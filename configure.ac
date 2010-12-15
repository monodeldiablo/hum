AC_INIT([Hum: The low calorie music manager],[0.3.0],[brian.william.davis@gmail.com],[hum],[http://github.com/monodeldiablo/hum])

AC_CONFIG_HEADERS([config.h])
AC_CONFIG_SRCDIR([Makefile.am])
AC_CONFIG_MACRO_DIR([m4])

AM_INIT_AUTOMAKE([1.10 dist-bzip2])
AM_MAINTAINER_MODE([enable])

m4_ifdef([AM_SILENT_RULES],[AM_SILENT_RULES([yes])])

# Check for programs
AC_PROG_CC
AM_PROG_CC_C_O
AM_PROG_VALAC([0.9.1])

# Initialize libtool
LT_INIT([disable-static])

# i18n stuff
IT_PROG_INTLTOOL([0.40.0])

AM_GNU_GETTEXT_VERSION([0.17])
AM_GNU_GETTEXT([external])

AC_SUBST([GETTEXT_PACKAGE],[hum])
AC_DEFINE([GETTEXT_PACKAGE],[PACKAGE_TARNAME],[Define to the gettext package name])

AM_GLIB_GNU_GETTEXT

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

AC_CONFIG_FILES([
	Makefile
	src/Makefile
	data/Makefile
	po/Makefile.in
	vapi/Makefile
])

AC_OUTPUT
