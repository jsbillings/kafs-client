CFLAGS		= -g -O2 -Wall -Wsign-compare
INSTALL		= install
DESTDIR		=
ETCDIR		= /etc/kafs
BINDIR		= /usr/bin
MANDIR		= /usr/share/man
DATADIR		= /usr/share/kafs-client
SPECFILE	= redhat/kafs-client.spec

LNS		:= ln -sf

###############################################################################
#
# Determine the current package version from the specfile
#
###############################################################################
VERSION		:= $(word 2,$(shell grep "^Version:" $(SPECFILE)))
TARBALL		:= kafs-client-$(VERSION).tar
ZTARBALL	:= $(TARBALL).bz2

###############################################################################
#
# Guess at the appropriate word size
#
###############################################################################
BUILDFOR	:= $(shell file /usr/bin/make | sed -e 's!.*ELF \(32\|64\)-bit.*!\1!')-bit

ifeq ($(BUILDFOR),32-bit)
CFLAGS		+= -m32
else
ifeq ($(BUILDFOR),64-bit)
CFLAGS		+= -m64
endif
endif

###############################################################################
#
# Build stuff
#
###############################################################################
all:
	$(MAKE) -C src all

###############################################################################
#
# Install everything
#
###############################################################################
MAN1	:= $(MANDIR)/man1

install: all
	$(MAKE) -C src install
	$(INSTALL) -D -m 0644 man/aklog-kafs.1 $(DESTDIR)$(MAN1)/aklog-kafs.1
	$(INSTALL) -D -m 0644 man/aklog.1 $(DESTDIR)$(MAN1)/aklog.1
	$(INSTALL) -D -m 0644 conf/cellservdb.conf $(DESTDIR)$(DATADIR)/cellservdb.conf
	$(INSTALL) -D -m 0644 conf/etc.conf $(DESTDIR)$(ETCDIR)/cellservdb.conf
	mkdir -m755 $(DESTDIR)$(ETCDIR)/cellservdb.d
	mkdir -m755 $(DESTDIR)/afs

###############################################################################
#
# Clean up
#
###############################################################################
clean:
	$(MAKE) -C src clean
	$(RM) debugfiles.list debugsources.list

distclean: clean
	$(MAKE) -C src distclean
	$(RM) -r rpmbuild $(TARBALL)

###############################################################################
#
# Generate a tarball
#
###############################################################################
$(ZTARBALL):
	git archive --prefix=kafs-client-$(VERSION)/ --format tar -o $(TARBALL) HEAD
	bzip2 -9 <$(TARBALL) >$(ZTARBALL)

tarball: $(ZTARBALL)

###############################################################################
#
# Generate an RPM
#
###############################################################################
SRCBALL	:= rpmbuild/SOURCES/$(TARBALL)
ZSRCBALL := rpmbuild/SOURCES/$(ZTARBALL)

BUILDID	:= .local
dist	:= $(word 2,$(shell grep -r "^%dist" /etc/rpm /usr/lib/rpm))
release	:= $(word 2,$(shell grep ^Release: $(SPECFILE)))
release	:= $(subst %{?dist},$(dist),$(release))
release	:= $(subst %{?buildid},$(BUILDID),$(release))
rpmver	:= $(VERSION)-$(release)
SRPM	:= rpmbuild/SRPMS/kafs-client-$(rpmver).src.rpm

RPMBUILDDIRS := \
	--define "_srcrpmdir $(CURDIR)/rpmbuild/SRPMS" \
	--define "_rpmdir $(CURDIR)/rpmbuild/RPMS" \
	--define "_sourcedir $(CURDIR)/rpmbuild/SOURCES" \
	--define "_specdir $(CURDIR)/rpmbuild/SPECS" \
	--define "_builddir $(CURDIR)/rpmbuild/BUILD" \
	--define "_buildrootdir $(CURDIR)/rpmbuild/BUILDROOT"

RPMFLAGS := \
	--define "buildid $(BUILDID)"

rpm:
	mkdir -p rpmbuild
	chmod ug-s rpmbuild
	mkdir -p rpmbuild/{SPECS,SOURCES,BUILD,BUILDROOT,RPMS,SRPMS}
	git archive --prefix=kafs-client-$(VERSION)/ --format tar -o $(SRCBALL) HEAD
	bzip2 -9 <$(SRCBALL) >$(ZSRCBALL)
	rpmbuild -ts $(ZSRCBALL) --define "_srcrpmdir rpmbuild/SRPMS" $(RPMFLAGS)
	rpmbuild --rebuild $(SRPM) $(RPMBUILDDIRS) $(RPMFLAGS)

rpmlint: rpm
	rpmlint $(SRPM) $(CURDIR)/rpmbuild/RPMS/*/kafs-client-{,debuginfo-}$(rpmver).*.rpm

###############################################################################
#
# Build debugging
#
###############################################################################
show_vars:
	@echo VERSION=$(VERSION)
	@echo TARBALL=$(TARBALL)
	@echo BUILDFOR=$(BUILDFOR)
