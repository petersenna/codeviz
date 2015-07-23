# CollectCppDepn.pm
#
# This module is responsible for collecting call graph information via
# cdepn files for C++ using cdepn files. The CXref method is far superior
# for C files as it is able to analyse the source. However, the parser is
# too C specific and it makes really stupid errors for C++. This method is
# not as extensive but it's simplicity makes it solid for C++
#

package CodeViz::CollectCppDepn;
use CodeViz::Graph;
use CodeViz::Format;
require Exporter;
use vars qw (@ISA @EXPORT);
use strict;
no strict 'refs';

@ISA    = qw(Exporter);
@EXPORT = qw(&generate_cppdep);

my $propdepth=2;

# generate_cppdep - Collect data from C++ .cdepn files and the graph
# $toplevel - Top level source directory
# $files    - Specific files that are to be scanned
# $subdirs  - List of subdirectories to graph
# $handle   - File handle to output graph
sub generate_cppdep {
  my ($toplevel, $files, $subdirs, $handle) = @_;
  analyse_cdepn($toplevel, $files, $subdirs, $handle, 1);
}

sub parseDeclaration($) {
  my ($decl) = $_[0];

  # Split by elements to remove the return type
  my @elements = split(/ /, $decl);

  # kost@ : skip all the elements, if any, until the one with a '(' or
  # containing "::operator" - these elements are the type specifiers
  # for the return element;

  my $index = 0;
  while ($index <= $#elements &&
	 @elements[$index] !~ /\(/ && @elements[$index] !~ /::operator/) {
      $index++;
  }

  # kost@ : is this template-related?? I have no idea.. someone more
  # knowledgeable should check this code - so far it's out:
  #if (@elements[0] =~ /</) {
  #  # Find end of arguments
  #  while ($elements[$index] !~ />/ && $index <= $#elements) { $index++; }
  #  $index++;
  #}

  # Get the function name
  $decl="";
  while ($index <= $#elements) {
    $decl .= $elements[$index];
    if ($decl !~ /,$/) { $decl .= " "; }
    $index++;
  }

  $decl =~ s/\s*$//;
  $decl =~ s/\}$//;
  $decl =~ s/^\{//;
  return $decl;
}

# analyse_cdepn - Collects the actual information
# Takes the same parameters as generate_cobjdump except for
# $cpp - Boolean set to 1 if analysing c++
sub analyse_cdepn {
  my ($toplevel, $files, $subdirs, $handle, $cpp) = @_;
  my $toplevel_escaped;
  my @f;
  my %F;		# Function declaration hash table
  my %M;		# Flags if function called 
  my %C;		# Call graph edge. Global as sorting function needs it
  my @sortedC;		# Sorted call graph
  my %printed;		# Hash table storing edges already printed
  my $i;		# Index variable
  my ($f1, $f2);	# Two functions

  # Get the top level escaped path
  $toplevel_escaped = $toplevel;
  $toplevel_escaped =~ s/\//\\\//g;

  # Begin scanning for files. If specific files have been requested,
  # then use them else use find to locate .cdepn files
  my $start = printstart("Finding input files");
  if ($files != -1) {
    open(FIND, "echo $files|") or die("Failed to open pipe to 'echo'");
  } else {
    open(FIND, "find $subdirs -print |") or die("Failed to open pipe to 'find'");
  }
  while (<FIND>) {
    chop;
    my $file = $_;
    push(@f, $file) if $file =~ /\.(h|hh)$/i; # Duplicated in lib/LXR/Common.pm
    if ($file =~ /.cdepn$/) {
      $file =~ s/\.cdepn$//g;
      push(@f, $file);
    }
			    
  }
  close(FIND);
  printcomplete($start, $#f+1 . " files found");

  # Read each of the files
  $start = printstart("Reading cdepn files");
  my $fnum=0;
  my $file;
  foreach $file (@f) {

    # Remove the toplevel source directory name
    $file =~ s/$toplevel_escaped//;

    # Open input file
    $fnum++;
    printprogress($file, -1, $fnum, $#f+1);
    open (F,"$toplevel$file.cdepn") || next;

    # Read this input file
    while (<F>) {
      $_ =~ s/$toplevel_escaped//;
      next if ($_ =~ /static destructors/);
      next if ($_ =~ /static init/);
      next if ($_ =~ /operator new/);
      next if ($_ =~ /operator delete/);

      # Lines beginning with F are function declarations
      # This check sees if the filename between the {}
      # has a / at the beginning or not. If it does, it
      # has been included from an external file and 
      # should be ignored, otherwise record it as a function
      # declaration
      if (/^F {(.*)} {(.+):(.+)}/) {
        my $loc="$2:$3";
	$f1 = parseDeclaration($1);
        
	#if ($cpp) { $f1 =~ s/<.*>//g; }
        $F{$f1} = "$2:$3";
        $M{$f1}=3;
      } elsif (/^C {(.*)} {(.+):(.+)}\s+(.+)/) {
        my $loc = "$2:$3";
        # Lines beginning with C are calling a function
        # The key is hashed as "caller:callee" and the
        # value is "filename:linenumber"
        $f1 = parseDeclaration($1);
	$f2 = parseDeclaration($4);

        #if ($cpp) { $f1 =~ s/<.*>//g; }
        #if ($cpp) { $f2 =~ s/<.*>//g; }

        $C{"$f1~$f2"}="$loc";
      }
    }

    close F;
  }
  printcomplete($start, "$fnum cdepn files read");
  close FIND;

  $start = printstart("Propagating call graph");
  for($i=0;$i<$propdepth;$i++) {
    foreach (keys %C) {
      next if (!/^(.+)~(.+)$/);
      $M{$2} |= 1 if ($M{$1} & 1);
      $M{$1} |= 2 if ($M{$2} & 2);
    }
  }
  printcomplete($start, "Propagation complete");

  # print result
  $start = printstart("Sorting function calls");
  @sortedC = sort FuncFileSort keys %C;
  printcomplete($start, "Functions sorted");

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

  $start = printstart("Dumping graph information");
  while (($f1, $f2) = each %F) {
    my $ef1 = $f1;
    printGraph($handle, "\"$ef1\" [label=\"$f1\\n$f2\"];\n"); 
  }

  foreach (@sortedC) {
    next if (!/^(.+)~(.+)$/); 
    $f1=$1; $f2=$2;
    next if (!($M{$f1} > 0));      # ignore not flagged caller

    # Strip away SMP mangling on symbols. This is very 
    # Linux specific but the names of the functions are
    # so weird, I cannot see it happening anywhere else.
    $f1 =~ s/_Rsmp_([0-9a-f]{8})$//;
    $f2 =~ s/_Rsmp_([0-9a-f]{8})$//;

    if ($printed{"$f1-$f2"} != 1)
    {
      $printed{"$f1-$f2"} = 1;
      my $loc = $C{"$f1~$f2"};
      $f1 = "\"$f1\"";
      $f2 = "\"$f2\"";
      printGraph($handle, "$f1 -> $f2 [label=\"" . $loc . "\"];\n");
    }
   
  }
  printcomplete($start, "Graph dumping complete");
  return 0;
}

1;
