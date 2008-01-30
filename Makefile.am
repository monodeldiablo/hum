NULL = 

AUTOMAKE_OPTIONS = subdir-objects

SUBDIRS = \
	po \
	$(NULL)

AM_CPPFLAGS = \
	$(HUMDEV_CFLAGS) \
	-include $(CONFIG_HEADER) \
	$(NULL)

BUILT_SOURCES = src/humdev.vala.stamp

bin_PROGRAMS = humdev

humdev_VALASOURCES = \
	src/mainwindow.vala \
	$(NULL)

humdev_SOURCES = \
	$(humdev_VALASOURCES:.vala=.c) \
	$(humdev_VALASOURCES:.vala=.h) \
	$(NULL)

src/humdev.vala.stamp: $(humdev_VALASOURCES)
	$(VALAC) --pkg gtk+-2.0 --basedir $(top_srcdir) $^
	touch $@

humdev_LDADD = \
	$(HUMDEV_LIBS) \
	$(NULL)

EXTRA_DIST = \
	intltool-extract.in \
	intltool-update.in \
	intltool-merge.in \
	$(humdev_VALASOURCES) \
	src/humdev.vala.stamp \
	$(NULL)

DISTCLEANFILES = \
	intltool-extract \
	intltool-update \
	intltool-merge \
	po/.intltool-merge-cache \
	$(NULL)

