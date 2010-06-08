NULL = 

AM_CPPFLAGS = \
	$(HUM_CFLAGS) \
	-include $(CONFIG_HEADER) \
	$(NULL)

AM_VALAFLAGS = \
	--vapidir $(top_srcdir)/vapi \
	--pkg config \
	--pkg gstreamer-0.10 \
	--pkg dbus-glib-1 \
	--pkg gtk+-2.0 \
	--thread \
	$(NULL)

bin_PROGRAMS = \
	hum-player \
	hum-gtk \
	$(NULL)

hum_gtk_SOURCES = \
	hum_utils.vala \
	hum_track.vala \
	hum_query_engine.vala \
	hum_gui.vala \
	$(NULL)

hum_gtk_LDADD = \
	$(HUM_LIBS) \
	$(NULL)

hum_player_SOURCES = \
	hum_player.vala \
	$(NULL)

hum_player_LDADD = \
	$(HUM_LIBS) \
	$(NULL)

EXTRA_DIST = \
	$(NULL)

CLEANFILES = \
	*.c \
	*.h \
	hum_player_vala.stamp \
	hum_gtk_vala.stamp \
	$(NULL)

DISTCLEANFILES = \
	$(NULL)

