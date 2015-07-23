 Makefile                                   |    2 
 README                                     |    8 -
 compilers/gcc-patches/gcc-3.4.1-cdepn.diff |  185 -----------------------------
 compilers/gcc-patches/gcc-3.4.6-cdepn.diff |  184 ++++++++++++++++++++++++++++
 compilers/install_gcc-3.4.1.sh             |   79 ------------
 compilers/install_gcc-3.4.6.sh             |   79 ++++++++++++
 configure                                  |    6 
 7 files changed, 271 insertions(+), 272 deletions(-)
diff -urN codeviz-1.0.9-3.4.1/Makefile codeviz-1.0.9-3.4.6/Makefile
--- codeviz-1.0.9-3.4.1/Makefile	2005-09-20 12:24:02.000000000 +0300
+++ codeviz-1.0.9-3.4.6/Makefile	2006-06-22 22:20:32.000000000 +0300
@@ -1,6 +1,6 @@
 TOPLEVEL = /home/mel/Projects/codeviz-1.0.8
 PREFIX = /usr/local
-GCCVERSION = 3.4.1
+GCCVERSION = 3.4.6
 PERLLIB = /usr/local/lib/perl/5.8.4
 GCCGRAPH = /usr/local/gccgraph
 
diff -urN codeviz-1.0.9-3.4.1/README codeviz-1.0.9-3.4.6/README
--- codeviz-1.0.9-3.4.1/README	2004-08-11 01:02:29.000000000 +0300
+++ codeviz-1.0.9-3.4.6/README	2006-06-22 22:20:43.000000000 +0300
@@ -65,20 +65,20 @@
 The patched version of gcc and g++ outputs .cdepn files for every c and c++
 file compiled. This .cdepn file contains information such as when functions
 are called, where they are declared and so on. Earlier versions of CodeViz
-supported multiple gcc versions but this one only support 3.4.1.
+supported multiple gcc versions but this one only support 3.4.6.
 
 First, the source tar has to be downloaded.  For those who have better things
 to do than read the gcc install doc, just do the following
 
 cd compilers
-ncftpget ftp://ftp.gnu.org/pub/gnu/gcc/gcc-3.4.1/gcc-3.4.1.tar.gz
-./install_gcc-3.4.1.sh <optional install path>
+ncftpget ftp://ftp.gnu.org/pub/gnu/gcc/gcc-3.4.6/gcc-3.4.6.tar.gz
+./install_gcc-3.4.6.sh <optional install path>
 
 This script will untar gcc, patch it and install it to the supplied path. If
 no path is given, it'll be installed to $HOME/gcc-graph . I usually install
 it to /usr/local/gcc-graph with
 
-./install_gcc-3.4.1.sh /usr/local/gcc-graph
+./install_gcc-3.4.6.sh /usr/local/gcc-graph
 
 If you seriously want to patch by hand, just read the script as it goes through
 each of the steps one at a time. There is one step to note though.
diff -urN codeviz-1.0.9-3.4.1/compilers/gcc-patches/gcc-3.4.1-cdepn.diff codeviz-1.0.9-3.4.6/compilers/gcc-patches/gcc-3.4.1-cdepn.diff
--- codeviz-1.0.9-3.4.1/compilers/gcc-patches/gcc-3.4.1-cdepn.diff	2004-08-19 23:09:00.000000000 +0300
+++ codeviz-1.0.9-3.4.6/compilers/gcc-patches/gcc-3.4.1-cdepn.diff	1970-01-01 02:00:00.000000000 +0200
@@ -1,185 +0,0 @@
-diff -ru gcc-3.4.1-clean/gcc/cgraph.c gcc-3.4.1-cdepn/gcc/cgraph.c
---- gcc-3.4.1-clean/gcc/cgraph.c	2004-06-01 00:43:51.000000000 +0100
-+++ gcc-3.4.1-cdepn/gcc/cgraph.c	2004-08-19 19:28:42.000000000 +0100
-@@ -68,7 +68,8 @@
- static GTY(())  struct cgraph_varpool_node *cgraph_varpool_nodes;
- 
- static struct cgraph_edge *create_edge (struct cgraph_node *,
--					struct cgraph_node *);
-+					struct cgraph_node *,
-+					location_t call_location);
- static hashval_t hash_node (const void *);
- static int eq_node (const void *, const void *);
- 
-@@ -152,7 +153,7 @@
- /* Create edge from CALLER to CALLEE in the cgraph.  */
- 
- static struct cgraph_edge *
--create_edge (struct cgraph_node *caller, struct cgraph_node *callee)
-+create_edge (struct cgraph_node *caller, struct cgraph_node *callee, location_t call_location)
- {
-   struct cgraph_edge *edge = ggc_alloc (sizeof (struct cgraph_edge));
-   struct cgraph_edge *edge2;
-@@ -180,6 +181,7 @@
- 
-   edge->caller = caller;
-   edge->callee = callee;
-+  edge->call_location = call_location;
-   edge->next_caller = callee->callers;
-   edge->next_callee = caller->callees;
-   caller->callees = edge;
-@@ -295,7 +297,7 @@
- struct cgraph_edge *
- cgraph_record_call (tree caller, tree callee)
- {
--  return create_edge (cgraph_node (caller), cgraph_node (callee));
-+  return create_edge (cgraph_node (caller), cgraph_node (callee), input_location);
- }
- 
- void
-Only in gcc-3.4.1-cdepn/gcc: cgraph.c.cdepn
-diff -ru gcc-3.4.1-clean/gcc/cgraph.h gcc-3.4.1-cdepn/gcc/cgraph.h
---- gcc-3.4.1-clean/gcc/cgraph.h	2004-01-23 23:35:54.000000000 +0000
-+++ gcc-3.4.1-cdepn/gcc/cgraph.h	2004-08-19 19:28:42.000000000 +0100
-@@ -126,6 +126,9 @@
-   /* When NULL, inline this call.  When non-NULL, points to the explanation
-      why function was not inlined.  */
-   const char *inline_failed;
-+
-+  /* CodeViz: Location the call occurred at */
-+  location_t call_location;
- };
- 
- /* The cgraph_varpool data structure.
-diff -ru gcc-3.4.1-clean/gcc/cgraphunit.c gcc-3.4.1-cdepn/gcc/cgraphunit.c
---- gcc-3.4.1-clean/gcc/cgraphunit.c	2004-05-06 00:24:28.000000000 +0100
-+++ gcc-3.4.1-cdepn/gcc/cgraphunit.c	2004-08-19 19:28:43.000000000 +0100
-@@ -320,7 +320,10 @@
- cgraph_analyze_function (struct cgraph_node *node)
- {
-   tree decl = node->decl;
-+  tree thisTree, calleeTree;
-+  FILE *fnref_f;
-   struct cgraph_edge *e;
-+  struct cgraph_edge *calleeEdge;
- 
-   current_function_decl = decl;
- 
-@@ -358,6 +361,33 @@
-   node->analyzed = true;
-   current_function_decl = NULL;
- 
-+  /* CodeViz: Output information on this node */
-+  thisTree = node->decl;
-+  if ((fnref_f = cdepn_open(NULL)))
-+    {
-+      fprintf(fnref_f,"F {%s} {%s:%d}\n",
-+	  lang_hooks.decl_printable_name (thisTree, 2),
-+	  DECL_SOURCE_FILE (thisTree), DECL_SOURCE_LINE (thisTree));
-+
-+    }
-+
-+  /* CodeViz: Output information on all functions this node calls */
-+  for (calleeEdge = node->callees; calleeEdge; calleeEdge = calleeEdge->next_callee)
-+    {
-+      calleeTree = calleeEdge->callee->decl;
-+      if (thisTree != NULL && 
-+	  calleeTree != NULL &&
-+	  (fnref_f = cdepn_open(NULL)) != NULL)
-+	{
-+	  fprintf(fnref_f, "C {%s} {%s:%d} {%s}\n",
-+	      lang_hooks.decl_printable_name (thisTree, 2),
-+	      calleeEdge->call_location.file, calleeEdge->call_location.line,
-+	      lang_hooks.decl_printable_name (calleeTree, 2));
-+	}
-+      else
-+	printf("CODEVIZ: Unexpected NULL encountered\n");
-+    }
-+  
-   /* Possibly warn about unused parameters.  */
-   if (warn_unused_parameter)
-     do_warn_unused_parameter (decl);
-diff -ru gcc-3.4.1-clean/gcc/toplev.c gcc-3.4.1-cdepn/gcc/toplev.c
---- gcc-3.4.1-clean/gcc/toplev.c	2004-02-20 08:40:49.000000000 +0000
-+++ gcc-3.4.1-cdepn/gcc/toplev.c	2004-08-19 20:59:21.000000000 +0100
-@@ -4665,6 +4665,52 @@
-   timevar_print (stderr);
- }
- 
-+/*
-+ * codeviz: Open the cdepn file. This is called with a filename by main()
-+ * and with just NULL for every other instance to return just the handle
-+ */
-+FILE *g_fnref_f = NULL;
-+char cdepnfile[256] = "--wonthappen--";
-+
-+FILE *cdepn_open(char *filename) {
-+  struct stat cdepnstat;
-+  int errval;
-+  time_t currtime;
-+  if (filename && g_fnref_f == NULL) {
-+    strcpy(cdepnfile, filename);
-+    strcat(cdepnfile, ".cdepn");
-+
-+    /*
-+     * Decide whether to open write or append. There appears to be a weird
-+     * bug that decides to open the file twice, overwriting all the cdepn
-+     * information put there before
-+     */
-+    errval = stat(cdepnfile, &cdepnstat); 
-+    currtime = time(NULL);
-+    if (errval == -1 || currtime - cdepnstat.st_mtime > 5)  {
-+      g_fnref_f = fopen(cdepnfile, "w");
-+      fprintf(stderr, "opened dep file %s\n",cdepnfile);
-+    } else {
-+      g_fnref_f = fopen(cdepnfile, "a");
-+      fprintf(stderr, "append dep file %s\n",cdepnfile);
-+    }
-+
-+    fflush(stderr);
-+  }
-+
-+  return g_fnref_f;
-+}
-+
-+void cdepn_close(void) {
-+  if (g_fnref_f) fclose(g_fnref_f);
-+  g_fnref_f = NULL;
-+}
-+
-+int cdepn_checkprint(void *fncheck) {
-+  return 1;
-+  /*return (void *)fncheck == (void *)decl_name; */
-+}
-+
- /* Entry point of cc1, cc1plus, jc1, f771, etc.
-    Exit code is FATAL_EXIT_CODE if can't open files or if there were
-    any errors, or SUCCESS_EXIT_CODE if compilation succeeded.
-@@ -4686,8 +4732,11 @@
-   randomize ();
- 
-   /* Exit early if we can (e.g. -help).  */
--  if (!exit_after_options)
-+  if (!exit_after_options) {
-+    cdepn_open(main_input_filename);
-     do_compile ();
-+    cdepn_close();
-+  }
- 
-   if (errorcount || sorrycount)
-     return (FATAL_EXIT_CODE);
-diff -ru gcc-3.4.1-clean/gcc/tree.h gcc-3.4.1-cdepn/gcc/tree.h
---- gcc-3.4.1-clean/gcc/tree.h	2004-02-08 01:52:43.000000000 +0000
-+++ gcc-3.4.1-cdepn/gcc/tree.h	2004-08-19 19:28:43.000000000 +0100
-@@ -3112,4 +3112,11 @@
- extern int tree_node_counts[];
- extern int tree_node_sizes[];
-     
-+/*
-+ * CodeViz functions to get the output file handle for cdepn files
-+ */
-+FILE *cdepn_open(char *filename);
-+void cdepn_close(void);
-+int  cdepn_checkprint(void *fncheck);
-+
- #endif  /* GCC_TREE_H  */
diff -urN codeviz-1.0.9-3.4.1/compilers/gcc-patches/gcc-3.4.6-cdepn.diff codeviz-1.0.9-3.4.6/compilers/gcc-patches/gcc-3.4.6-cdepn.diff
--- codeviz-1.0.9-3.4.1/compilers/gcc-patches/gcc-3.4.6-cdepn.diff	1970-01-01 02:00:00.000000000 +0200
+++ codeviz-1.0.9-3.4.6/compilers/gcc-patches/gcc-3.4.6-cdepn.diff	2006-06-22 22:22:40.000000000 +0300
@@ -0,0 +1,184 @@
+diff -ur gcc-3.4.6-clean/gcc/cgraph.c gcc-3.4.6-cdepn/gcc/cgraph.c
+--- gcc-3.4.6-clean/gcc/cgraph.c	2004-06-01 02:43:51.000000000 +0300
++++ gcc-3.4.6-cdepn/gcc/cgraph.c	2006-06-21 20:34:04.000000000 +0300
+@@ -68,7 +68,8 @@
+ static GTY(())  struct cgraph_varpool_node *cgraph_varpool_nodes;
+ 
+ static struct cgraph_edge *create_edge (struct cgraph_node *,
+-					struct cgraph_node *);
++					struct cgraph_node *,
++					location_t call_location);
+ static hashval_t hash_node (const void *);
+ static int eq_node (const void *, const void *);
+ 
+@@ -152,7 +153,7 @@
+ /* Create edge from CALLER to CALLEE in the cgraph.  */
+ 
+ static struct cgraph_edge *
+-create_edge (struct cgraph_node *caller, struct cgraph_node *callee)
++create_edge (struct cgraph_node *caller, struct cgraph_node *callee, location_t call_location)
+ {
+   struct cgraph_edge *edge = ggc_alloc (sizeof (struct cgraph_edge));
+   struct cgraph_edge *edge2;
+@@ -180,6 +181,7 @@
+ 
+   edge->caller = caller;
+   edge->callee = callee;
++  edge->call_location = call_location;
+   edge->next_caller = callee->callers;
+   edge->next_callee = caller->callees;
+   caller->callees = edge;
+@@ -295,7 +297,7 @@
+ struct cgraph_edge *
+ cgraph_record_call (tree caller, tree callee)
+ {
+-  return create_edge (cgraph_node (caller), cgraph_node (callee));
++  return create_edge (cgraph_node (caller), cgraph_node (callee), input_location);
+ }
+ 
+ void
+diff -ur gcc-3.4.6-clean/gcc/cgraph.h gcc-3.4.6-cdepn/gcc/cgraph.h
+--- gcc-3.4.6-clean/gcc/cgraph.h	2004-01-24 01:36:03.000000000 +0200
++++ gcc-3.4.6-cdepn/gcc/cgraph.h	2006-06-21 20:34:04.000000000 +0300
+@@ -126,6 +126,9 @@
+   /* When NULL, inline this call.  When non-NULL, points to the explanation
+      why function was not inlined.  */
+   const char *inline_failed;
++
++  /* CodeViz: Location the call occurred at */
++  location_t call_location;
+ };
+ 
+ /* The cgraph_varpool data structure.
+diff -ur gcc-3.4.6-clean/gcc/cgraphunit.c gcc-3.4.6-cdepn/gcc/cgraphunit.c
+--- gcc-3.4.6-clean/gcc/cgraphunit.c	2004-05-06 02:24:30.000000000 +0300
++++ gcc-3.4.6-cdepn/gcc/cgraphunit.c	2006-06-21 20:34:04.000000000 +0300
+@@ -320,7 +320,10 @@
+ cgraph_analyze_function (struct cgraph_node *node)
+ {
+   tree decl = node->decl;
++  tree thisTree, calleeTree;
++  FILE *fnref_f;
+   struct cgraph_edge *e;
++  struct cgraph_edge *calleeEdge;
+ 
+   current_function_decl = decl;
+ 
+@@ -358,6 +361,33 @@
+   node->analyzed = true;
+   current_function_decl = NULL;
+ 
++  /* CodeViz: Output information on this node */
++  thisTree = node->decl;
++  if ((fnref_f = cdepn_open(NULL)))
++    {
++      fprintf(fnref_f,"F {%s} {%s:%d}\n",
++	  lang_hooks.decl_printable_name (thisTree, 2),
++	  DECL_SOURCE_FILE (thisTree), DECL_SOURCE_LINE (thisTree));
++
++    }
++
++  /* CodeViz: Output information on all functions this node calls */
++  for (calleeEdge = node->callees; calleeEdge; calleeEdge = calleeEdge->next_callee)
++    {
++      calleeTree = calleeEdge->callee->decl;
++      if (thisTree != NULL && 
++	  calleeTree != NULL &&
++	  (fnref_f = cdepn_open(NULL)) != NULL)
++	{
++	  fprintf(fnref_f, "C {%s} {%s:%d} {%s}\n",
++	      lang_hooks.decl_printable_name (thisTree, 2),
++	      calleeEdge->call_location.file, calleeEdge->call_location.line,
++	      lang_hooks.decl_printable_name (calleeTree, 2));
++	}
++      else
++	printf("CODEVIZ: Unexpected NULL encountered\n");
++    }
++  
+   /* Possibly warn about unused parameters.  */
+   if (warn_unused_parameter)
+     do_warn_unused_parameter (decl);
+diff -ur gcc-3.4.6-clean/gcc/toplev.c gcc-3.4.6-cdepn/gcc/toplev.c
+--- gcc-3.4.6-clean/gcc/toplev.c	2005-11-09 09:51:51.000000000 +0200
++++ gcc-3.4.6-cdepn/gcc/toplev.c	2006-06-21 20:34:04.000000000 +0300
+@@ -4675,6 +4675,52 @@
+   timevar_print (stderr);
+ }
+ 
++/*
++ * codeviz: Open the cdepn file. This is called with a filename by main()
++ * and with just NULL for every other instance to return just the handle
++ */
++FILE *g_fnref_f = NULL;
++char cdepnfile[256] = "--wonthappen--";
++
++FILE *cdepn_open(char *filename) {
++  struct stat cdepnstat;
++  int errval;
++  time_t currtime;
++  if (filename && g_fnref_f == NULL) {
++    strcpy(cdepnfile, filename);
++    strcat(cdepnfile, ".cdepn");
++
++    /*
++     * Decide whether to open write or append. There appears to be a weird
++     * bug that decides to open the file twice, overwriting all the cdepn
++     * information put there before
++     */
++    errval = stat(cdepnfile, &cdepnstat); 
++    currtime = time(NULL);
++    if (errval == -1 || currtime - cdepnstat.st_mtime > 5)  {
++      g_fnref_f = fopen(cdepnfile, "w");
++      fprintf(stderr, "opened dep file %s\n",cdepnfile);
++    } else {
++      g_fnref_f = fopen(cdepnfile, "a");
++      fprintf(stderr, "append dep file %s\n",cdepnfile);
++    }
++
++    fflush(stderr);
++  }
++
++  return g_fnref_f;
++}
++
++void cdepn_close(void) {
++  if (g_fnref_f) fclose(g_fnref_f);
++  g_fnref_f = NULL;
++}
++
++int cdepn_checkprint(void *fncheck) {
++  return 1;
++  /*return (void *)fncheck == (void *)decl_name; */
++}
++
+ /* Entry point of cc1, cc1plus, jc1, f771, etc.
+    Exit code is FATAL_EXIT_CODE if can't open files or if there were
+    any errors, or SUCCESS_EXIT_CODE if compilation succeeded.
+@@ -4696,8 +4742,11 @@
+   randomize ();
+ 
+   /* Exit early if we can (e.g. -help).  */
+-  if (!exit_after_options)
++  if (!exit_after_options) {
++    cdepn_open(main_input_filename);
+     do_compile ();
++    cdepn_close();
++  }
+ 
+   if (errorcount || sorrycount)
+     return (FATAL_EXIT_CODE);
+diff -ur gcc-3.4.6-clean/gcc/tree.h gcc-3.4.6-cdepn/gcc/tree.h
+--- gcc-3.4.6-clean/gcc/tree.h	2005-01-16 18:01:28.000000000 +0200
++++ gcc-3.4.6-cdepn/gcc/tree.h	2006-06-21 20:34:04.000000000 +0300
+@@ -3115,4 +3115,11 @@
+ extern int tree_node_counts[];
+ extern int tree_node_sizes[];
+     
++/*
++ * CodeViz functions to get the output file handle for cdepn files
++ */
++FILE *cdepn_open(char *filename);
++void cdepn_close(void);
++int  cdepn_checkprint(void *fncheck);
++
+ #endif  /* GCC_TREE_H  */
diff -urN codeviz-1.0.9-3.4.1/compilers/install_gcc-3.4.1.sh codeviz-1.0.9-3.4.6/compilers/install_gcc-3.4.1.sh
--- codeviz-1.0.9-3.4.1/compilers/install_gcc-3.4.1.sh	2005-09-20 12:24:37.000000000 +0300
+++ codeviz-1.0.9-3.4.6/compilers/install_gcc-3.4.1.sh	1970-01-01 02:00:00.000000000 +0200
@@ -1,79 +0,0 @@
-#!/bin/bash
-
-INSTALL_PATH=$HOME/gcc-graph
-if [ "$1" != "" ]; then INSTALL_PATH=$1; fi
-if [ "$2" = "compile-only" ]; then export COMPILE_ONLY=yes; fi
-echo Installing gcc to $INSTALL_PATH
-
-NCFTP=`which ncftpget`
-EXIT=$?
-if [ "$EXIT" != "0" ]; then
-  NCFTP=ftp
-fi
-
-if [ ! -e gcc-3.4.1.tar.gz ]; then
-  echo gcc-3.4.1.tar.gz not found, downloading
-  $NCFTP ftp://ftp.gnu.org/pub/gnu/gcc/gcc-3.4.1/gcc-3.4.1.tar.gz
-  if [ ! -e gcc-3.4.1.tar.gz ]; then
-    echo Failed to download gcc, download gcc-3.4.1.tar.gz from www.gnu.org
-    exit
-  fi
-fi
-
-# Untar gcc
-rm -rf gcc-graph/objdir 2> /dev/null
-mkdir -p gcc-graph/objdir
-echo Untarring gcc...
-tar -zxf gcc-3.4.1.tar.gz -C gcc-graph || exit
-
-# Apply patch
-cd gcc-graph/gcc-3.4.1
-patch -p1 < ../../gcc-patches/gcc-3.4.1-cdepn.diff
-cd ../objdir
-
-# Configure and compile
-../gcc-3.4.1/configure --prefix=$INSTALL_PATH --enable-shared --enable-languages=c,c++ || exit
-make bootstrap
-
-RETVAL=$?
-PLATFORM=i686-pc-linux-gnu
-if [ $RETVAL != 0 ]; then
-  if [ ! -e $PLATFORM/libiberty/config.h ]; then
-    echo Checking if this is CygWin
-    echo Note: This is untested, if building with Cygwin works, please email mel@csn.ul.ie with
-    echo a report
-    export PLATFORM=i686-pc-cygwin
-    if [ ! -e $PLATFORM/libiberty/config.h ]; then
-      echo Do not know how to fix this compile error up, exiting...
-      exit -1
-    fi
-  fi
-  cd $PLATFORM/libiberty/
-  cat config.h | sed -e 's/.*undef HAVE_LIMITS_H.*/\#define HAVE_LIMITS_H 1/' > config.h.tmp && mv config.h.tmp config.h
-  cat config.h | sed -e 's/.*undef HAVE_STDLIB_H.*/\#define HAVE_STDLIB_H 1/' > config.h.tmp && mv config.h.tmp config.h
-  cat config.h | sed -e 's/.*undef HAVE_UNISTD_H.*/\#define HAVE_UNISTD_H 1/' > config.h.tmp && mv config.h.tmp config.h
-  cat config.h | sed -e 's/.*undef HAVE_SYS_STAT_H.*/\#define HAVE_LIMITS_H 1/' > config.h.tmp && mv config.h.tmp config.h
-  if [ "$PLATFORM" = "i686-pc-cygwin" ]; then
-    echo "#undef HAVE_GETTIMEOFDAY" >> config.h
-  fi
-
-  TEST=`grep HAVE_SYS_STAT_H config.h` 
-  if [ "$TEST" = "" ]; then
-    echo "#undef HAVE_SYS_STAT_H" >> config.h
-    echo "#define HAVE_SYS_STAT_H 1" >> config.h
-  fi
-  cd ../../
-  make
-
-  RETVAL=$?
-  if [ $RETVAL != 0 ]; then
-    echo
-    echo Compile saved after trying to fix up config.h, do not know what to do
-    echo This is likely a CodeViz rather than a gcc problem
-    exit -1
-  fi
-fi
-
-if [ "$COMPILE_ONLY" != "yes" ]; then
-  make install
-fi
diff -urN codeviz-1.0.9-3.4.1/compilers/install_gcc-3.4.6.sh codeviz-1.0.9-3.4.6/compilers/install_gcc-3.4.6.sh
--- codeviz-1.0.9-3.4.1/compilers/install_gcc-3.4.6.sh	1970-01-01 02:00:00.000000000 +0200
+++ codeviz-1.0.9-3.4.6/compilers/install_gcc-3.4.6.sh	2006-06-22 22:21:01.000000000 +0300
@@ -0,0 +1,79 @@
+#!/bin/bash
+
+INSTALL_PATH=$HOME/gcc-graph
+if [ "$1" != "" ]; then INSTALL_PATH=$1; fi
+if [ "$2" = "compile-only" ]; then export COMPILE_ONLY=yes; fi
+echo Installing gcc to $INSTALL_PATH
+
+NCFTP=`which ncftpget`
+EXIT=$?
+if [ "$EXIT" != "0" ]; then
+  NCFTP=ftp
+fi
+
+if [ ! -e gcc-3.4.6.tar.gz ]; then
+  echo gcc-3.4.6.tar.gz not found, downloading
+  $NCFTP ftp://ftp.gnu.org/pub/gnu/gcc/gcc-3.4.6/gcc-3.4.6.tar.gz
+  if [ ! -e gcc-3.4.6.tar.gz ]; then
+    echo Failed to download gcc, download gcc-3.4.6.tar.gz from www.gnu.org
+    exit
+  fi
+fi
+
+# Untar gcc
+rm -rf gcc-graph/objdir 2> /dev/null
+mkdir -p gcc-graph/objdir
+echo Untarring gcc...
+tar -zxf gcc-3.4.6.tar.gz -C gcc-graph || exit
+
+# Apply patch
+cd gcc-graph/gcc-3.4.6
+patch -p1 < ../../gcc-patches/gcc-3.4.6-cdepn.diff
+cd ../objdir
+
+# Configure and compile
+../gcc-3.4.6/configure --prefix=$INSTALL_PATH --enable-shared --enable-languages=c,c++ || exit
+make bootstrap
+
+RETVAL=$?
+PLATFORM=i686-pc-linux-gnu
+if [ $RETVAL != 0 ]; then
+  if [ ! -e $PLATFORM/libiberty/config.h ]; then
+    echo Checking if this is CygWin
+    echo Note: This is untested, if building with Cygwin works, please email mel@csn.ul.ie with
+    echo a report
+    export PLATFORM=i686-pc-cygwin
+    if [ ! -e $PLATFORM/libiberty/config.h ]; then
+      echo Do not know how to fix this compile error up, exiting...
+      exit -1
+    fi
+  fi
+  cd $PLATFORM/libiberty/
+  cat config.h | sed -e 's/.*undef HAVE_LIMITS_H.*/\#define HAVE_LIMITS_H 1/' > config.h.tmp && mv config.h.tmp config.h
+  cat config.h | sed -e 's/.*undef HAVE_STDLIB_H.*/\#define HAVE_STDLIB_H 1/' > config.h.tmp && mv config.h.tmp config.h
+  cat config.h | sed -e 's/.*undef HAVE_UNISTD_H.*/\#define HAVE_UNISTD_H 1/' > config.h.tmp && mv config.h.tmp config.h
+  cat config.h | sed -e 's/.*undef HAVE_SYS_STAT_H.*/\#define HAVE_LIMITS_H 1/' > config.h.tmp && mv config.h.tmp config.h
+  if [ "$PLATFORM" = "i686-pc-cygwin" ]; then
+    echo "#undef HAVE_GETTIMEOFDAY" >> config.h
+  fi
+
+  TEST=`grep HAVE_SYS_STAT_H config.h` 
+  if [ "$TEST" = "" ]; then
+    echo "#undef HAVE_SYS_STAT_H" >> config.h
+    echo "#define HAVE_SYS_STAT_H 1" >> config.h
+  fi
+  cd ../../
+  make
+
+  RETVAL=$?
+  if [ $RETVAL != 0 ]; then
+    echo
+    echo Compile saved after trying to fix up config.h, do not know what to do
+    echo This is likely a CodeViz rather than a gcc problem
+    exit -1
+  fi
+fi
+
+if [ "$COMPILE_ONLY" != "yes" ]; then
+  make install
+fi
diff -urN codeviz-1.0.9-3.4.1/configure codeviz-1.0.9-3.4.6/configure
--- codeviz-1.0.9-3.4.1/configure	2005-07-11 21:07:41.000000000 +0300
+++ codeviz-1.0.9-3.4.6/configure	2006-06-22 22:21:10.000000000 +0300
@@ -6,7 +6,7 @@
 # the scripts. It is meant to behave similar to ordinary configure scripts
 
 PREFIX=/usr/local
-GCCVERSION=3.4.1
+GCCVERSION=3.4.6
 GCCGRAPH=-unset-
 
 # Print program usage
@@ -17,8 +17,8 @@
   echo "  -h, --help	    display this help and exit"
   echo "  --prefix=PREFIX   install architecture-independent files in PREFIX"
   echo "                    [Default: /usr/local]"
-  echo "  --gcc=VERSION     version of gcc to use: 3.4.1 only available"
-  echo "                    [Default: 3.4.1]"
+  echo "  --gcc=VERSION     version of gcc to use: 3.4.6 only available"
+  echo "                    [Default: 3.4.6]"
   echo "  --gccgraph=PATH   install patched gcc to this path"
   echo "                    [Default: $HOME/gccgraph]"
   echo "  --perllib=PATH    Where to install the perl libraries"
