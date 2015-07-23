%define _specver        $Id: codeviz.spec,v 1.1 2003/10/26 19:47:43 mel Exp $
%define _name           codeviz
%define _pkg            %{_name}
%define _ver            0.13
%define _rel            3boz
%define _nv             %{_name}-%{_ver}
%define _namever        %{_nv}
%define _nameverrel     %{_name}-%{_ver}-%{_rel}

%define _filelist       %{_nameverrel}-filelist

# compress man, info and POD pages.
%define _brp_compress   /usr/lib/rpm/brp-compress
%define __brp_compress  [ -x %{_brp_compress} ] && %{_brp_compress}

Summary: A call graph generation utility for C/C++
Name: %{_pkg}
Version: %{_ver}
Release: %{_rel}
Copyright: distributable
Group: Development/Tools
Packager: %{_packager}
Source0: http://www.skynet.ie/~mel/projects/codeviz/%{_nv}.tar.gz
Patch0: patch.new-options
BuildRoot: %{_buildtmp}/%{_nameverrel}-buildroot/
BuildArch: noarch

%description
CodeViz provides the ability to generate call graphs to aid the task
of understanding code. It uses a highly modular set of collection
methods and can be adapted to support any language although only C and
C++ are currently supported.

build-id ---> %_specver

%prep
%setup
%patch0

%build

%install
{ i="$RPM_BUILD_ROOT"; [ "$i" != "/" ] && rm -rf $i; }

gen_filelist()
{
  _d=$1;shift
  _l=$1;shift
  find $_d | perl -nl \
    -e "\$_d='$_d';" \
    -e 'if ( ! -d ) { $_f=1; undef $_p; }' \
    -e 'elsif ( m,$_d.*%{_name}, ) { $_f=1; $_p="%dir "; }' \
    -e 'if ( $_f ) {' \
    -e '  s,/*$_d/*,/,;' \
    -e '  printf "%s\n", "$_p$_";' \
    -e '  undef $_f }' \
    > $_l

  if [ ! -f $_l -o ! -s  $_l ]
  then
      echo "ERROR: EMPTY FILE LIST"
      exit -1
  fi
}

_r=$RPM_BUILD_ROOT
eval "_perl_`perl -V:installsitelib`"
%{__mkdir_p} -m 755 $_r/%{_bindir} \
                    $_r/$_perl_installsitelib ]\
                    $_r/%{_docdir}/%{_nv}
%{__install} -m 755 bin/* $_r/%{_bindir}
%{__cp} -pr lib/* $_r/$_perl_installsitelib
%{__cp} -pr CHANGELOG \
            README \
            compilers \
            graphs \
            $_r/%{_docdir}/%{_nv}

gen_filelist $RPM_BUILD_ROOT %{_filelist}

%clean 
#echo The maid is off on `date +%A`.
for i in "$RPM_BUILD_ROOT" "$RPM_BUILD_DIR/%{_namever}" "%_buildtmp"; do
    [ "$i" != "/" ] && rm -rf $i
done

%files -f %{_filelist}
%defattr(-,root,root)

%changelog
* Fri Oct 17 2003 Robert Lehr <bozzio@the-lehrs.com>
- initial revision for private RPM
