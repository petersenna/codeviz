# Format.pm
#
# Simple functions for outputting things nicely such as progress reports
#

use lib ".";
package CodeViz::Format;
require Exporter;
use vars qw (@ISA @EXPORT);
use strict;
no strict 'refs';

@ISA    = qw(Exporter);
@EXPORT = qw(&printstart &printline &printprogress &printwarning &printcollision &print_collision_count &printcomplete &printerror &printverbose &die_nice &set_verbose &set_daemon);

my $VERBOSE=0;    # Verbosity level
my $DAEMON=0;     # Set to 1 if program is a daemon
my $pass=0;       # Which pass we are on
my $pcursor=0;    # Current position of cursor
my $lastprint=0;  # Last time something was printed
my $lastline="";  # Last line that was printed

##
# Print a start message for genfull using printraw
sub printstart {
  my ($message) = @_;
  $pass++;
  printraw("Starting  pass $pass: $message\n");
  return time;
}

##
# Print message exactly as it appears. This writes the message to the
# same line which is desirable for genfull but probably not for gengraph.
sub printraw {
  my ($message, $noremember) = @_;
  my $blank;

  $blank = sprintf "%-" . $pcursor. "s", " ";
  syswrite STDOUT, "\r$blank";
  syswrite STDOUT, "\r$message";
  $pcursor = length($message);

  if ($noremember == 0) { $lastline = $message; }
}

##
# Print a single line
sub printline {
  my $message = $_[0];
  printraw("(Pass $pass) $message");
}

##
# Print a progress report for genfull
sub printprogress {
  my ($fname, $fsize, $fnum, $ftotal) = @_;
  my $message;
  my $now = time;

  # Print the file size in a nice fashion. 
  # 0  => file is being skipped
  # -1 => file size is unknown
  
  # Only print out once a second at most
  if ($now eq $lastprint) { return; }
  $lastprint = $now;

  if        ($fsize == 0)  { $fsize = "skipping"; }
  else { if ($fsize == -1) { $fsize = "scanning"; } }

  # Format the filename so it is not more than 35 characters
  if (length($fname) > 30) {
    $fname = "..." . substr $fname, length($fname)-27, 27;
  }
  $message = sprintf "(Pass $pass) %-30s (%8s), file %d of %d...",
                     $fname, $fsize, $fnum, $ftotal;

  # Write message
  printraw($message);
}

##
# Print a report on a collision found. specific to genfull
sub printcollision {
  my ($func, $first, $second) = @_;

  printraw("\rWARNING: Function name collision for $func.....\n", 1);
  printraw("         First  occurance in $first\n", 1);
  printraw("         Second occurance in $second\n", 1);
  printraw($lastline);
}

##
# Print a report on the number of collisions that occured
sub print_collision_count {
  my ($collisions, $resolved, $funccount) = @_;
  if ($collisions > 0 && $collisions != $resolved) {
    print STDOUT <<EOF
    
NOTICE: $collisions naming collisions were detected affecting $funccount different 
        functions.  $resolved of the collisions were resolved automatically. 
        If this is a problem try using the -s switch to break the source 
        tree into smaller chunks
EOF
  }
}

sub printwarning {
  my ($message) = @_;
  printraw("WARNING: $message\n");
}

sub printcomplete {
  my ($start, $message) = @_;
  $message = sprintf "Completed pass $pass\: $message in %d seconds\n", (time-$start);
  printraw($message);
}


# This function will print an error to standard out and exit normally. For
# most perl scripts, the die() function is used but as gengraph can be used
# as part of a CGI script, this function is used instead
sub printerror {
  if ($DAEMON) {
    print STDERR $_[0];
    print STDERR_EXTRA "FAILED\n";
    print STDERR_EXTRA $_[0];
    return;
  }
  die($_[0]);
}

sub die_nice {
  printerror($_[0]);
}

# This function will only print out the parameter if the -v switch is
# specified
sub printverbose {
  if ($VERBOSE) {
    syswrite (STDOUT, @_[0], length(@_[0]));
  }
}

sub set_verbose {
  $VERBOSE = $_[0];
}

sub set_daemon {
  $DAEMON = $_[0];
}

1;

