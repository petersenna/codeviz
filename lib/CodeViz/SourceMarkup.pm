# SourceMarkup.pm
#
# This file contains a routine to render source as HTML files
#
package CodeViz::SourceMarkup;
require Exporter;
use File::Copy;
use CodeViz::Format;
use CodeViz::Output;
use vars qw (@ISA @EXPORT);
use strict;
no strict 'refs';

@ISA = qw(Exporter);
@EXPORT = qw(&sourceMarkup &test_shighlight_installed);

my $SHIGHLIGHT="source-highlight";

sub sourceMarkup($$$$) {
  my ($css, $sourceRoot, $sourceHighlight, $sourceFiles) = @_;

  if ($sourceHighlight) { sourceHighlight($css, $sourceRoot, $sourceFiles); }
  else {

    print("WARNING: --shighlight must be specified to have HTML-marked up pages. Requires source-highlight to be installed.\n");
  }
}

sub sourceHighlight($$$$) {
  my ($css, $sourceRoot, $sourceFilesPtr) = @_;
  my %sourceFiles = %$sourceFilesPtr;
 
  if ($css ne "") { $css = "-c $css"; }

  # Create root directory for HTML files
  my $htmlroot = "$sourceRoot/html_sources";
  mkdir($htmlroot);
    
  foreach my $source ( keys %sourceFiles ) {
    my $htmlpath = "$htmlroot/";
    my $pathpart;
    my $sourcepath = $source;

    # Create the directory needed to store the HTML file
    $sourcepath =~ /(.*)\/.*$/; $sourcepath=$1;
    foreach $pathpart (split /\//, $sourcepath) {
      $htmlpath .= "$pathpart/";
      mkdir($htmlpath);
    }

    # Generate the HTML source file
    my $htmlfile= "$htmlroot/$source.html";
    printverbose("Processing source file: $sourceRoot/$source\n");
    if ( -e "$sourceRoot/$source" ) {
      printverbose("Generating source HTML: $htmlfile\n");
      open( SOURCE, "$SHIGHLIGHT $css -i $sourceRoot/$source -n -s cpp --out-format=html |");
      open( HTML, "> $htmlfile") || die("Failed to open HTML file: $htmlfile");
      while ( <SOURCE> ) {
          s,^(\d+): (.span class="function".(\w+)./span.),<a name="$3">$1<\/A>: $2,
              if /class="function"/;
          print HTML;
      }
      close HTML;
      close SOURCE;
    }
  }
}

# Test to see if source-highlight is installed
sub test_shighlight_installed() {
  my $dir;
  my $found='';

  printverbose("Testing source-highlight\n");

  if ( ! -e $SHIGHLIGHT ) {
    # Check that dot is in path
    foreach $dir (split(/:/, $ENV{"PATH"})) {
      if (-e "$dir/source-highlight") { if ($found eq '') {$found=$dir;} }
    }

    if ($found eq '') {
      print("Notice: source-highlight could not be found in the path. HTML-marked up source will not be generated\n");
    } else { $SHIGHLIGHT = "$found/source-highlight"; }
  }

  printverbose("Source-highlight found at: $SHIGHLIGHT\n");
}


