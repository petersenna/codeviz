# IPC.pm
#
# This package deals with client/daemon communication for codeviz. The
# communicatgion mechanism is via a named pipe in /tmp so only one daemon
# can exist at a time. The data sent is the arguments delimited by #()#

package CodeViz::IPC;
require Exporter;
use vars qw(@ISA @EXPORT);
use strict;
use CodeViz::Format;
use File::Temp qw/ tempfile tempdir /;
use Cwd;
use Cwd 'abs_path';
use Fcntl;
no strict 'refs';

@ISA = qw(Exporter);
@EXPORT = qw(&daemon_open &client_open &daemon_close &client_close &client_write &daemon_read);

# PIPE for daemon and the input buffer for daemons
# The pipe is opened with sysopen() and
# accessed with sysread() and syswrite(). This was to avoid buffered IO and
# have select() work as expected
my $PIPE="/tmp/codeviz.pipe";
my $input_buffer;

# Alternative LDSO, see gengraph for explanation
my $LDSO="";

sub daemon_open()  {
  my $flags = '';
  printverbose("Opening pipe for reading\n");

  # Check a pipe does not already exist and if it does, have it removed
  check_pipe_exists();

  # Create new pipe
  printverbose("Creating input pipe\n");
  system("$LDSO mkfifo -m 666 $PIPE");
  if (! -p $PIPE) { die_nice("Failed to mknod pipe\n"); }

  # Open the pipe for reading
  if (!sysopen(DPIPE, $PIPE, O_RDONLY|O_NDELAY, 0666)) {
    die_nice("Failed to open $PIPE\n");
  }
}

# Open pipe for writing. Used by the client writing parameters to the daemon
sub client_open() {
  printverbose("Opening pipe for writing\n");

  # Check that a pipe exists and is a pipe
  if (! -e $PIPE) { die_nice("ERROR: $PIPE does not exist"); }
  if (! -p $PIPE) { die_nice("ERROR: $PIPE is not a pipe"); }

  # Open the pipe for writing
  sysopen(DPIPE, $PIPE, O_WRONLY|O_SYNC) || die_nice("ERROR: Failed open $PIPE for writing\n");
}

# Shutdown daemon
sub daemon_close() {
  printverbose("Shuttdown down daemon\n");

  # Check that a pipe exists and is a pipe
  if (! -e $PIPE) { print("Daemon is not running\n"); exit(-1); }
  if (! -p $PIPE) { print("Daemon is not running\n"); exit(-1); }

  # Open the pipe for writing or exit if it fails as a daemon
  if (!sysopen(DPIPE, $PIPE, O_WRONLY|O_NONBLOCK)) {
    print("Daemon is not running\n");
    exit(-1);
  }

  # Shutdown remote daemon
  print DPIPE "QUIT\n";
  close DPIPE;

  exit;
}


sub client_close() {
  printverbose("Closing input pipe\n");
  close DPIPE;
}

# This function is called if gengraph is being used in client mode.
sub client_write($$$$$$$$$$$$$$$$) {

  # Get parameters, matched exactly to gengraph
  my ($TRIM, $OUTPUT_TYPE, $ALL_LOCS, $LOCATION, $REVERSE, $FUNC, $FUNC_RX, $MAXDEPTH, $IGNORE, $IGNORE_RX, $SHOW, $SHOW_RX, $PLAIN_OUTPUT, $OUTPUT, $VERBOSE, $STDOUT) = @_;

  my $sleep_count;
  printverbose("Writing arguements to pipe\n");

  # Set output if appropriate
  if ( $OUTPUT eq "--unset--" ) {
    ($OUTPUT) = split(/ /, $FUNC);
    $OUTPUT .= $OUTPUT_TYPE;
  }

  # Prepend path if necessary
  if ($OUTPUT !~ /^\//) { $OUTPUT = abs_path(&getcwd) . "/$OUTPUT"; }

  # Unlink graph if it already exists
  if ( -e $OUTPUT ) { unlink($OUTPUT); }

  # Create a temporary file to catch errors
  my $TEMPDIR = tempdir( CLEANUP => 0 );
  my ($TMPFD, $TEMP) = tempfile( "codevizXXXX", DIR => $TEMPDIR );
  close($TMPFD);
  printverbose("Opened $TEMP for error log\n");

  # Call the daemon to generate the graph
  syswrite DPIPE, "$TRIM#()#$OUTPUT_TYPE#()#$ALL_LOCS#()#$LOCATION#()#$REVERSE#()#$FUNC#()#$FUNC_RX#()#$MAXDEPTH#()#$IGNORE#()#$IGNORE_RX#()#()#$SHOW#()#$SHOW_RX#()#$PLAIN_OUTPUT#()#$OUTPUT#()#$VERBOSE#()#$STDOUT#()#$TEMP#()#\n";
  client_close();

  # Wait 120 seconds until the error file or output file is created. If the 
  # error file is created, watch it until something useful happens
  $sleep_count=1200;
  printverbose("Waiting for output or error log\n");
  while ($sleep_count && (!-e $TEMP && ! -e $OUTPUT)) {
    $sleep_count--;
    select(undef, undef, undef, 0.1);
  }

  if (!$sleep_count) { print STDOUT "WARNING: Graph took longer than 120 seconds to generate. Gave up\n"; }

  # Either the output file or the error file exists
  if (!-e $OUTPUT) {
    $sleep_count=1200;
    printverbose("Waiting on error log\n");
    while ($sleep_count && (! -e $OUTPUT)) {

      # Read a line from the error file
      open(ERRLOG, "$TEMP") || die_nice("Failed to open error log");
      my $err_line = <ERRLOG>;

      if ($err_line eq "FAILED\n") {
        $err_line = <ERRLOG>;

	# Some buggy clients may be waiting on the existance of output
	open(OUTPUT, ">$OUTPUT");

	# Unlink the temp files
	unlink($TEMP);
	unlink($TEMPDIR);

	print "Failed to create graph: $err_line";
	exit;
      }
      close(ERRLOG);

      # Sleep for a tenth of a second
      $sleep_count--;
      select(undef, undef, undef, 0.1);
    }
  }

  # Unlink the temp files
  unlink($TEMP);
  unlink($TEMPDIR);


  if (!$sleep_count) { print STDOUT "WARNING: Graph took longer than 120 seconds to generate. Gave up\n"; }
}

# This function is used when in daemon mode to read input from the pipe. Input
# is read in with sysread in large blocks and then broken up into lines and
# returned to the caller line by line. Normal perl functions are not used
# because they don't block even if there is no data avaialble meaning the
# daemon would have to sleep and wake up every second checking for data
sub daemon_read() {
  my $offset=-1;
  my $line;
  my $length;
  my ($bytes, $times);
  my ($rin, $rout);

  # Initialise the number of times to sleep
  $times = 13;

  printverbose("Waiting for input\n");

  # Find if a full line has been read yet
  $offset = index $input_buffer, "\n";

  # If a line is not ready, try and read some input
  while ($offset == -1) {

    # Use select() to block on pipe until data is available
    $rin = '';
    vec($rin,fileno(DPIPE),1) = 1;
    select($rout=$rin, undef, undef, undef);

    # Read from the pipe
    $length = length($input_buffer);
    $bytes = sysread DPIPE, $input_buffer, 4096, $length;

    # Find if a full line has been read yet
    $offset = index $input_buffer, "\n";

    # If no bytes were read, sleep for up to 3 seconds before reopening
    # the pipe so that a select() will block
    if (!$bytes && $offset == -1) {

      # Sleep for 0.1 second intervals for the first second and 1 second after
      $times--;
      if ($times > 3) { select(undef, undef, undef, 0.1); next; }
      else            { sleep(1); next; }

      # Else reopen the pipe so the process will block on select()
      printverbose("Reopening pipe\n");
      close(DPIPE);
      if (!sysopen(DPIPE, $PIPE, O_RDONLY|O_NDELAY, 0666)) {
        unlink($PIPE);
	die_nice("Failed to reopen $PIPE\n");
      }
    }

    # Reset the number of times to sleep before reopening the pipe. Remember
    # that a partial line may only have been read this time around
    $times = 13;

  }

  # Read the line and truncate input_buffer to remove this line
  $line = substr $input_buffer, 0, $offset;
  $input_buffer = substr $input_buffer, $offset+1, length($input_buffer);

  # Check if we should exit. It is possible that some clients will lose their
  # requests if the daemon is really busy but thats too bad. The proper way
  # to fix this is have a global var indicating that the system is exiting
  # and then quit when no input is available from the pipe and input_buffer
  # is empty
  if ($line eq "QUIT") {
    printverbose("Exiting daemon\n");
    pipe_close();
    unlink($PIPE);
    exit;
  }

  # Parse the input line
  my @retarray;
  my $index=0;
  foreach (split(/#\(\)#/, $line)) {
    $retarray[$index] = $_;
    $index++;
  }

  return @retarray;
}

# Check if the pipe already exists and is active. If it is, this daemon exits.
# Otherwise the pipe is simply unlinked
sub check_pipe_exists() {
  printverbose("Checking for existing pipe\n");
  if (-e $PIPE) {

    if (-p $PIPE) {
      # Open pipe
      if (sysopen(DPIPE, $PIPE, O_WRONLY|O_NDELAY, 0644)){
        close(DPIPE);
        print("CodeViz daemon already appears to be running\n");
	exit(-1);
      }
    }

    # Unlink the file that is there
    unlink($PIPE);
  }
}

1;
