#!/usr/bin/perl
# Based on genxref.pl 
#        extremely fuzzy algorithm.  It sort of works.
#
#    Arne Georg Gleditsch <argggh@ifi.uio.no>
#    Per Kristian Gjermshus <pergj@ifi.uio.no>
#
# Originally part of the LXR project. 
# Adapted for CodeViz by Mel Gorman <mel@csn.ul.ie>
#
# For CodeViz, This basically works as follows
#
# readcdepn:
#   o Search all .cdepn files
#   o Create three hash arrays
#     cdepncloc - maps source:line     ->    caller~callee
#     cdepncall - maps caller~callee   ->    source:line
#     headers  - maps headers used    ->    1
#
# findident
#   o Search all .c and . h files
#   o Create two hash arrays
#     fdecl - maps  macro_name   ->  source:line:
#                   functions    ->  source:line:scope
#
# findusage
#   o Search all .c and .h files
#   o Create two hash arrays
#     xrefcloc - maps source:line     ->    caller~callee
#     xrefcall - maps caller~callee   ->    source:line
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

package CodeViz::CollectCXref;
use CodeViz::Graph;
use CodeViz::Format;
require Exporter;
use vars qw (@ISA @EXPORT);

@ISA    = qw(Exporter);
@EXPORT = qw(&generate_cdepn);

my $propdepth=2;

use lib 'lib/';
use integer;
use DB_File;

my %itype = (('macro',     'M'),
             ('macrofunc', 'P'),
             ('typedef',   'T'),
             ('struct',    'S'),
             ('enum',      'E'),
             ('union',     'U'),
             ('function',  'F'),
             ('funcprot',  'f'),
             ('class',     'C'),    # (C++)
             ('classforw', 'c'),    # (C++)
             ('var',       'V'));

my @reserved = ('auto', 'break', 'case', 'char', 'const', 'continue',
         'default', 'do', 'double', 'else', 'enum', 'extern',
         'float', 'for', 'goto', 'if', 'int', 'long', 'register',
         'return', 'short', 'signed', 'sizeof', 'static',
         'struct', 'switch', 'typedef', 'union', 'unsigned',
         'void', 'volatile', 'while', 'fortran', 'asm',
         'inline', 'operator',
         'class',        # (C++)
         '__asm__','__inline__');


my $ident = '\~?_*[a-zA-Z][a-zA-Z0-9_]*';

my $realpath;     # Real path of toplevel source tree
my $outgraph;     # Output graph handle
my %fdecl;        # Hash table of function declarations
my %fileidx;      # Hash table of filenames to ID as ordered by find
my %C;            # Hash table of function calls
my %cdepnfdecl;    # Hash table of where functions are declared in .cdepn files
my %cdepncloc;     # Hash table of where functions are called in .cdepn files
my %cdepncall;     # Hash table of function calls that occur in .cdepn files
my %xrefcloc;     # Hash table of where functions are called parsed directly
my %xrefcall;     # Hash table of function calls that occur parsed directly
my %headers;      # Hash table of headers referenced by .cdepn files
my $cpp;          # Boolean indicating if cpp files are being parsed
my %funccollide;  # List of functions that collided
my $funccount=0;  # Count of the number of functions that collided
my $collisions=0; # Number of naming collisions that occured
my $resolved=0;   # Number of collisions that were resolved
my $progstart;    # Starting time of the program

# Toplevel function for C files. As well as parsing, it'll check the
# .cdepn files and compare the two outputs
sub generate_cdepn {
  my ($toplevel, $files, $subdirs, $handle) = @_;

  return generate_cxref($toplevel, $files, $subdirs, $handle);
}

sub parseDeclaration($) {
  my ($decl) = $_[0];
  $decl =~ s/\[.*\]//g;
  $decl =~ s/^{//;
  $decl =~ s/}$//;

  # Split by elements to remove the return type
  my @elements = split(/ /, $decl);
  if ($#elements == 0) {
    return $elements[0];
  }

  my $index=1;
  if (@elements[0] =~ /</) {
    # Find end of arguments
    while ($elements[$index] !~ />/ && $index <= $#elements) { $index++; }
    $index++;
  }

  # Get the function name
  $decl="";
  while ($index <= $#elements) {
    $decl .= $elements[$index];
    if ($decl !~ /,$/) { $decl .= " "; }
    $index++;
  }

  $decl =~ s/\s*$//;
  $decl =~ s/\}$//;
  return $decl;
}

# Main codeviz function
sub generate_cxref {
  my ($toplevel, $files, $subdirs, $handle) = @_;
  $realpath = $toplevel;
  $outgraph = $handle;
  my $toplevel_escaped = $toplevel;
  $toplevel_escaped =~ s/\//\\\//g;

  $progstart = time;
  # Create a list of files to scan.
  $start = printstart("Finding input files");
  if ($files != -1) {
    open(FILES, "echo $files | tr \" \" \"\n\"|")
  } else {
    open(FILES, "find $subdirs -print |");
  }

  while (<FILES>) {
    chop;
    my $file = $_;
    push(@f, $file) if $file =~ /\.(h|hh)$/i;
    if ($file =~ /.cdepn$/) {
      $file =~ s/\.cdepn$//g;
      push(@f, $file);
    }
    
  }
  close(FILES);

  printcomplete($start, $#f+1 . " files found");

  &readcdepn;
  &findident(0);
  &findident(1);
  &findusage;
  &generatecall;
  &dumplabels;
  &dumpgraph;
  &print_collision_count($collisions, $resolved);

  printline("\ngenfull complete: Total duration was " . (time - $progstart) . " seconds\n");

  return 0;
}

# This function searches cdepn files and reads the available information from
# them
sub readcdepn {
  $fnum=0;
  $defs=0;

  # Read cdepn files
  $start = printstart("Reading cdepn files");
  foreach $f (@f) {
    $fnum++;
    $f =~ s/^$realpath//o;
    $baref = $f;
    $baref =~ s/.*\///;
    open(CDEPFILE, $realpath.$f.".cdepn") || next;
    printprogress($f, -1, $fnum, $#f+1);
  
    while (!eof(CDEPFILE)) {
      $line = <CDEPFILE>;
      # Read a function declaration line
      if ($line =~ /^F {(.*)} {(.+):(.+)}/) {
        my $fdecl = $1;
        $file = $f;
        $file =~ s/\.cdepn//;
	# Strip out the source root if it's in the filename
	if ($file =~ /^$toplevel_escaped/) {
	  $file =~ s/^$toplevel_escaped//;
	}
	$file .= "\:$3";
	$caller = parseDeclaration($fdecl);

        $cdepnfdecl{$caller} = "$file";
      }

      # Read a function call line
      if ($line =~ /^C {(.*)} {(.+):(.+)}\s+(.+)/) {
        $caller = parseDeclaration($1);
	$callee = parseDeclaration($4);
        $line   = $3;
	$file   = $2;
	$file =~ s/\:$//;

        # Check if the filename is a header
        if (isheader($2)) {
          # It is, record this header file was accessed
          $file =~ s/^$realpath//o;
          $headers{$file} = 1;
        }

	# Strip out the source root if it's in the filename
	if ($file =~ /^$toplevel_escaped/) {
	  $file =~ s/^$toplevel_escaped//;
	}

        # Only record the function call if its in the same source file
        if ($f eq $file || $baref eq $file || isheader($file)) {
          $cdepncloc{"$f:$line"} = "$caller~$callee";
	  if (isheader($file)) {
            $cdepncall{"$caller~$callee"} = "$caller~$file:$line ";
	  } else {
            $cdepncall{"$caller~$callee"} .= "$caller~$f:$line ";
	  }
        } else {

	  if ($caller eq "__alloc_pages" || $callee eq "__alloc_pages") { 
	    print "HERE: $caller -> $callee\n"; 
	    print "f: $f\n";
	    print "file: $file\n";
	    print "baref: $baref\n";
	  }
	}
      }

      $defs++;
    }
    close CDEPFILE;

  }

  printcomplete($start, "$defs function calls found");
}

# This function searches all .c and .h files and looks for identifiers and
# declarations.
sub findident {
  $honly = $_[0];

  if ($honly) {
    $start = printstart("Collect identifier definitions for C/C++ files");
  } else {
    $start = printstart("Collect identifier definitions for headers");
  }
   
  $fnum = 0; $defs = 0;

  foreach $f (@f) {
    $f =~ s/^$realpath//o;
    $fileidx{++$fnum} = $f;

    # If scanning headers, only scan ones known to be in use
    if ($honly && !isheader_used($f)) {
      printprogress($f, 0, $fnum, $#f+1);
      next;
    } 

    # If scanning C files, only use ones that a .cdepn file exists for
    if (!$honly && (! -e "$realpath$f.cdepn")) {
      printprogress($f, 0, $fnum, $#f+1);
      next;
    }

    # Read full source file
    open(SRCFILE, $realpath.$f);
    $_ = $/; undef($/); $contents = <SRCFILE>; $/ = $_;
    close(SRCFILE);

    printprogress($f, length($contents), $fnum, $#f+1);

    # Remove comments.
    $contents =~ s/\/\*(.*?)\*\//&wash($1)/ges;
    $contents =~ s/\/\/[^\n]*//g; # C++

    # Track the headers used
    $_ = $contents;
    foreach $header (m/^[ \t]*\#include[ \t]+<(.*)>.*[^\n]*/gm) {
      $headers{$header} = 1;
    }

    # Unwrap continunation lines.
    $contents =~ s/\\\s*\n/$1\05/gs;
    while ($contents =~ s/\05([^\n\05]+)\05/$1\05\05/gs) {}
    $contents =~ s/(\05+)([^\n]*)/"$2"."\n" x length($1)/gse;

    # Find macro (un)definitions.
    $l = 0;
    my ($currmacro, $inmacro);
    foreach ($contents =~ /^(.*)/gm) {
      $l++;

      # See if we are entering a macro of some sort that is #defined
      if (/^[ \t]*\#\s*(define|undef)\s+($ident)(.*)/o) {
        my $macroline = $_;
        $macro = $2;

        if ($3 =~ /^\((.*)\)/) { 
	  $loc = "$f:$l:";
  
	  # Record the macro declaration
          $fdecl{$macro} = $loc;
          $xref{$macro} .= "$itype{'macro'}$fnum:$l\t";
          $defs++;

	  # Record calls
	  foreach ($macroline =~ /([a-zA-Z0-9_]*)\s?\(/g) {
	    if ($_ ne $macro &&
	        $_ !~ /(while|for|if)/) {
	      if ($macro =~ /oom_kill/) {
	        print "DEBIG: $macro~$_\n";
	      }
	      $cdepncloc{"$f:$line"} = "$macro~$_";
	      $cdepncall{"$macro~$_"} .= "$macro~$f:$l ";

	    }
	  }

        }
      }

    }
  
    # We want to do some funky heuristics with preprocessor blocks
    # later, so mark them. (FIXME: #elif)
    $contents =~ s/^[ \t]*\#\s*if.*/\01/gm;
    $contents =~ s/^[ \t]*\#\s*else.*/\02/gm;
    $contents =~ s/^[ \t]*\#\s*endif.*/\03/gm;
  
    # Strip all preprocessor directives.
    $contents =~ s/^[ \t]*\#(.*)//gm;
  
    # Now, remove all odd block markers ({,}) we find inside
    # #else..#endif blocks.  (And pray they matched one in the
    # preceding #if..#else block.)
    while ($contents =~ s/\02([^\01\02\03]*\03)/&stripodd($1)/ges ||
         $contents =~ s/\01([^\01\02\03]*)\03/$1/gs) {}

    while ($contents =~ /([\01\02\03\04\05])/gs) {
      printwarning("** stray ".($1 eq "\01"  
             ? "#if"
             : ($1 eq "\02"
              ? "#else"
              : ($1 eq "\03"
                 ? "#endif"
                 : "control sequence"
                 )
              )
             )." found in $f at line $l");
    }
    $contents =~ s/[\01\02\03\04\05]//gs;
  
    # Remove all but outermost blocks.  (No local variables.)
    while ($contents =~ s/\{([^\{\}]*)\}/
         "\05".&wash($1)/ges) {}
    $contents =~ s/\05/\{\}/gs;
  
    # Remove nested parentheses.
    while ($contents =~ s/\(([^\)]*)\(/\($1\05/g ||
         $contents =~ s/\05([^\(\)]*)\)/ $1 /g) {}
    
    # Parentheses containing commas are probably not interesting.
    $contents =~ s/\(([^\)]*\,[^\)]*)\)/
      "()".&wash($1)/ges;
  
    # This operator-stuff messes things up. (C++)
    $contents =~ s/operator[\<\>\=\!\+\-\*\%\/]{1,2}/operator/g;
  
    # Ranges are uninteresting (and confusing).
    $contents =~ s/\[.*?\]//gs;
  
    # And so are assignments.
    $contents =~ s/\=(.*?);/";".&wash($1)/ges;
  
    # From here on, \01 and \02 are used to encapsulate found
    # identifiers,
  
    # Find struct, enum and union definitions.
    $contents =~ s/((struct|enum|union)\s+($ident|)\s*({}|(;)))/
      "$2 ".($3 ? "\01".$itype{$2}.$3."\02 " : "").$5.&wash($1)/goes;
  
    # Find class definitions. (C++)
    $contents =~ s/((class)\s+($ident)\s*(:[^;\{]*|)({}|(;)))/
      "$2 "."\01".$itype{$2.($6 ? 'forw' : '')}.
      &classes($4).$3."\02 ".$6.&wash($1)/goes;
  
    @contents = split(/[;\}]/, $contents);
    $contents = '';
  
    foreach (@contents) {
      s/^(\s*)(struct|enum|union|inline)/$1/;
  
      if (/$ident[^a-zA-Z0-9_]+$ident/) {
  
        $t = /^\s*typedef/s;  # Is this a type definition?
    
        s/($ident(?:\s*::\s*$ident|))  # ($1) Match the identifier
          ([\s\)]*                     # ($2) Tokens allowed after identifier
           (\([^\)]*\)                 # ($3) Function parameters?
            (?:\s*:[^\{]*|)            # inheritage specification (C++)
            |)                         # No function parameters
           \s*($|,|\{))/               # ($4) Allowed termination chars.
          "\01".                       # identifier marker
           ($t                         # if type definition...
          ? $itype{'typedef'}          # ..mark as such
          : ($3                        # $3 is empty unless function definition.
             ? ($4 eq '{'              # Terminating token indicates 
            ? $itype{'function'}       # function or
            : $itype{'funcprot'})      # function prototype.
             : $itype{'var'})          # Variable.
          )."$1\02 ".&wash($2)/goesx;
      }

      $contents .= $_;
    }
  
    $l = 0; 
    foreach ($contents =~ /^(.*)/gm) {
      $l++;
      while (/\01(.)(?:(.+?)\s*::\s*|)($ident)\02/go) {
        $f1 = $3;
        $type = $1;
	$loc = "$f:$l:";
  
        if ($cpp && $2) { 
          $scope = $2;
          $f1 =~ s/<.*>//g;
        }
  
        if ($fdecl{$f1}) {
	  $loc = resolvecollision($f1, $fdecl{$f1}, "$f:$l:", $type);
        }
  
        # Dump if this is a function declaration
        if ($type eq $itype{'function'}   ||
            $type eq $itype{'macrofunc'}  ||
            $type eq $itype{'classforw'}    ) {

          $fdecl{$f1} = "$loc$scope";
          $xref{$f1} .= "$f1$fnum:$l".($2 ? ":$2" : "")."\t";
          $defs++;
        }
      }
    }
  
    # Så juksar me litt.
    foreach (@reserved) {
      delete($xref{$_});
    }
  
  }  
  
  printcomplete($start, "$defs definitions found");
}

sub findusage {
  $start = time;
  $fnum = 0; $refs = 0;
  $defs=0;
   
  $start = printstart("Generate reference statistics");
  foreach $f (@f) {
    $f =~ s/^$realpath//o;
    $fnum++;
    $lcount = 0;

    # Check if a cdepn file was generated for this file and skip if not
    if ((! -e "$realpath$f.cdepn") && !isheader_used($f)) {
      printprogress($f, 0, $fnum, $#f+1);
      next;
    }

    open(SRCFILE, $realpath.$f);
    $_ = $/; undef($/); $contents = <SRCFILE>; $/ = $_;
    close(SRCFILE);

    printprogress($f, length($contents), $fnum, $#f+1);

    # Remove comments
    $contents =~ s/\/\*(.*?)\*\//&wash($1)/ges; 
    $contents =~ s/\/\/[^\n]*//g;

    # Remove include statements
    $contents =~ s/^[ \t]*\#include[ \t]+[^\n]*//gm;

    @lines = split(/\n/, $contents);
    my $bcount;

    foreach $line (@lines) {
      $lcount++;
      if ($line =~ /{/) { $bcount++; }
      if ($line =~ /}/) { $bcount--; }
      if ($bcount == 0) { $currfunc = ""; }

      foreach ($line =~ /(?:^|[^a-zA-Z_\#])($ident)\b/og) {
        # Check to see have we recorded any type of function information here
	my ($tda, $tdb);
        if ($fdecl{$_}) {
	  $tda = $_;
	  $tdb = $fdecl{$_};
	  
	  # Check if this is entering a new function of if it is a call
          if ($fdecl{$_} =~ /$f:$lcount:(.?)/) {

	    # Entered new function
            $currfunc  = $_; 
            if ($cpp && $1) { $currfunc = "$1\::$currfunc"; }

          } else { 

            if ($currfunc eq "") { next; }

            # This looks like a function call
            $callee = $_;
	    
            # If C++, then find the scope we're in based on the cdepn file
            if ($cpp) {
              ($f1, $f2) = split(/~/, $cdepncloc{"$f:$lcount"});
              if ($f2 =~ /::/) {
                ($scope, $dummy) = split(/::/, $f2);
                $callee = "$scope\::$callee";
              }
            }

            # Record the function call
	    $xrefcloc{"$f:$lcount"} = "$currfunc~$callee";
	    $xrefcall{"$currfunc~$callee"} = "$f:$lcount";

          }
        }
      }
    }

  }

  printcomplete($start, "$refs references to known identifiers found");
}

# Generate the call graphs based on the %cdepncall and %xrefcall arrays. Use
# %cdepncall as the primary reference
sub generatecall {
  my ($caller, $callee);
  my ($call, $locs, $loc);
  my ($source, $line);
  my ($found);

  # First dump out all cdepn related information because it is the closest to
  # being accurate
  foreach (keys %cdepncall) {
    $call = $_;
    $locs  = $cdepncall{$call};
    $found=0;

    # If cdepncall and xrefcall match exactly, record them and continue
    if ($cdepncall{$call} && $xrefcall{$call}) {
      $C{$call} = $locs;
      delete($xrefcall{$call});

      # Delete each reference to this function call for each location in
      # the source it occurs on
      foreach $loc (split(/ /, $locs)) {
        delete($xrefcloc{$loc});
      }

      # Move to the next key
      next;
    }

    # Check each location this function call was made and see do any of them
    # match a macro. Awkward and probably could be done better
    foreach $loc (split(/ /, $locs)) {
      if ($cdepncloc{$loc} && $xrefcloc{$loc}) {
        $found=1;
        $C{ $xrefcloc{$loc} } = $loc;
        delete($xrefcall{ $xrefcloc{$loc} });
        delete($xrefcloc{$loc});
      }
    }

    # Else just presume cdepn is right. This will miss function calls which
    # span multiple lines
    if (! $found) { 
    	foreach $loc (split(/ /, $locs)) {
    		$C{$call} = $loc;
	}
    }
  }

  # Dump out all xrefcalls that are in header files
  foreach (keys %xrefcall) {
    $call = $_;
    $loc = $xrefcall{$call};
    ($source, $line) = split(/:/, $loc);
    

    if (isheader_used($source)) {
      $C{$call} = $loc;
    }
  }

}

# Returns if a header is in use or not
sub isheader_used {
  $file = $_[0];
  return 1 if $headers{$file} == 1;

  $file =~ /.*\/(.*\/.*)$/;
  return 1 if $headers{$1} == 1;

  $file =~ /.*\/(.*\/.*\/.*)$/;
  return 1 if $headers{$1} == 1;
  
  return 0;
}

# Returns if a filename looks like a header or not
sub isheader {
  return $_[0] =~ /\.h$/;
}


sub wash {
  my $towash = $_[0];
  $towash =~ s/[^\n]+//gs;
  return($towash);
}

sub stripodd {
  my $tostrip = $_[0];
  while ($tostrip =~ s/\{([^\{\}]*)\}/
     "\05".&wash($1)/ges) {}
  $tostrip =~ s/\05/\{\}/gs;
  $tostrip =~ s/[\{\}]//gs;
  return($tostrip);
}

sub classes {
  my @c = (shift =~ /($ident)\s*(?:$|,)/gm);
  if (@c) {
    return(join(":", @c)."::");
  } else {
    return('');
  }
}

sub resolvecollision {
  my ($func, $first, $second, $typesecond) = @_;
  $collisions++;

  # If the second type is a function prototype, favour the first
  if ($typesecond eq $itype{'funcprot'}) { $resolved++; return $first; }

  # Extract the source file and line for both occurances
  ($sourcea, $linea) = split(/:/, $first);
  ($sourceb, $lineb) = split(/:/, $second);

  if ($cdepnfdecl{$func}) { 
    # If the declaration is in a cdepn file, use the cdepn file to resolve it
    ($sourcecdepn, $linec) = split(/:/, $cdepnfdecl{$func});

    if ($sourcea eq $sourceb) {
       # If the two source files are the same, resolve it by returning the 
       # source line closest to the .cdepn declaration. This will handle the 
       # case where functions are conditionally declared in a single source
       # file

      $diffa = abs ($linec - $linea);
      $diffb = abs ($linec - $lineb);

      $resolved++; 
      if ($diffa > $diffb) { return $second; }
      else                 { return $first;  }
    }

    if ($sourcea eq $sourcecdepn) { $resolved++; return $first;  }
    if ($sourceb eq $sourcecdepn) { $resolved++; return $second; }

  }

  # When colliding between a .c file and a .h, give preference to the header
  if (isheader($sourcea) && !isheader($sourceb)){ $resolved++; return $first;  }
  if (isheader($sourceb) && !isheader($sourcea)){ $resolved++; return $second; }

  # When there is two collisions in the same file, check if the second is
  # a macro definition. If it is, chances are the function is a debugging
  # function which is turned into an empty macro when debugging is off
  if ($sourcea eq $sourceb) {
    $resolved++;
    if ($typesecond eq $itype{'macro'}) { return $second; }
    else { return $first; }
  }
  
  # Record the first collision
  if (!$funccollide{$func}) {
    $funccount++;
    $funccollide{$func} = $first;
  }

  printcollision($func, $funccollide{$func}, $second);
  return "name_collision:-1:";
}

sub FuncFileSort {
  my ($lFunc, $rFunc);
  my ($lFile, $rFile);
  my ($lNum, $rNum);
  my ($lInfo, $rInfo);
  my $result;
  
  ($lFunc, $lInfo) = split(/~/, $C{$a});
  ($rFunc, $rInfo) = split(/~/, $C{$b});

  ($lFile, $lNum) = split(/:/, $lInfo);
  ($rFile, $rNum) = split(/:/, $rInfo);

  # Compare the filenames and return the result
  # if they are not the same
  $result = $lFile cmp $rFile;
  if ($result != 0) {
    return $result;
  }
  
  # Filenames are the same, so return the comparison
  # of the line numbers
  return $lNum <=> $rNum;
}

sub dumplabels {

  $start = printstart("Dumping node labels");
  $l=0;
  foreach (keys %fdecl) {
    $l++;
    printGraph($handle, "\"$_\" [label=\"$_\\n$fdecl{$_}\"];\n");
    if ($l % 10 == 0) {
      printline("Dumped $l labels...");
    }
  }
}
sub dumpgraph {

  my $allcalls;
  my $localcalls;
  my ($acall, $func, $loc);
  $start = printstart("Dumping call graph");
  printline("Sorting function calls...");
  @sortedC = sort FuncFileSort keys %C;

  printline("Dumping full call graph...");
  foreach (@sortedC) {
    $allcalls = $cdepncall{$_};
    next if (!/^(.+)~(.+)$/);
    $f1=$1; $f2=$2;

    # Dump a function call if it hasn't been printed already
    if ($printed{"$f1-$f2"} != 1) {
      if ($cpp) {
        if ($f1 =~ /::/) { $f1 = "\"$f1\""; }
        if ($f2 =~ /::/) { $f2 = "\"$f2\""; }
      }

      # Sort out which of these calls are local
      $localcalls = "";
      foreach $acall (split(/ /, $allcalls)) {
        ($caller, $loc) = split(/~/, $acall);
	if ($localcalls ne "") { $localcalls .= " "; }
	if ($caller eq $f1) { $localcalls .= "$loc"; }
      }
      
      # Strip away SMP mangling on symbols. This is very 
      # Linux specific but the names of the functions are
      # so weird, I cannot see it happening anywhere else.
      # If and when a bug report appears on the subject,
      # this will be made a postprocessing option
      $f1 =~ s/_Rsmp_([0-9a-f]{8})$//;
      $f2 =~ s/_Rsmp_([0-9a-f]{8})$//;
      $f1 =~ s/_R([0-9a-f]{8})$//;
      $f2 =~ s/_R([0-9a-f]{8})$//;
     
      printGraph($outgraph, "\"$f1\" -> \"$f2\" [label=\"$localcalls\"];\n");
      $printed{"$f1-$f2"} = 1;
    }

  }
  printcomplete($start, "Full graph dumped to file");

}

1;
