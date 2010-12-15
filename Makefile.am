ACLOCAL_AMFLAGS = -I m4 ${ACLOCAL_FLAGS}

NULL = 

#Build in these directories:

SUBDIRS = \
	src \
	data \
	po \
	vapi \
	$(NULL)

humservicedir = $(datadir)/dbus-1/services
humservice_in_files = org.washedup.Hum.service.in
humservice_DATA = $(humservice_in_files:.service.in=.service)

$(humservice_DATA): $(humservice_in_files)
	@sed -e "s|\@bindir\@|$(bindir)|" $< > $@

humappdir = $(datadir)/applications
humapp_DATA = \
	hum.desktop \
	$(NULL)

humdocdir = $(docdir)
humdoc_DATA = \
	ChangeLog \
	README \
	COPYING \
	AUTHORS \
	INSTALL \
	NEWS \
	$(NULL)

README:
	cp -f README.markdown README

EXTRA_DIST = \
	$(humservice_in_files) \
	$(humapp_DATA) \
	$(humdoc_DATA) \
	intltool-extract.in \
	intltool-merge.in \
	intltool-update.in \
	$(NULL)

CLEANFILES = \
	$(humservice_DATA) \
	$(NULL)
	
DISTCLEANFILES = \
	README \
	intltool-extract \
	intltool-merge \
	intltool-update \
	po/.intltool-merge-cache \
	$(NULL)
