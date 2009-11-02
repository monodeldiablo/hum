NULL = 

AM_CPPFLAGS = \
	$(HUM_CFLAGS) \
	-include $(CONFIG_HEADER) \
	-DUI_FILE='"$(pkgdatadir)/ui.xml"' \
	$(NULL)

AM_VALAFLAGS = \
	--pkg gstreamer-0.10 \
	--pkg dbus-glib-1 \
	$(NULL)

bin_PROGRAMS = hum

hum_SOURCES = \
	hum.vala \
	$(NULL)

hum_LDADD = \
	$(HUM_LIBS) \
	$(NULL)

EXTRA_DIST = \
	$(NULL)

DISTCLEANFILES = \
	$(NULL)

