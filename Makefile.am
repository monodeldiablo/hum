NULL = 

AUTOMAKE_OPTIONS = subdir-objects

SUBDIRS = \
	po \
	$(NULL)

AM_CPPFLAGS = \
	$(HUM_CFLAGS) \
	-include $(CONFIG_HEADER) \
	$(NULL)

BUILT_SOURCES = src/hum.vala.stamp

bin_PROGRAMS = hum

hum_VALASOURCES = \
	src/hum.vala \
	$(NULL)

hum_SOURCES = \
	$(hum_VALASOURCES:.vala=.c) \
	$(hum_VALASOURCES:.vala=.h) \
	$(NULL)

src/hum.vala.stamp: $(hum_VALASOURCES)
	$(VALAC) --pkg gtk+-2.0 --pkg gstreamer-0.10 --basedir $(top_srcdir) $^
	touch $@

hum_LDADD = \
	$(HUM_LIBS) \
	$(NULL)

EXTRA_DIST = \
	intltool-extract.in \
	intltool-update.in \
	intltool-merge.in \
	$(hum_VALASOURCES) \
	src/hum.vala.stamp \
	$(NULL)

DISTCLEANFILES = \
	intltool-extract \
	intltool-update \
	intltool-merge \
	po/.intltool-merge-cache \
	$(NULL)

