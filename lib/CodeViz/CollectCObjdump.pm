# CollectCObjdump.pm
#
# This module is responsible for collecting call graph information by
# calling objdump on each object file created. The restriction is that
# the files must not be stripped. This module will fail if the 
# intermediatary object files are not created for each C file but it
# is assumed that this is the prevalent build method and not likely to
# change. In theory, this could work with compiled binaries but it is
# not supported yet
#

package CodeViz::CollectCObjdump;
use CodeViz::Graph;
use Cwd 'abs_path';
require Exporter;
use vars qw (@ISA @EXPORT);
use strict;
no strict 'refs';

# List of sections to dump for code. text is the one used normally and
# init is commonly used in the Linux kernel
my $dumpsections = "text init";

# List of possible assembler instructions for function calls.
my @asm_calllist = ("call", "jmp", "bl");

my $propdepth = 2;

@ISA    = qw(Exporter);
@EXPORT = qw(&generate_cobjdump &generate_cppobjdump);

# generate_cobjdump   - Collect data from binary files compiled with gcc
# $toplevel - Top level source directory
# $files    - Specific files (probably binaries) to scan
# $subdirs  - List of subdirectories to graph
# $handle   - File handle to output graph
sub generate_cobjdump {
  my ($toplevel, $files, $subdirs, $handle) = @_;
  analyse_binaries($toplevel, $files, $subdirs, $handle, 0);
}

# generate_cppobjdump - Collect data from binary files compiled with g++
# $toplevel - Top level source directory
# $files    - Specific files (probably binaries) to scan
# $subdirs  - List of subdirectories to graph
# $handle   - File handle to output graph
sub generate_cppobjdump {
  my ($toplevel, $files, $subdirs, $handle) = @_;
  analyse_binaries($toplevel, $files, $subdirs, $handle, 1);
}

# analyse_binaries - Collects the actual information
# Takes the same parameters as generate_cobjdump except for
# $cpp - Boolean set to 1 if analysing c++

sub analyse_binaries {
  my ($toplevel, $files, $subdirs, $handle, $cpp) = @_;
  my $obj;		     # Name of object file
  my %F;		     # Function declaration hash table
  my %M;		     # Flags if function called 
  my %C;		     # Call graph edge. Global as sorting function needs it
  my @sortedC;		     # Sorted call graph
  my %printed;		     # Hash table storing edges already printed
  my $i;		     # Index variable
  my ($f1, $f2);	     # Two functions
  my ($currFunc, $currAddr); # Current function being read from objdump and address
  my ($callFunc, $callAddr); # Function being called from current func
  my $section;
  my $op;

  # Use find to get all cdep files and process them with cdepn()
  if ($files != -1) {
    open(FIND, "echo $files|") or die("Failed to open pipe to 'echo'");
  } else {
    open(FIND, "find $subdirs -type f -name \"*\" -perm +111|")
      or die("Failed to open pipe to 'find'");
  }

  while(!eof(FIND)) { 

    # Open input file
    $obj = <FIND>;
    chomp($obj);
    syswrite STDOUT, "Opening: $obj";

    foreach $section (split(/ /, $dumpsections)) {
      open (F,"objdump -C -d --section=.text --section=.$section $obj|") || next;
      syswrite STDOUT, "...$section";

      # Read this input file
      while (<F>) {
	# Function labels from objdump look like
	# address <functionname>: which is what this
	# regular expression searched for
        if (/^([0-9a-f]+) <(.*?)(\(.*\)\s*(const)?)?>:/) {
	  $currAddr = $1;
	  $currFunc = $2;

	  $F{$currFunc} = "$obj:0x$currAddr";
          $M{$currFunc}=3;
	}

	# A function call will look something like
	# addr: opcodes		asmop <funcname+offset>
	# Where asmop will be some instruction as listed
	# in the $asm_calllist array
	
	#    address        asmop     addr     <function>
	if (/(^\s*[0-9a-f]+):.*\s+([a-z]+)\s+[0-9a-f]+\s+<(.*?)(\(.*\)\s*(const)?)?(\+0x[0-9a-f]+)?>/ && $3 ne $currFunc) {
	  foreach (@asm_calllist) {
	    if ($_ eq $2) { 
	      $callAddr = $1;
	      $callFunc = $3;

	      $callFunc =~ s/\+.*//;

	      # Some as for function declarations, strip parameter information for c++
	      $C{"$currFunc~$callFunc"} = "$obj:0x$callAddr"; 
	      last;
	    } 
	  } 
	}
      }
  
      close F;
    }
    syswrite STDOUT, "\n";
  }
  close FIND;

  print "Propagating call graph\n";
  for($i=0;$i<$propdepth;$i++) {
    foreach (keys %C) {
      next if (!/^(.+)~(.+)$/);
      $M{$2} |= 1 if ($M{$1} & 1);
      $M{$1} |= 2 if ($M{$2} & 2);
    }
  }

  # print result
  print "Sorting function calls\n";
  @sortedC = sort FuncFileSort keys %C;
  # Function sorting function. Functions are sorted by
  # filename alphabetically and then line number. This
  # is done to ensure the functions are outputted in
  # the right call order
  sub FuncFileSort {
    my ($lFunc, $rFunc);
    my ($lNum, $rNum);
    my $result;

    ($lFunc, $lNum) = split(/~/, $C{$a});
    ($rFunc, $rNum) = split(/~/, $C{$b});
  
    # Compare the filenames and return the result
    # if they are not the same
    $result = $lFunc cmp $rFunc;
    if ($result != 0) { return $result; }
  
    # Filenames are the same, so return the comparison
    # of the line numbers
    return $lNum <=> $rNum;
  }

  print "Outputting graph labels\n";
  while (($f1, $f2) = each %F) {
    my $ef1 = $f1;
    if ($cpp && $ef1 =~ /::/) { $ef1 = "\"$ef1\""; }
    printGraph($handle, "$ef1 [label=\"$f1\\n$f2\"];\n"); 
  }

  print "Outputting call graph\n";
  foreach (@sortedC) {
    next if (!/^(.+)~(.+)$/); 
    $f1=$1; $f2=$2;
    next if (!($M{$f1} > 0));      # ignore not flagged caller

    if ($printed{"$f1-$f2"} != 1)
    {
      $printed{"$f1-$f2"} = 1;
      if ($cpp) { 
      
        if ($f1 =~ /::/) { $f1 = "\"$f1\""; }
        if ($f2 =~ /::/) { $f2 = "\"$f2\""; }
      }
      printGraph($handle, "$f1 -> $f2;\n");
    }
   
  }
  print "Done\n";
  return 0;
}

1;
