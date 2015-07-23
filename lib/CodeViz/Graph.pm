# Graph.pm
#
# Simple package to simplify the handling of graphs, nodes and edges. Each
# node in the graph is represented by a hash. The hash has the following
# fields of relevance
#
# name     - Name of the node. Used to hash into the graph
# label    - Label of the node to display
# outbound - Number of nodes this connects to
# inbound  - Number of nodes connecting to here
#
# While this package could be used for representing generic packages, it is
# intended for the user with the call graph generator so some of the placement
# decisions look a little odd

package CodeViz::Graph;
require Exporter;
use vars qw (@ISA @EXPORT);
use strict;
use CodeViz::Format;
no strict 'refs';

@ISA    = qw(Exporter);
@EXPORT = qw(&openGraph &closeGraph &printGraph &createNode &createEdge &addHTMLAttributes &printNode &addEdgeAttribute &read_inputgraph &getNodeAttribute &setNodeAttribute &resolveNode);
my $DEFAULT_FONT="Helvetica";
my $DEFAULT_FONTSIZE="12";
my %resolveMap;
 
# openGraph - Open an output graph file for use with dot
# $filename: Graph file to open
#
sub openGraph {
  my ($filename) = @_;
  open(OPENGRAPH, ">$filename") || die ("Failed to open output graph '$filename'\n");
  print OPENGRAPH "digraph fullgraph {\n";
  print OPENGRAPH "node [ fontname=$DEFAULT_FONT, fontsize=$DEFAULT_FONTSIZE ];\n";
  return "OPENGRAPH";
}

# resolveNode - Given a function name, try and resolve it's full name
# $nodeName - Name of the node to resolve
sub resolveNode($) {
  my ($nodeName) = $_[0];
  my ($resolveList) = $resolveMap{$nodeName};

  # If there are no mappings, return and hope for the best
  if ($resolveList eq "") { return $nodeName; }

  # Get the full list. If there is only one, return it
  my @resolveElements = split(/\|/, $resolveList);
  if ($#resolveElements == 0) { return $resolveElements[0]; }

  # Else, there are more than one and it is an ambiguous graph. Request
  # which one is of interest
  print "There are multiple functions that match the requested $nodeName.\n";
  print "Rerun with one of the following selected for -f;\n";
  my $element;
  foreach $element (@resolveElements) {
    print "$element\n";
  }
}

# closeGraph - Print footer and close graph file
# $handle: Name of file to close
#
sub closeGraph {
  print OPENGRAPH "}";
  close OPENGRAPH;
}

# printGraph - Print an output line to a graph file
sub printGraph {
  my ($handle, $line) = @_;
  print OPENGRAPH $line;
}

# createNode - Create a single node
# $name  - name to assign to this node
# $label - label to use for displaying 
# %dag   - Graph to add this node to
#
# Check if a node exists in a particular graph yet and if it does not,
# create it with some default values. 
sub createNode {
  my ($name, $label, $dag) = @_;

  # Strip out "'s that may have been inserted for scopes
  $name =~ s/\"//g;

  if (!defined($$dag{$name})) {
    $$dag{$name}->{'name'}  = $name;
    $$dag{$name}->{'label'} = $label;
    $$dag{$name}->{'outbound'} = 0;
    $$dag{$name}->{'inbount'} = 0;
  } 

  # Get the filename from the label if possible
  if ($label =~ /:/) {
    my ($dummy, $file) = split /\\n/, $label;
    $file =~ s/:.*//;
    $$dag{$name}->{'file'} = $file;
  }
}

# createEdge - Create an edge between two nodes
# $from - From node
# $to   - To node
# $loc  - Location the call took place
sub createEdge {
  my ($from, $to, $loc) = @_;
  my ($dx, $dy);

  # Make sure labels are assigned
  if (!defined($$from->{'label'})) { $$from->{'label'} = $$from->{'name'}; }
  if (!defined($$to->{'label'}))   { $$to->{'label'} = $$to->{'name'}; }

  # Create edge
  push(@{$$from->{'callees'}}, $to);
  push(@{$$to->{'callers'}},   $from);
  push(@{$$from->{'callocs'}}, '"' . $$to->{'label'} . '"' . "~$loc");
  $$from->{'outbound'}++;
  $$to->{'inbound'}++;
}

# getNodeAttribute - Returns the value of a given attribute
sub getNodeAttribute {
  my ($desiredkey, $node) = @_;
  my ($attrib, $key, $value);

  my $nodeAttribs = $$node->{'attributes'};
  return $$nodeAttribs{$desiredkey};
}

# setNodeAttribute - Sets the value of the given attribute
sub setNodeAttribute {
  my ($desiredkey, $newvalue, $node) = @_;

  my $nodeAttribs = $$node->{'attributes'};
  $$nodeAttribs{$desiredkey} = $newvalue;

  $$node->{'attributes'} = $nodeAttribs;
}

# addHTMLAttributes - Add attributes that are specific to HTML
# $nodeName - Node name to set the HTML attributes for
# $URL      - Template URL to use for links
sub addHTMLAttributes {
  my ($nodeName, $URL, $label, $dag) = @_;
  my $dummy;
  
  # Only add HTML attributes if label looks like it supports it
  if ($label !~ /:/) { return; }

  # Else create some HTML attributes
  my ($dummy, $fileline) = split /\\n/, $label;
  my ($file, $line) = split /:/, $fileline;

  $URL =~ s/%n/$nodeName/;
  $URL =~ s/%f/$file/;
  $URL =~ s/%l/$line/;

  setNodeAttribute("URL", $URL, \$$dag{$nodeName});
  setNodeAttribute("tooltip", "$nodeName(), $file, line $line", \$$dag{$nodeName});
}

# printNode - Print a node and all it's attributes in dot-friendly format
# $node - Node to print
# $fd   - File description to write to
sub printNode {
  my ($node, $fd, $LOCATION, $dag) = @_;
  my ($name, $attributes);

  # Get the node name
  # Quote certain functions, particularly
  # o Class members with the scope operator ::
  # o Function pointers
  $name = $$dag{$node}->{'name'};
  $name = "\"$name\"";

  # Render the node attributes if it has any
  my $nodeAttribs = $$dag{$node}->{'attributes'};
  my $key;
  my $allattribs;
  foreach $key (keys %$nodeAttribs) {
    if ($key eq "") { next; }
    if ($allattribs ne "") { $allattribs .= ", "; }
    $allattribs .= "$key=\"" . $$nodeAttribs{$key} . "\"";
  }

  # Print the node
  if ($allattribs ne "") {
    print $fd "$name  [ $allattribs ];\n";
  }
}


# This function reads the full input graph from the file that is requsted and
# builds the DAG based on it. Most of the graph functionality is in
# CodeViz::Graph
sub read_inputgraph($$$$$$$) {
  my ($GRAPH, $LOCATION, $OUTPUT_TYPE, $BASEURL, $font, $fontsize, $dag) = @_;
  my $HEADER;
  my $delim;
  my $line;
  my ($caller, $callee, $loc, $other);

  # Open input graph and read the header
  open(INGRAPH,  $GRAPH) || die_nice ("$GRAPH not found, use genfull\n");
  $HEADER =  <INGRAPH>;
  $HEADER .= <INGRAPH>;
  $HEADER =~ s/$DEFAULT_FONT/$font/;
  $HEADER =~ s/fontsize=$DEFAULT_FONTSIZE/fontsize=$fontsize/;

  # Read full input graph
  $delim = $/ ; $/ = ";\n";
  printverbose("Reading input call graph\n");

  while (! eof INGRAPH) {
    $line = <INGRAPH>;
    if ($line ne "}") {

      # Check if this is a function call
      if ($line =~ /->/) {

        # Extract information about the call
        if ($line =~ /(.+) -> (.+) \[label="(.*)"\]/) {
	  # Extract caller, callee and call locations from new-style graphs
          $caller = $1;
	  $callee = $2;
	  $loc    = $3;

	} else {
          if ($line =~ /(.+) -> (.+);/) {
	    # Extract just caller and callee from old-style graphs
	    $caller = $1;
	    $callee = $2;
	    $loc    = "";
	  }
	}
	$caller =~ s/\"//g;
	$callee =~ s/\"//g;

        # Make sure the nodes exist
        if (!defined($$dag{$caller})) { createNode($caller, $caller, $dag); }
        if (!defined($$dag{$callee})) { createNode($callee, $callee, $dag); }

        # Create an edge in the graph
        createEdge(\$$dag{$caller}, \$$dag{$callee}, $loc);

      } else {
        # Check if this is a location declaration
        if ($line =~ /(.+) +\[.*label="(.*)".*\]/ ) {
	  my ($node, $label);
	  $node  = $1;
	  $label = $2;
	  $node =~ s/\"//g;

	  # As graphs now include parameter information, record a mapping
	  # of nodes without the parameter information to the nodes with
	  # the parameter information. This can be used later by resolveNode()
	  # to decide if there are multiple functions with the same name
	  if ($node =~ /(.*)\(.*\)/) {
	    $resolveMap{$1} .= $node . "|";
	  }

	  # Create a new node, with label and HTML specific attributes if asked
          createNode($node, $label, $dag);
	  if ($LOCATION) { setNodeAttribute("label", $label, \$$dag{$node}); }
	  if ($OUTPUT_TYPE =~ /html/) { addHTMLAttributes($node, $BASEURL, $label, $dag); }

	  # Set the node attributes
          $line =~ /(.+) +\[(.*)\]/;
	  my $allattribs = $2;
	  my @elements = split(/,/, $allattribs);
	  my $element="";
	  my $index=0;
	  while ($index <= $#elements) {
	    $element .= $elements[$index];
	    if ($index < $#elements) { $element .= ","; }
	    my $halfcount = ($element =~ tr/\"//) / 2;
	    my $intcount = int $halfcount;
	    if ($halfcount == $intcount) {
              my ($key, $value) = split /=/, $element;
	      $element="";

	      # Skip label
	      if ($key eq "label") { $index++; next; }

              # Else add the node attribute
              $value =~ s/^\"//;
              $value =~ s/\"$//;
	      setNodeAttribute($key, $value, \$$dag{$node});
	    }
	    $index++;
          }
	}

      }

      # All other lines are ignored. genfull never generates superflous lines
      # but you never know what people do themselves
    }
  }
  $/ = $delim;
  close INGRAPH;
  printverbose("Input call graph read\n");
  return $HEADER;
}


1;
