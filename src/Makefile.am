NULL = 

AM_CPPFLAGS = \
	$(HUM_CFLAGS) \
	-include $(CONFIG_HEADER) \
	-DPACKAGE_DATADIR='"$(pkgdatadir)"' \
	-DUI_FILE='"$(pkgdatadir)/ui.xml"' \
	$(NULL)

AM_VALAFLAGS = \
	--vapidir ../vapi \
	--pkg config \
	--pkg gstreamer-0.10 \
	--pkg dbus-glib-1 \
	--pkg gtk+-2.0 \
	$(NULL)

bin_PROGRAMS = \
	hum \
	humgui \
	$(NULL)

humgui_SOURCES = \
	hum_gui.vala \
	$(NULL)

humgui_LDADD = \
	$(HUM_LIBS) \
	$(NULL)

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

