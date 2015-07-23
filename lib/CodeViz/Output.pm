# Output.pm
#
# This library delegates which handler should be used to render the dot
# graph. Most output mechanisms are some wrapper around dot

package CodeViz::Output;
require Exporter;
use File::Copy;
use CodeViz::Format;
use vars qw (@ISA @EXPORT);
use strict;
no strict 'refs';

@ISA = qw(Exporter);
@EXPORT = qw(&renderGraph &test_dot_installed &test_dot_generate);

my $DOT="dot";	    # Path to dot program

##
# renderGraph - Renders a graph in the desired output format
# $type - Output format
# $in   - Filename of the input graph
# $out  - Filename to output the graph to
sub renderGraph {
  my ($type, $in, $out) = @_;
  my $rendered=0;

  printverbose("Rendering graph for output type: $type\n");
  if ($type eq "ps")         { renderPostscript($in,$out); $rendered=1; }
  if ($type eq "postscript") { renderPostscript($in,$out); $rendered=1; }
  if ($type eq "gif")        { renderGif($in,$out);        $rendered=1; }
  if ($type eq "png")        { renderPng($in,$out);        $rendered=1; }
  if ($type eq "html")       { renderHtml($in,$out,0);
                               my $tmpout = $out;
			       $tmpout =~ s/\.[a-zA-Z]*$//;
			       $tmpout .= ".gif";
                               renderGif($in, $tmpout);    $rendered=1; }
  if ($type eq "tersehtml")  { renderHtml($in,$out,1);     $rendered=1; }
  if ($type eq "plain")      { renderPlain($in, $out);     $rendered=1; }

  # Output functions are expected to output to $outputGraph.dot and
  # have it moved to the real filename here. This is for daemon mode
  # so that clients know the daemon is finished when and only when
  # the final graph appears
  if (-e "$out.dot") { move("$out.dot", $out); }

  # Return 1 if the output format was recognised
  return $rendered;
}

##
# renderPostscript - Render the graph in postscript with dot
sub renderPostscript {
  my ($inputGraph, $outputGraph) = @_;
  printverbose("Rendering postscript with dot\n");
  system("$DOT -Tps -o $outputGraph.dot 2>&1 > /dev/null < $inputGraph");
}

##
# renderPlain - Just output it plain
sub renderPlain {
  my ($inputGraph, $outputGraph) = @_;
  printverbose("Rendering plain output\n");
}

##
# renderGif - Render the graph in gif format with dot
sub renderGif {
  my ($inputGraph, $outputGraph) = @_;
  printverbose("Rendering gif with dot\n");
  system("$DOT -Tgif -o $outputGraph.dot 2>&1 > /dev/null < $inputGraph");
  move("$outputGraph.dot", $outputGraph);
}

##
# renderPng - Render the graph in png format with dot
sub renderPng {
  my ($inputGraph, $outputGraph) = @_;
  printverbose("Rendering png with dot\n");
  system("$DOT -Tpng -o $outputGraph.dot 2>&1 > /dev/null < $inputGraph");
  move("$outputGraph.dot", $outputGraph);
}


## 
# renderHtml - Render a graph in HTML format
sub renderHtml {
  my ($inputGraph, $outputGraph, $tersehtml) = @_;

  # Remove terse from teh extension name if necessary
  if ($tersehtml) { $outputGraph =~ s/tersehtml$/html/; }

  # Render GIF first
  renderGif($inputGraph, $outputGraph);

  printverbose("Generating HTML files\n");
  my $base= ( $outputGraph =~ /(.*)\..*$/ )[0];
  if ($base eq "") { $base = $outputGraph; }

  # generate and read the image-map
  my $cmapfile= "$base.cmap";
  system("$DOT -Tcmap -o $cmapfile < $inputGraph");
  open( CMAP, "< $cmapfile");
  my @cmap= <CMAP>;
  close CMAP;

  # create the HTML file for the function.
  my $funchtml= "$base.html";
  my @html;
  if (!$tersehtml) {
    @html = <<EOF;
<html>
<head>
<title>%%FUNC%%()</title>
<map name="%%FUNC%%">%%CMAP%%</map>
</head>
<body>
<h1>%%FUNC%%()</h1>
<img src="%%FUNC%%.gif" usemap="#%%FUNC%%">
</body>
</html>
EOF
  } else {
    @html = <<EOF;
<map name="%%FUNC%%">%%CMAP%%</map>
<img src="%%FUNC%%.gif" usemap="#%%FUNC%%">
EOF
  }

  printverbose("Generating main   HTML: $funchtml\n");
  open( HTML, "> $funchtml");
  # this works b/c $base <= $OUTPUT <= $afunc <= the first func in the list.
  print HTML map { s/%%FUNC%%/$base/g; s/%%CMAP%%/@cmap/; $_ } @html;
  close HTML;

}

##
# test_dot_installed - Finds the path to dot from the graphviz package
sub test_dot_installed() {
  my $dir;
  my $found='';
  printverbose("Testing GraphViz\n");

  if ( ! -e $DOT ) {
    # Check that dot is in path
    foreach $dir (split(/:/, $ENV{"PATH"})) {
      if (-e "$dir/dot") { if ($found eq '') {$found=$dir;} }
    }

    if ($found eq '') {
      die_nice("dot from GraphViz could not be found in the path. Install GraphViz
from your distribution CD or download from http://www.graphviz.org/ .

Daemon exiting\n");
    } else { $DOT = "$found/dot"; }
  }

  printverbose("Dot found at: $DOT\n");
}

# Test that dot can generate proper graphs
# $type   - Test for a given output type. Currently only gif is tested as it is only weird one
# $header - The header to use for generating graphs. Should be read from full.graph
# returns - The header that was finally used to generate graphs
sub test_dot_generate($$$) {
  my ($type, $font, $header) = @_;
  my $line;

  if ($type eq "ps" || $type eq "postscript") {
    # Check that dot can generate a postscript graph
    printverbose("Testing GraphViz Postscript Generation\n");
    unlink("/tmp/codeviz_test.ps");
    open(TPIPE, "|$DOT -Tps -o /tmp/codeviz_test.ps");
    print TPIPE $header;
    print TPIPE "code -> viz;\n";
    print TPIPE "};";
    close TPIPE;
    if (! -e "/tmp/codeviz_test.ps") {
      die_nice("Dot is unable to generate a simple postscript file in /tmp/\n");
    }
    unlink("/tmp/codeviz_test.ps");
  }

  if ($type eq "gif" || $type =~ /html/) {
    # Check that dot can generate a GIF graph
    printverbose("Testing GraphViz GIF Generation with $font\n");
    unlink("/tmp/codeviz_test.gif");
    open(TPIPE, "|$DOT -Tgif -o /tmp/codeviz_test.gif 2> /tmp/codeviz.err");
    print TPIPE $header;
    print TPIPE "code -> viz;\n";
    print TPIPE "};";
    close TPIPE;
    if (! -e "/tmp/codeviz_test.gif") {
      printverbose("Generation with $font failed. Trying Arial\n");
    }

    # Check that no error occured while generating GIFs. On my machine,
    # $font cannot be used to generate GIFs but Arial can. This is not a
    # critical error but the GIF output is horrible otherwise
    if (open (TPIPE, "/tmp/codeviz.err")) {
      $line = <TPIPE>;
      close TPIPE;
      if ($line =~ /Could not find/ || ! -e "/tmp/codeviz_test.gif") {
        # An error occured :-(
        # Check if this works with the Arial font. Dot on my machine wouldn't
        # work with $font but did with Arial. I am guessing that Arial is
        # a much more common format
        printwarning("Cannot render with $font font. Falling back to Arial\n");
        $header =~ s/$font/Arial/;
        open(TPIPE, "|$DOT -Tgif -o /tmp/codeviz_test.gif 2> /tmp/codeviz.err");
        print TPIPE $header;
        print TPIPE "code -> viz;\n";
        print TPIPE "};";
        close TPIPE;

        # Test for errors again
        if (open (TPIPE, "/tmp/codeviz.err")) {
          $line = <TPIPE>;
          close TPIPE;
          if ($line =~ /Could not find/) {
	    print STDERR "\nWARNING: Could not generate GIFs with $font or Arial fonts\n";
	    print STDERR "         GIF call graphs generated for browsers are likely to\n";
	    print STDERR "         to look horrible. On Debian, this fonts are available\n";
            print STDERR "         with the msttcorefonts package. Other distributions\n";
            print STDERR "         should have similar packages.\n\n";
	  }
        }
      }
    }
    unlink("/tmp/codeviz.err");
    unlink("/tmp/codeviz_test.gif");
  }

  return $header;
}

1;
