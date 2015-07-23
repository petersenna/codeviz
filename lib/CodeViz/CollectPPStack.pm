# CollectPPStack.pm
#
# This is a post-processing module for the collection of stack usage in functions
# See the usage function for the options

package CodeViz::CollectPPStack;
require Exporter;
use vars qw (@ISA @EXPORT);
use strict;
use CodeViz::Format;
no strict 'refs';

@ISA =    qw(Exporter);
@EXPORT = qw(&CollectPPStack);

sub usage() {
  print <<EOF;

The supported options for the Stack postprocessing are:

  objfile=[file]    e.g. vmlinux

EOF
  exit;
}

sub CollectPPStack {
  my ($fullgraph, $options) = @_;
  my $objfile;
  my $option;
  my ($param, $value);
  my %susage;
  my $start;
  if ($options eq 'help') { usage(); }

  $start = printstart("Post-Processing: Stack usage");

  # Add a , if necessary to help parsing
  if ($options !~ /.*=.*,/) { $options .= ","; }

  # Parse all options. Currently, there is only one, but that might change
  foreach $option (split /,/, $options) {
    ($param, $value) = split /=/, $option;
    if ($param eq "objfile") { $objfile = $value; }
    else { usage(); }
  }

  # Call check-stack.sh and read the stack usage information
  if (! -e $objfile) {
    print STDERR "Post-processing error: Object file '$objfile' does not exist\n";
    return;
  }

  if (!open(PPPIPE, "check-stack.sh $objfile|")) {
    print STDERR "Failed to run check-stack on $objfile";
    return;
  }

  # Read the stack usage
  printstart("Reading check-stack output");
  while (!eof(PPPIPE)) {
    my $line = <PPPIPE>;
    if ($line !~ /^0x([0-9a-fA-F]+) (.*)/) { next; }
    
    $susage{$2} = hex $1;
  }
  close(PPPIPE);

  # Read the full.graph file and insert the stack related information. 
  # Place the processed file in full.graph.pp and then transfer it
  open(PPFILE, $fullgraph) || die("Failed to open full graph '$fullgraph'");
  open(PPOUT,  ">$fullgraph.pp") || die("Failed to open temporary file '$fullgraph.pp");

  printstart("Inserting stack information into $fullgraph");
  while (!eof(PPFILE)) {
    my $line = <PPFILE>;

    if ($line =~ /(.*) \[.*\];/) {
      my $func = $1;

      # This is a node description, see have we stack information on it
      if ($susage{$func} != 0) {
        chomp($line);
        $line =~ s/\];//;
	$line .= ", stackuse=$susage{$func}];\n";
      }
    }

    print PPOUT $line;
  }

  close(PPFILE);
  close(PPOUT);

  system("mv $fullgraph.pp $fullgraph");

  printcomplete($start, "Post-Processing: Stack usage");

}

1;
