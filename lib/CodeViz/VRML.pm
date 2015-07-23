# VRML.pm
# VRML Render package for graphs in perl. Each node in the graph is expected
# to be a hash array
#
# (c) Mel Gorman 2002

package CodeViz::VRML;
use Math::Complex;
require Exporter;
use vars qw (@ISA @EXPORT);
use strict;
no strict 'refs';

@ISA    = qw(Exporter);
@EXPORT = qw(&VRMLRender &createCamera);

my %cameras;
my $numCameras=0;

# Graph drawing parameters
my $NODE_RADIUS   = 0.5;	  # Radius of a node
my $NODE_COLOR    = "1 0.95 0.7"; # Color of a node
my $DUMB_RADIUS   = 0.25;	  # Radius of a dummy node
my $DUMB_COLOR	  = "1 0 0";	  # Color of a dummy node
my $EDGE_DIAMETER = 0.1;	  # Diameter of an edge
my $EDGE_COLOR    = "0.5 0.5 1";  # Color of an edge
my $SKY_COLOR	  = "0.9 0.9 1";  # Color of the background
my $FONT_SIZE	  = 1;		  # Font size
my $TRANSPARENCY  = "0.5";	  # How transparent items are

# Subroutine to render a supplied DAG to the output filename
sub VRMLRender {
  my ($outputFile, %dag) = @_;
  my ($callernode, $calleenode);

  # Open output file
  if (!open(VRML, ">$outputFile")) {
    print "Failed to open output VRML file ($outputFile)\n";
    return 0;
  }

  printVRMLHead();

  # Render all nodes
  foreach $callernode (%dag) {
    printVRMLNode(\$callernode);
  }

  # Render all edges
  foreach $callernode (%dag) {
    foreach $calleenode (@{$callernode->{'targets'}}) {

      printVRMLEdge(\$callernode, $calleenode);
    }
  }
  printVRMLFoot();
  close VRML;
}

sub createCamera {
  my ($x, $y, $z) = @_;

  $cameras{$numCameras}->{'x'} = $x;
  $cameras{$numCameras}->{'y'} = $y;
  $cameras{$numCameras}->{'z'} = $z;
  $numCameras++;
}

sub printVRMLHead {
  my ($x, $y, $z, $index);

  print VRML <<EOF
WorldInfo {
  title "Gengraph VRML Generator, Copyright Mel Gorman 2002"
  info  "Automatically generated from call graph, mel\@csn.ul.ie"
}
EOF
;
  for ($index=0; $index<$numCameras; $index++) {
    $x = $cameras{$index}->{'x'};
    $y = $cameras{$index}->{'y'};
    $z = $cameras{$index}->{'z'};
    print VRML <<EOF

Viewpoint {
  description "main"
  position $x $y $z
}
EOF
  }

  print VRML <<EOF

Background {
  skyColor $SKY_COLOR
}

Transform {
  translation 0 0 0
  children [
EOF
}

# Returns the distance between two points
sub getLength($$$$$$) {
  my ($x1, $y1, $z1, $x2, $y2, $z2) = @_;
  my ($dx, $dy, $dz);
  my ($dsquared, $dist);

  $dx = ($x1 - $x2);
  $dy = ($y1 - $y2);
  $dz = ($z1 - $z2);
  
  $dsquared = $dx*$dx + $dy*$dy + $dz*$dz;
  $dist = sqrt($dsquared);
  
  return $dist;
}   

sub printVRMLEdge {
  my ($fnode, $tnode) = @_;
  my ($x1, $y1, $z1, $x2, $y2, $z2);
  my ($mx, $my, $mz);
  my ($dx, $dy, $dz);
  my ($rx, $rf);
  my ($dist);
  my $radian = 3.141592654 / 180;
  
  # Get co-ordinates as perl cannot pass in more than
  # one hash reference at a time
  $x1 = $$fnode->{'x'};
  $y1 = $$fnode->{'y'};
  $z1 = $$fnode->{'z'};
  $x2 = $$tnode->{'x'};
  $y2 = $$tnode->{'y'};
  $z2 = $$tnode->{'z'};


  $mx = ($x1 + $x2) / 2;
  $my = ($y1 + $y2) / 2;
  $mz = ($z1 + $z2) / 2;

  $dx = ($x1 - $x2);
  $dy = ($y1 - $y2);
  $dz = ($z1 - $z2);

  $dist = getLength($x1, $y1, $z1, $x2, $y2, $z2);

  if ($dy   == 0) { $dy = 0.01; }
  if ($dist == 0) { $dist = 0.01; }

  $rx   = -atan(-$dz/$dy);
  $rf   = asin($dx/$dist);

  $dy   = -$dy;
  $dist -= 1;

  print VRML <<EOF
    Transform {
      rotation 0 $dz $dy $rf
      translation $mx $my $mz
      children [
        Transform {
          rotation 1 0 0 $rx
          children [
            Shape {
              appearance Appearance {
                material Material {
                  diffuseColor $EDGE_COLOR
                  transparency $TRANSPARENCY
                }
              }
              geometry Cylinder {
                height $dist
                radius $EDGE_DIAMETER
              }
            }
          ]
        }
      ]
    }
EOF
}


sub printVRMLNode {
  my $node = shift;
  my $len;
  my ($x, $y, $z, $label);
  my ($tx, $ty, $tz);
  $x = $$node->{'x'};
  $y = $$node->{'y'};
  $z = $$node->{'z'};
  $tx = $x;
  $ty = $y;
  $tz = $z;
  $label = $$node->{'label'};
  if ($label eq "") { return; }

  # Try and center the text a bit
  $len = length($label);
  $tx -= $len / 8;

print VRML <<EOF
    Transform {
      translation $tx $ty $tz
      children [
        Shape {
	  appearance Appearance {
	    material Material {
	      diffuseColor 0 0 1
	    }
	  }

	  geometry Text {
	    string [ "$label" ]
	    fontStyle FontStyle {
	      size $FONT_SIZE
            }
	  }
	}
      ]
    }

    Transform {
      translation $x $y $z
      children [

	Shape {
	  appearance Appearance {
	    material Material {
	      diffuseColor $NODE_COLOR
	      transparency $TRANSPARENCY
	    }
	  }
	  geometry Sphere {
	    radius $NODE_RADIUS
	  }
	}
      ]
    }
EOF
}

sub printVRMLFoot {
  print VRML "  ]\n}\n";
}

