# Layout.pm
#
# Module to layout graph elements in some eye pleasing manner depending on 
# the input algorithm
#
# doSpring()  - Layout the nodes based on a spring algorithm

package CodeViz::Layout;
require Exporter;
use vars qw (@ISA @EXPORT);
use strict;
no strict 'refs';

@ISA    = qw(Exporter);
@EXPORT = qw(&doSpring);

# Spring Algorithm parameters
my $relaxedLength = 2;
my $springy = 2;

sub doSpring {
  my %dag = @_;
  my $rLength = $relaxedLength; 
  my $springC = $springy;
  my $springU = $springC * $rLength * $rLength / (2.718 * 2.718);
  my $relaxed = 0;
  my $loop=0;
  my $peakForce=0;
  my $lastForce=0;
  my $force;
  my $dForce;
  my ($x1, $y1, $z1, $x2, $y2, $z2);
  my ($dx, $dy, $dz);
  my ($rx, $ry, $rz);
  my ($fnode, $tnode);

  my %adjacentLabels;
  my @unadjacent;

  while (!$relaxed && $loop < 2000) {
    $loop++;
    if ($loop % 20 == 0) { print "Loop: $loop\n"; }
    $peakForce=0;

    foreach $fnode (%dag) {
      $x1 = $fnode->{'x'};
      $y1 = $fnode->{'y'};
      $z1 = $fnode->{'z'};
      $dx=0;
      $dy=0;
      $dz=0;
      
      # Calculate adjacent nodes
      foreach $tnode (@{$fnode->{'targets'}}) {
        $adjacentLabels{$tnode->{'label'}} = 1;
        $x2 = $tnode->{'x'};
        $y2 = $tnode->{'y'};
        $z2 = $tnode->{'z'};

	# Calculate difference between nodes
	$rx = $x2 - $x1;
	$ry = $y2 - $y1;
	$rz = $z2 - $z1;

	$rLength = getLength(0,0,0, $rx, $ry, $rz);
	$force = calcForce($rLength, 1);
	
	# Calculate distance to move
	$dx += $rx * ($force / $rLength);
	$dy += $ry * ($force / $rLength);
	$dz += $rz * ($force / $rLength);
     }

     # Calculate unadjacent nodes
     foreach $tnode (@{$fnode->{'targets'}}) {
        $adjacentLabels{$tnode->{'label'}} = 1;
	if ($adjacentLabels{$tnode->{'label'}} != 1) {
          $x2 = $tnode->{'x'};
          $y2 = $tnode->{'y'};
          $z2 = $tnode->{'z'};

	  # Calculate difference between nods
	  $rx = $x2 - $x1;
	  $ry = $y2 - $y1;
	  $rz = $z2 - $z1;
  
	  $rLength = getLength(0,0,0, $rx, $ry, $rz);
	  $force = calcForce($rLength, 0);
	
	  # Calculate distance to move
	  $dx += $rx * ($force / $rLength);
	  $dy += $ry * ($force / $rLength);
	  $dz += $rz * ($force / $rLength);

        }
      }

      # Adjust position of node
      $fnode->{'x'} = $x1 + $dx;
      $fnode->{'y'} = $y1 + $dy;
      $fnode->{'z'} = $z1 + $dz;
 
      # Calculate force
      $dForce = getLength(0,0,0, $dx, $dy, $dz);
      if ($peakForce < $dForce) { $peakForce = $dForce; }
      if (abs($lastForce - $peakForce) < 0.2) { $relaxed=1; }
    }

  }
}
sub calcForce($$$) {
  my ($len, $adj) = @_;
  my $rel = $len / $relaxedLength;

  if ($adj) {
    if ($rel > 0) { return $springy * log($rel); }
    else { return -10; }
  } else {
    if ($rel > 0) { return -5 * $springy / ($rel * $rel); }
    else { return 10; }
  }
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
