# PPCStack.pm
#
# This is a post-processing module that uses the cumulative stackusage 
# between pairs of functions. A pair is separated by a - and subsequent
# pairs are separated by a ,

package CodeViz::PPCStack;
require Exporter;
use vars qw (@ISA @EXPORT);
use strict;
use CodeViz::Graph;
use CodeViz::Format;
no strict 'refs';

@ISA =    qw(Exporter);
@EXPORT = qw(&PPCStack);

my @path;

sub usage() {
  print <<EOF;

The supported options for the Stack postprocessing are:

  showcumulative     Show cumulative usage between pairs of functions. A
                     single pair is seperated by a - and subsequent pairs
		     are separeted by a space
		     e.g "

  startusage         Use this value as the starting value of the stack usage.
                     There is no automatic way to determine when the stack
		     usage was effectively 0. You must make a guess at it
		     yourself. For example, on entry to a system call, it
		     could be considered to be 0 but at alloc_page(), you'd
		     have to calculate it yourself.
		     "__alloc_pages-bad_range prep_new_page-show_trace"

  largeusage         Highlight nodes in a dark blue which are using a 
                     cumulative usage more than a given value. For the kernel,
		     this would be around 7168 to show that only 1KiB is left
		     in the stack space
                     
EOF
  exit;
}

##
# Top-level call function to show cumulative stack usage
sub PPCStack {
  my ($options, $dag, $ingraph) = @_;
  my $allpairs;
  my $pair;
  my $largeUsage=4294967296;
  my $startUsage;
  my $option;
  my ($param, $value);
  if ($options eq 'help') { usage(); }

  printverbose("Post-Processing: Cumulative stack usage\n");


  # Add a , if necessary to help parsing
  if ($options !~ /.*=.*,/) { $options .= ","; }

  # Parse all options.
  foreach $option (split /,/, $options) {
    ($param, $value) = split /=/, $option;
    if ($param eq "showcumulative")  { $allpairs = $value; next; }
    if ($param eq "startusage")      { $startUsage = $value; next; }
    if ($param eq "largeusage")      { $largeUsage = $value; next; }

    # Unknown option, show usage
    usage();
  }

  # Process each pair
  $allpairs .= " ";
  foreach $pair (split / /, $allpairs) {
    my ($from, $to) = split(/-/, $pair);
    processPair($from, $to, $largeUsage, $startUsage, $dag, $ingraph);
  }
}

##
# Process a single pair of functions to show the cumulative usage for
sub processPair {
  my ($from, $to, $largeUsage, $startUsage, $dag, $ingraph) = @_;

  # Check that both functions are in the output graph
  if ($$ingraph{$from} != 1) {
    printerror("Function $from is not in the output graph, ignoring cumulative stack usage for pair ($from -> $to)");
    return;
  }
  if ($$ingraph{$to} != 1) {
    printerror("Function $to is not in the output graph, ignoring cumulative stack usage for pair ($from -> $to)");
    return;
  }

  # Find the path between the two functions
  my %visited;
  my $i;
  undef @path;
  my $found = findPath($from, $to, $dag, $ingraph, \%visited, 0);

  # Return as failure if a path was not found
  if ($found == 0) {
    printerror("No path between $from and $to was found, ignoring this pair");
    return;
  }

  # Calculate the cumulative stack usage for the node
  my $usage = $startUsage;
  my $i;
  for ($i = 0; $i <= $#path; $i++) {
    # Check if this node has had usage set already
    my $thisCUsage = getNodeAttribute("cstackuse", \$$dag{$path[$i]});
    if ($thisCUsage != 0) {
      printerror("Node " . $path[$i] . " already has cumulative usage calculated($thisCUsage), skipping\n");
      next;
    }
    
    # Calculate the cumulative usage for this node and set
    my $thisUsage = getNodeAttribute("stackuse", \$$dag{$path[$i]});
    $usage += $thisUsage;
    setNodeAttribute("cstackuse", $usage, \$$dag{$path[$i]});

    # Color the node. Light blue normal, dark blue if using too much
    setNodeAttribute("style", "filled, bold", \$$dag{$path[$i]});
    if ($usage > $largeUsage) {
      setNodeAttribute("fillcolor", "#5050A0", \$$dag{$path[$i]});
    } else {
      setNodeAttribute("fillcolor", "#A0A0F0", \$$dag{$path[$i]});
    }

    # Set the node label
    my $label = getNodeAttribute("label",    \$$dag{$path[$i]});
    if ($label ne "") { $label .= "\\ncstackuse=$usage"; }
    else              { $label =  $path[$i] . "\\ncstackuse=$usage"; }
    setNodeAttribute("label", $label, \$$dag{$path[$i]});
  }
  
}

##
# Find a path between two functions. Paths which involve functions that
# are not in the call graph are ignored. Otherwise, it is a bog-standard
# depth-first recursive search of the graph
sub findPath {
  my ($nodeName, $to, $dag, $ingraph, $path, $visited, $depth) = @_;

  printverbose("Searching: $nodeName\n");

  # If we have already visited this node, return
  if ($$visited{$nodeName} == 1) { return 0; }
  $$visited{$nodeName} = 1;

  # Return fail if this node is not in the output graph
  if ($$ingraph{$nodeName} != 1) { return 0; }

  # Return success if we have found the desired node
  if ($nodeName eq $to) {
    printverbose("Path found\n");
    $path[$depth] = $nodeName;
    return 1;
  }

   # Else we need to continue searching
   my $node;
   my @callers = @{$$dag{$nodeName}->{'callees'}};
   foreach $node (@callers) {
     my $found = findPath($$node->{'name'}, $to, $dag, $ingraph, $path, $visited, $depth+1);
     if ($found == 1) {
       # Hurray, this node was in the desired path
       $path[$depth] = $nodeName;
       return 1;
     }
  }

  # Was not found anywhere below this node
  return 0;
}

1;
