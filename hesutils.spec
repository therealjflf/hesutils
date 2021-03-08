# ==============================================================================
#
# hesutils.specs
#
# ------------------------------------------------------------------------------
#
# Spec file for the RPM package
# 
# ==============================================================================
#
# This file is part of Hesutils <https://gitlab.com/jflf/hesutils>
# Hesutils Copyright (c) 2019-2021 JFLF
#
# Hesutils is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Hesutils is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Hesutils. If not, see <https://www.gnu.org/licenses/>.
#
# ==============================================================================

Name:           hesutils
Version:        %(git describe --always | tr -- - _)
Release:        1%{?dist}
Summary:        The Hesiod utilities
License:        GPLv3
URL:            https://gitlab.com/jflf/hesutils
Source0:        %{expand:%%(pwd)}
BuildArch:      noarch

Provides:       hes = %{version}-%{release}
Provides:       hesadd = %{version}-%{release}
Provides:       hesuseradd = %{version}-%{release}
Provides:       hesgroupadd = %{version}-%{release}
Provides:       hesgen = %{version}-%{release}

BuildRequires:  bash >= 4, rst2man
Requires:       bash >= 4, awk, column, coreutils, sed, which
Recommends:     hesinfo


%description
Hesutils, the HESiod UTILitieS, is a set of tools to facilitate the deployment and usage of the Hesiod user and group name service.

Information about Hesiod and the Hesutils documentation are available in the project's repository on Gitlab:
https://gitlab.com/jflf/hesutils


%prep
# clean out old files
find . -mindepth 1 -delete
find %{buildroot} -mindepth 1 -delete || true
cp -af %{SOURCEURL0}/. .


%build
make man


%install
mkdir -p %{buildroot}/%{_bindir}/
mkdir -p %{buildroot}/%{_sbindir}/
mkdir -p %{buildroot}/%{_sysconfdir}/
mkdir -p %{buildroot}/%{_datadir}/hesutils
mkdir -p %{buildroot}/%{_mandir}/man1
mkdir -p %{buildroot}/%{_mandir}/man8

install -m 755 ./src/* %{buildroot}/%{_datadir}/hesutils/
chmod 644 %{buildroot}/%{_datadir}/hesutils/lib_*

ln -s %{_datadir}/hesutils/hes %{buildroot}/%{_bindir}/hes
ln -s %{_datadir}/hesutils/hesgen %{buildroot}/%{_bindir}/hesgen
ln -s %{_datadir}/hesutils/hesadd %{buildroot}/%{_sbindir}/hesadd
ln -s %{_datadir}/hesutils/hesadd %{buildroot}/%{_sbindir}/hesuseradd
ln -s %{_datadir}/hesutils/hesadd %{buildroot}/%{_sbindir}/hesgroupadd

install -m 644 docs/man1/*.1 %{buildroot}/%{_mandir}/man1/
install -m 644 docs/man8/*.8 %{buildroot}/%{_mandir}/man8/

install -m 644 ./hesutils.conf %{buildroot}/%{_sysconfdir}/


%files
%{_datadir}/hesutils
%{_bindir}/hes
%{_bindir}/hesgen
%{_sbindir}/hesadd
%{_sbindir}/hesuseradd
%{_sbindir}/hesgroupadd
%{_mandir}/man1/hes.1*
%{_mandir}/man1/hesgen.1*
%{_mandir}/man8/hesadd.8*
%config(noreplace) %{_sysconfdir}/hesutils.conf
%license LICENSE


%changelog
# nothing there yet

