#!/bin/bash

INSTALL_PATH=$HOME/gcc-graph
if [ "$1" != "" ]; then INSTALL_PATH=$1; fi
if [ "$2" = "compile-only" ]; then export COMPILE_ONLY=yes; fi
echo Installing gcc to $INSTALL_PATH

NCFTP=`which ncftpget`
EXIT=$?
if [ "$EXIT" != "0" ]; then
  NCFTP=ftp
fi

if [ ! -e gcc-7.4.0.tar.gz ]; then
  echo gcc-7.4.0.tar.gz not found, downloading
  $NCFTP ftp://ftp.gnu.org/pub/gnu/gcc/gcc-7.4.0/gcc-7.4.0.tar.gz
  if [ ! -e gcc-7.4.0.tar.gz ]; then
    echo Failed to download gcc, download gcc-7.4.0.tar.gz from www.gnu.org
    exit
  fi
fi

# Untar gcc
rm -rf gcc-graph/objdir 2> /dev/null
mkdir -p gcc-graph/objdir
echo Untarring gcc...
tar -zxf gcc-7.4.0.tar.gz -C gcc-graph || exit

# Apply patch
cd gcc-graph/gcc-7.4.0
patch -p1 < ../../gcc-patches/gcc-7.4.0-cdepn.diff
cd ../objdir

# Configure and compile
../gcc-7.4.0/configure --prefix=$INSTALL_PATH --enable-shared --enable-languages=c,c++ || exit
make bootstrap

RETVAL=$?
PLATFORM=i686-pc-linux-gnu
if [ $RETVAL != 0 ]; then
  if [ ! -e $PLATFORM/libiberty/config.h ]; then
    echo Checking if this is CygWin
    echo Note: This is untested, if building with Cygwin works, please email mel@csn.ul.ie with
    echo a report
    export PLATFORM=i686-pc-cygwin
    if [ ! -e $PLATFORM/libiberty/config.h ]; then
      echo Do not know how to fix this compile error up, exiting...
      exit -1
    fi
  fi
  cd $PLATFORM/libiberty/
  cat config.h | sed -e 's/.*undef HAVE_LIMITS_H.*/\#define HAVE_LIMITS_H 1/' > config.h.tmp && mv config.h.tmp config.h
  cat config.h | sed -e 's/.*undef HAVE_STDLIB_H.*/\#define HAVE_STDLIB_H 1/' > config.h.tmp && mv config.h.tmp config.h
  cat config.h | sed -e 's/.*undef HAVE_UNISTD_H.*/\#define HAVE_UNISTD_H 1/' > config.h.tmp && mv config.h.tmp config.h
  cat config.h | sed -e 's/.*undef HAVE_SYS_STAT_H.*/\#define HAVE_LIMITS_H 1/' > config.h.tmp && mv config.h.tmp config.h
  if [ "$PLATFORM" = "i686-pc-cygwin" ]; then
    echo "#undef HAVE_GETTIMEOFDAY" >> config.h
  fi

  TEST=`grep HAVE_SYS_STAT_H config.h` 
  if [ "$TEST" = "" ]; then
    echo "#undef HAVE_SYS_STAT_H" >> config.h
    echo "#define HAVE_SYS_STAT_H 1" >> config.h
  fi
  cd ../../
  make

  RETVAL=$?
  if [ $RETVAL != 0 ]; then
    echo
    echo Compile saved after trying to fix up config.h, do not know what to do
    echo This is likely a CodeViz rather than a gcc problem
    exit -1
  fi
fi

if [ "$COMPILE_ONLY" != "yes" ]; then
  make install
fi
