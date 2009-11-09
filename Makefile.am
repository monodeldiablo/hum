NULL = 

#Build in these directories:

SUBDIRS = \
	src \
	data \
	po \
	$(NULL)

humservicedir = ${datadir}/dbus-1/services
humservice_DATA = \
	org.washedup.Hum.service \
	$(NULL)

org.washedup.Hum.service:
	cp org.washedup.Hum.service.in org.washedup.Hum.service && \
	echo "Exec=${bindir}/hum-player" >> org.washedup.Hum.service

humappdir = ${datadir}/applications
humapp_DATA = \
	hum.desktop \
	$(NULL)

humdocdir = ${docdir}
humdoc_DATA = \
	ChangeLog \
	README \
	COPYING \
	AUTHORS \
	INSTALL \
	NEWS \
	$(NULL)

EXTRA_DIST = \
	org.washedup.Hum.service.in \
	$(humdoc_DATA) \
	intltool-extract.in \
	intltool-merge.in \
	intltool-update.in \
	$(NULL)

DISTCLEANFILES = \
	org.washedup.Hum.service \
	intltool-extract \
	intltool-merge \
	intltool-update \
	po/.intltool-merge-cache \
	$(NULL)
