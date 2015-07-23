# Collect.pm
#
# This is the high level library for collecting data for generating the 
# full.graph file. At the time of writing, the only method is through the
# reading of .cdepn files in a source directory but there will be more in
# the future for other collection methods and languages. When a new one
# is created, it is added via this library. Different collection methods
# are simply identified by string
#
# Each collection module is expected to export one function. The return value
# should be 0 on success and -1 on failure. The return value is initialised to 
# -2 so that unrecognised methoid invocation can be recognised
#

use lib ".";
package CodeViz::Collect;
use CodeViz::CollectCXref;
use CodeViz::CollectCppDepn;
use CodeViz::CollectCObjdump;
use CodeViz::CollectCNcc;
use CodeViz::Graph;
require Exporter;
use vars qw (@ISA @EXPORT);
use strict;
no strict 'refs';

@ISA    = qw(Exporter);
@EXPORT = qw(&gen_fullgraph);

# gen_fullgraph - Collect data and output a full graph
# $method   - Data collection method
# $toplevel - Top level source directory
# $files    - Specific files that are to be scanned or used
# $subdirs  - List of subdirectories to graph
# $output   - Output graph name
#
sub gen_fullgraph {
  my ($method, $toplevel, $files, $subdirs, $output) = @_;
  my $handle;
  my $retval=-2;

  $handle = openGraph($output);
  
  # C Handlers
  $retval = generate_cdepn     ($toplevel, $files, $subdirs, $handle) if $method eq "cdepn";
  $retval = generate_cncc      ($toplevel, $files, $subdirs, $handle) if $method eq "cncc";
  $retval = generate_cobjdump  ($toplevel, $files, $subdirs, $handle) if $method eq "cobjdump";

  # C++ Handlers
  $retval = generate_cppobjdump($toplevel, $files, $subdirs, $handle) if $method eq "cppobjdump";
  $retval = generate_cppdep($toplevel, $files, $subdirs, $handle) if $method eq "cppdepn";

  closeGraph($handle);

  if ($retval == -2) {
    print "Collection method '$method' unknown\n";
  }
  
  return $retval;
}
