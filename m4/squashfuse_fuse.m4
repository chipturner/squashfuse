# Copyright (c) 2012 Dave Vasilevsky <dave@vasilevsky.ca>
# All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
# 
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR(S) ``AS IS'' AND ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
# OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
# IN NO EVENT SHALL THE AUTHOR(S) BE LIABLE FOR ANY DIRECT, INDIRECT,
# INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
# NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
# THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

# SQ_CHECK_FUSE(LIBS, [IF-FOUND], [IF-NOT-FOUND])
#
# Check if FUSE low-level compiles and links correctly.
AC_DEFUN([SQ_CHECK_FUSE],[
	sq_fuse_ok=yes
	AS_VAR_PUSHDEF([sq_cv_lib],[sq_cv_lib_fuse_""$1""_""$LIBS])
	AC_CACHE_CHECK([for FUSE library],[sq_cv_lib],[
		for sq_lib in '' $1
		do
			SQ_SAVE_FLAGS
			AS_IF([test "x$sq_lib" = x],,[LIBS="$LIBS -l$sq_lib"])
			AC_LINK_IFELSE([AC_LANG_CALL(,[fuse_lowlevel_new])],[
				AS_VAR_SET([sq_cv_lib],[-l$sq_lib])
			])
			SQ_RESTORE_FLAGS
			AS_VAR_SET_IF([sq_cv_lib],[break])
		done
		AS_VAR_SET_IF([sq_cv_lib],,[AS_VAR_SET([sq_cv_lib],[no])])
	])
	AS_VAR_IF([sq_cv_lib],[no],[sq_fuse_ok=no])
	
	AS_IF([test "x$sq_fuse_ok" = "xno"],,[
		AS_VAR_PUSHDEF([sq_cv_hdr],[sq_cv_header_fuse_""$CPPFLAGS])
		AC_CACHE_CHECK([for FUSE header],[sq_cv_hdr],[
			AC_COMPILE_IFELSE([AC_LANG_PROGRAM([#include <fuse_lowlevel.h>])],
				[AS_VAR_SET([sq_cv_hdr],[yes])],
				[AS_VAR_SET([sq_cv_hdr],[no])]
			)
		])
		AS_VAR_IF([sq_cv_hdr],[yes],,[sq_fuse_ok=no])
		AS_VAR_POPDEF([sq_cv_hdr])
	])
	
	AS_IF([test "x$sq_fuse_ok" = "xno"],[$3],[
		AS_VAR_COPY([sq_lib_res],[sq_cv_lib])
		LIBS="$LIBS $sq_lib_res"
		$2
	])
	AS_VAR_POPDEF([sq_cv_lib])
])

# SQ_CHECK_FUSE(INCDIR, LIBDIR, CPPFLAGS, LIBS, [IF-FOUND], [IF-NOT-FOUND])
#
# Check for FUSE in the given directories.
AC_DEFUN([SQ_CHECK_FUSE_DIRS],[
	AS_IF([test "x$sq_fuse_found" = xyes],,[
		SQ_SAVE_FLAGS
		AS_IF([test "x$1" = x],,[CPPFLAGS="$CPPFLAGS -I$1"])
		AS_IF([test "x$2" = x],,[LIBS="$LIBS -L$2"])
		CPPFLAGS="$CPPFLAGS $3"
		SQ_CHECK_FUSE($4,[sq_fuse_found=yes],[sq_fuse_found=])
		SQ_KEEP_FLAGS([FUSE],[$sq_fuse_found])
		AS_IF([test "x$sq_fuse_found" = xyes],$5,$6)
	])
])

# SQ_FIND_FUSE([IF-FOUND],[IF-NOT-FOUND])
#
# Find the FUSE library
AC_DEFUN([SQ_FIND_FUSE],[
	m4_define([SQ_FUSE_CPPFLAGS],[-D_FILE_OFFSET_BITS=64])
	m4_define([SQ_FUSE_LIBS],[fuse])
	AS_CASE([$target_os],[darwin*],[
		m4_append([SQ_FUSE_CPPFLAGS],
			[ -D__FreeBSD__=10 -D_DARWIN_USE_64_BIT_INODE])
		m4_define([SQ_FUSE_LIBS],[fuse_ino64 ]SQ_FUSE_LIBS)
	])
	sq_fuse_found=
	
	# Specified in arguments
	AC_ARG_WITH(fuse,
		AS_HELP_STRING([--with-fuse=DIR], [FUSE prefix directory]),[
		fuse_inc="$withval/include/fuse"
		fuse_lib="$withval/lib"
	])
	AC_ARG_WITH(fuse-include,
		AS_HELP_STRING([--with-fuse-include=DIR], [FUSE header directory]),
		[fuse_inc=$withval])
	AC_ARG_WITH(fuse-lib,
		AS_HELP_STRING([--with-fuse-lib=DIR], [FUSE library directory]),
		[fuse_lib=$withval])
	AS_IF([test "x$fuse_inc$fuse_lib" = x],,[
		SQ_CHECK_FUSE_DIRS([$fuse_inc],[$fuse_lib],SQ_FUSE_CPPFLAGS,
			SQ_FUSE_LIBS,,
			[AC_MSG_FAILURE([Can't find FUSE in specified directories])])
	])
	
	# pkgconfig
	AS_IF([test "x$sq_fuse_found" = xyes],,[
		SQ_SAVE_FLAGS
		SQ_PKG([fuse],[fuse >= 2.5],
			[SQ_CHECK_FUSE(,[sq_fuse_found=yes],
				[AC_MSG_FAILURE([Can't find FUSE with pkgconfig])])],
			[:])
		SQ_KEEP_FLAGS([FUSE],[$sq_fuse_found])
	])
	
	# Default search locations
	SQ_CHECK_FUSE_DIRS(,,SQ_FUSE_CPPFLAGS,SQ_FUSE_LIBS)
	SQ_CHECK_FUSE_DIRS([/usr/include/fuse],[/usr/lib],
		SQ_FUSE_CPPFLAGS,SQ_FUSE_LIBS)
	SQ_CHECK_FUSE_DIRS([/usr/local/include/fuse],[/usr/local/lib],
		SQ_FUSE_CPPFLAGS,SQ_FUSE_LIBS)
	SQ_CHECK_FUSE_DIRS([/usr/local/include/osxfuse/fuse],[/usr/local/lib],
		SQ_FUSE_CPPFLAGS,[osxfuse ]SQ_FUSE_LIBS)
	
	AS_IF([test "x$sq_fuse_found" = xyes],,
		[AC_MSG_FAILURE([Can't find FUSE])])
])

# SQ_FUSE_API_VERSION
#
# Check various things that are different in different versions of FUSE
AC_DEFUN([SQ_FUSE_API_VERSION],[
	SQ_SAVE_FLAGS
	LIBS="$LIBS $FUSE_LIBS"
	CPPFLAGS="$CPPFLAGS $FUSE_CPPFLAGS"
	
	AC_CHECK_DECLS([fuse_add_direntry,fuse_add_dirent],[found_dirent=yes],,
		[#include <fuse_lowlevel.h>])
	AS_IF([test "x$found_dirent" = xyes],,
		[AC_MSG_FAILURE([No way to add directory entries])])

	AC_CHECK_DECLS([fuse_daemonize],,
		[SQ_CHECK_NONSTD(daemon,[#include <unistd.h>],[(void)daemon;])],
		[#include <fuse_lowlevel.h>])

	AC_CHECK_DECLS([fuse_session_remove_chan],,,[#include <fuse_lowlevel.h>])

	AC_MSG_CHECKING([for two-argument fuse_unmount])
	AC_LINK_IFELSE([
		AC_LANG_PROGRAM([#include <fuse_lowlevel.h>],[fuse_unmount(0,0)])
	],[
		AC_MSG_RESULT(yes)
		AC_DEFINE([HAVE_NEW_FUSE_UNMOUNT],1,
			[Define if we have two-argument fuse_unmount])
	],[AC_MSG_RESULT(no)])
	
	SQ_RESTORE_FLAGS
])

# SQ_FUSE_API_XATTR_POSITION
#
# Check for OS X's special flag to getxattr.
AC_DEFUN([SQ_FUSE_API_XATTR_POSITION],[
	SQ_SAVE_FLAGS
	LIBS="$LIBS $FUSE_LIBS"
	CPPFLAGS="$CPPFLAGS $FUSE_CPPFLAGS"
	
	AC_MSG_CHECKING([for position argument to FUSE xattr operations])
	AC_LINK_IFELSE([AC_LANG_PROGRAM([#include <fuse_lowlevel.h>],[
			struct fuse_lowlevel_ops ops;
			ops.getxattr(0, 0, 0, 0, 0);
		])],[
		AC_MSG_RESULT(yes)
		AC_DEFINE([FUSE_XATTR_POSITION],1,
			[Define if FUSE xattr operations take a position argument])
	],[AC_MSG_RESULT(no)])
	
	SQ_RESTORE_FLAGS
])
