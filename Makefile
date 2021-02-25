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

# Default goes into /usr/local
# For an install into /usr: make PREFIX=/usr install

PREFIX ?= /usr/local

# Brace expansion requires bash
SHELL := $(shell which bash)

install:
	mkdir -p $(PREFIX)/{bin,sbin,share/hesutils}
	cp src/* $(PREFIX)/share/hesutils
	chmod 755 $(PREFIX)/share/hesutils/{hes,hesadd,hesgen}
	ln -s $(PREFIX)/share/hesutils/hes $(PREFIX)/bin/hes
	ln -s $(PREFIX)/share/hesutils/hesgen $(PREFIX)/bin/hesgen
	ln -s $(PREFIX)/share/hesutils/hesadd $(PREFIX)/sbin/hesadd
	ln -s $(PREFIX)/share/hesutils/hesadd $(PREFIX)/sbin/hesuseradd
	ln -s $(PREFIX)/share/hesutils/hesadd $(PREFIX)/sbin/hesgroupadd
	-install -b hesutils.conf /etc

uninstall:
	rm -f $(PREFIX)/bin/{hes,hesgen}
	rm -f $(PREFIX)/sbin/{hesadd,hesuseradd,hesgroupadd}
	rm -fr $(PREFIX)/share/hesutils

# Make runs each line in a separate shell, so run_tests.sh need to be called on
# the same line as the export...

check:
	export PATH=$(PWD)/src:$(PATH) ; tests/run_tests.sh tests/*.test

clean:
	rm -fr tests/*.test.*

