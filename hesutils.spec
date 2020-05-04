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
# Hesutils Copyright (c) 2019-2020 JFLF
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

Name:       hesutils
Version:    %(git describe --always)
Release:    1%{?dist}
Summary:    The Hesiod utilities
License:    GPLv3
URL:        https://gitlab.com/jflf/hesutils
Source0:    %{expand:%%(pwd)}
BuildArch:  noarch

Provides:   hesadd = %{version}-%{release}
Provides:   hesuseradd = %{version}-%{release}
Provides:   hesgroupadd = %{version}-%{release}
Provides:   hesgen = %{version}-%{release}

Requires:   bash >= 4, gawk

%description
Hesutils, the HESiod UTILitieS, is a set of tools to facilitate the deployment and usage of the Hesiod user and group name service.

Information about Hesiod and the Hesutils documentation are available in the project's wiki on GitLab:
https://gitlab.com/jflf/hesutils/-/wikis/home

%prep
# clean out old files
find . -mindepth 1 -delete

%build
# nothing there

%install
mkdir -p %{buildroot}/%{_sbindir}/
mkdir -p %{buildroot}/%{_sysconfdir}/
mkdir -p %{buildroot}/%{_datadir}/hesutils/

install -m 755 %{SOURCEURL0}/src/* %{buildroot}/%{_datadir}/hesutils/

ln -s %{_datadir}/hesutils/hesadd %{buildroot}/%{_sbindir}/hesadd
ln -s %{_datadir}/hesutils/hesadd %{buildroot}/%{_sbindir}/hesuseradd
ln -s %{_datadir}/hesutils/hesadd %{buildroot}/%{_sbindir}/hesgroupadd
ln -s %{_datadir}/hesutils/hesgen %{buildroot}/%{_sbindir}/hesgen

install -m 644 %{SOURCEURL0}/hesutils.conf %{buildroot}/%{_sysconfdir}/
install -m 644 %{SOURCEURL0}/LICENSE %{buildroot}/%{_datadir}/hesutils/

%files
%{_datadir}/hesutils/
%{_sbindir}/hesadd
%{_sbindir}/hesuseradd
%{_sbindir}/hesgroupadd
%{_sbindir}/hesgen
%config(noreplace) %{_sysconfdir}/hesutils.conf
%license %{_datadir}/hesutils/LICENSE

%changelog
# nothing there

