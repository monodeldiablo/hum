AC_INIT([Hum: The Low-Calorie Music Manager], [0.1.0], [brian.william.davis@gmail.com], [hum], [http://launchpad.net/hum])
AC_CONFIG_SRCDIR([Makefile.am])
AC_CONFIG_HEADERS(config.h)
AM_INIT_AUTOMAKE([dist-bzip2])
AM_MAINTAINER_MODE

AC_PROG_CC
AM_PROG_CC_C_O
AC_DISABLE_STATIC
AC_PROG_LIBTOOL

AC_PATH_PROG(VALAC, valac, valac)
AC_SUBST(VALAC)

AH_TEMPLATE([GETTEXT_PACKAGE], [Hum: The Low-Calorie Music Manager])
GETTEXT_PACKAGE=hum
AC_DEFINE_UNQUOTED(GETTEXT_PACKAGE, "$GETTEXT_PACKAGE")
AC_SUBST(GETTEXT_PACKAGE)
AM_GLIB_GNU_GETTEXT
IT_PROG_INTLTOOL([0.35.0])

# Set up prefix-relative directories
if test "x${prefix}" = "xNONE"; then
  PREFIX="${ac_default_prefix}"
else
  PREFIX="${prefix}"
fi
AC_DEFINE_UNQUOTED(PACKAGE_DATADIR, "${PREFIX}/${DATADIRNAME}/${PACKAGE}",[Package data directory])
AC_DEFINE_UNQUOTED(PACKAGE_BINDIR, "${PREFIX}/bin",[Package executable directory])

AC_SUBST(CFLAGS)
AC_SUBST(CPPFLAGS)
AC_SUBST(LDFLAGS)

GLIB_REQUIRED=2.12.0
GTK_REQUIRED=2.10.0
GST_REQUIRED=0.10.15
DBUS_GLIB_REQUIRED=0.80

PKG_CHECK_MODULES(HUM, glib-2.0 >= $GLIB_REQUIRED gobject-2.0 >= $GLIB_REQUIRED gtk+-2.0 >= $GTK_REQUIRED gstreamer-0.10 >= $GST_REQUIRED dbus-glib-1 >= $DBUS_GLIB_REQUIRED)
AC_SUBST(HUM_CFLAGS)
AC_SUBST(HUM_LIBS)

AC_CONFIG_FILES([Makefile
        src/Makefile
	data/Makefile
	po/Makefile.in])

AC_OUTPUT
