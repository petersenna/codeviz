# PPStack.pm
#
# This is a post-processing module that uses an excerpt from oprofile
# to determine how much time was spent in each function

package CodeViz::PPOprofile;
require Exporter;
use vars qw (@ISA @EXPORT);
use strict;
use CodeViz::Graph;
use CodeViz::Format;
no strict 'refs';

@ISA =    qw(Exporter);
@EXPORT = qw(&PPOprofile);

sub usage() {
  print <<EOF;

The supported options for the Oprofile postprocessing are:

  profile            String, path to the oprofile report to read
  eventfield         Int, The field index that the counters are stored in

EOF
  exit;
}

sub PPOprofile {
  my ($options, $dag) = @_;
  my ($profile, $eventfield, $eventvalue);
  my ($param, $value);
  my $func;
  my $option;
  my $line;
  my ($fieldno, $field);
  my %funccosts;
  if ($options eq 'help') { usage(); }

  printverbose("Post-Processing: Oprofile function costs\n");

  # Add a , if necessary to help parsing
  if ($options !~ /.*=.*,/) { $options .= ","; }

  # Parse all options
  $eventfield = 0;
  foreach $option (split /,/, $options) {
    ($param, $value) = split /=/, $option;
    if ($param eq "profile")  { $profile = $value; next; }
    if ($param eq "eventfield") { $eventfield = $value; next; }

    # Unknown option, show usage
    usage();
  }

  # Read the profile
  open (PROFILE, $profile) || die("Failed to open profile $profile");
  printverbose("PPOprofile: Opened $profile\n");
  while (!eof(PROFILE)) {
  	$line = <PROFILE>;
	$fieldno = 1;
	my $lastfield;
	foreach $field (split /\s+/, $line) {
		if ($fieldno == $eventfield) {
			$eventvalue = $field;
		}
		$lastfield = $field;
		$fieldno++;
	}
	$funccosts{$lastfield} = $eventvalue;
  }
  close(PROFILE);
  printverbose("PPOprofile: Closed profile\n");

  # Process the full graph
  printverbose("PPOprofile: Processing graph\n");
  foreach $func (keys %$dag) {

    # Get the node label and stack usage information
    my $label = getNodeAttribute("label",    \$$dag{$func});

    if ($funccosts{$func} == 0) {
      $funccosts{$func} = 0;
    }

    # Add the function cost label
    if ($label ne "") { $label .= "\\ncost=$funccosts{$func}"; }
    else              { $label =  "$func\\ncost=$funccosts{$func}"; }
    setNodeAttribute("label", $label, \$$dag{$func});
  }
  printverbose("PPOprofile: Done\n");
}

1;
