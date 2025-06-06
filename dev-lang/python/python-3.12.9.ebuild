# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI="8"
WANT_LIBTOOL="none"

inherit autotools check-reqs flag-o-matic multiprocessing pax-utils
inherit python-utils-r1 toolchain-funcs verify-sig

MY_PV=${PV/_rc/rc}
MY_P="Python-${MY_PV%_p*}"
PYVER=$(ver_cut 1-2)
PATCHSET="python-gentoo-patches-${MY_PV}"

DESCRIPTION="An interpreted, interactive, object-oriented programming language"
HOMEPAGE="
	https://www.python.org/
	https://github.com/python/cpython/
"
SRC_URI="
	https://www.python.org/ftp/python/${PV%%_*}/${MY_P}.tar.xz
	https://dev.gentoo.org/~mgorny/dist/python/${PATCHSET}.tar.xz
	verify-sig? (
		https://www.python.org/ftp/python/${PV%%_*}/${MY_P}.tar.xz.asc
	)
"
S="${WORKDIR}/${MY_P}"

LICENSE="PSF-2"
SLOT="${PYVER}"
KEYWORDS="~alpha amd64 arm arm64 hppa ~loong ~m68k ~mips ppc ppc64 ~riscv ~s390 sparc x86"
IUSE="
	bluetooth build debug +ensurepip examples gdbm libedit
	+ncurses pgo +readline +sqlite +ssl static static-libs test tk valgrind
"
RESTRICT="!test? ( test )"

# Do not add a dependency on dev-lang/python to this ebuild.
# If you need to apply a patch which requires python for bootstrapping, please
# run the bootstrap code on your dev box and include the results in the
# patchset. See bug 447752.

RDEPEND="
	!static? ( app-arch/bzip2:= )
	!static? ( app-arch/xz-utils:= )
	!static? ( app-crypt/libb2 )
	!static? ( >=dev-libs/expat-2.1:= )
	!static? ( dev-libs/libffi:= )
	!static? ( dev-libs/mpdecimal:= )
	dev-python/gentoo-common
	!static? ( >=sys-libs/zlib-1.1.3:= )
	!static? ( virtual/libcrypt:= )
	virtual/libintl
	ensurepip? ( dev-python/ensurepip-pip )
	!static? ( gdbm? ( sys-libs/gdbm:=[berkdb] ) )
	!static? ( kernel_linux? ( sys-apps/util-linux:= ) )
	!static? ( ncurses? ( >=sys-libs/ncurses-5.2:= ) )
	!static? ( readline? (
		!libedit? ( >=sys-libs/readline-4.1:= )
		libedit? ( dev-libs/libedit:= )
	) )
	!static? ( sqlite? ( >=dev-db/sqlite-3.3.8:3= ) )
	!static? ( ssl? ( >=dev-libs/openssl-1.1.1:= ) )
	tk? (
		>=dev-lang/tcl-8.0:=
		>=dev-lang/tk-8.0:=
		dev-tcltk/blt:=
		dev-tcltk/tix
	)
"
# bluetooth requires headers from bluez
DEPEND="
	${RDEPEND}
	static? ( app-arch/bzip2:=[static-libs] )
	static? ( app-arch/xz-utils:=[static-libs] )
	static? ( app-crypt/libb2[static-libs] )
	static? ( >=dev-libs/expat-2.1:=[static-libs] )
	static? ( dev-libs/libffi:=[static-libs] )
	static? ( dev-libs/mpdecimal:=[static-libs] )
	static? ( >=sys-libs/zlib-1.1.3:=[static-libs] )
	static? ( virtual/libcrypt:=[static-libs] )
	static? ( gdbm? ( sys-libs/gdbm:=[berkdb,static-libs] ) )
	static? ( kernel_linux? ( sys-apps/util-linux:=[static-libs] ) )
	static? ( ncurses? ( >=sys-libs/ncurses-5.2:=[static-libs] ) )
	static? ( readline? (
		!libedit? ( >=sys-libs/readline-4.1:=[static-libs] )
		libedit? ( dev-libs/libedit:=[static-libs] )
	) )
	static? ( sqlite? ( >=dev-db/sqlite-3.3.8:3=[static-libs] ) )
	static? ( ssl? ( >=dev-libs/openssl-1.1.1:=[static-libs] ) )
	bluetooth? ( net-wireless/bluez )
	test? (
		app-arch/xz-utils
		dev-python/ensurepip-pip
		dev-python/ensurepip-setuptools
		dev-python/ensurepip-wheel
	)
	valgrind? ( dev-debug/valgrind )
"
# autoconf-archive needed to eautoreconf
BDEPEND="
	dev-build/autoconf-archive
	app-alternatives/awk
	virtual/pkgconfig
	verify-sig? ( >=sec-keys/openpgp-keys-python-20221025 )
"
RDEPEND+="
	!build? ( app-misc/mime-types )
"
if [[ ${PV} != *_alpha* ]]; then
	RDEPEND+="
		dev-lang/python-exec[python_targets_python${PYVER/./_}(-)]
	"
fi

VERIFY_SIG_OPENPGP_KEY_PATH=/usr/share/openpgp-keys/python.org.asc

# large file tests involve a 2.5G file being copied (duplicated)
CHECKREQS_DISK_BUILD=5500M

QA_PKGCONFIG_VERSION=${PYVER}
# false positives -- functions specific to *BSD
QA_CONFIG_IMPL_DECL_SKIP=( chflags lchflags )

pkg_pretend() {
	use test && check-reqs_pkg_pretend
}

pkg_setup() {
	use test && check-reqs_pkg_setup
}

src_unpack() {
	if use verify-sig; then
		verify-sig_verify_detached "${DISTDIR}"/${MY_P}.tar.xz{,.asc}
	fi
	default
}

src_prepare() {
	# Ensure that internal copies of expat and libffi are not used.
	# TODO: Makefile has annoying deps on expat headers
	#rm -r Modules/expat || die

	local PATCHES=(
		"${WORKDIR}/${PATCHSET}"
	)

	default

	# force the correct number of jobs
	# https://bugs.gentoo.org/737660
	sed -i -e "s:-j0:-j$(makeopts_jobs):" Makefile.pre.in || die

	# breaks tests when using --with-wheel-pkg-dir
	rm -r Lib/test/wheeldata || die

	eautoreconf
}

build_cbuild_python() {
	# Hack to workaround get_libdir not being able to handle CBUILD, bug #794181
	local cbuild_libdir=$(unset PKG_CONFIG_PATH ; $(tc-getBUILD_PKG_CONFIG) --keep-system-libs --libs-only-L libffi)

	# pass system CFLAGS & LDFLAGS as _NODIST, otherwise they'll get
	# propagated to sysconfig for built extensions
	#
	# -fno-lto to avoid bug #700012 (not like it matters for mini-CBUILD Python anyway)
	local -x CFLAGS_NODIST="${BUILD_CFLAGS} -fno-lto"
	local -x LDFLAGS_NODIST=${BUILD_LDFLAGS}
	local -x CFLAGS= LDFLAGS=
	local -x BUILD_CFLAGS="${CFLAGS_NODIST}"
	local -x BUILD_LDFLAGS=${LDFLAGS_NODIST}

	# We need to build our own Python on CBUILD first, and feed it in.
	# bug #847910
	local myeconfargs_cbuild=(
		"${myeconfargs[@]}"

		--prefix="${BROOT}"/usr
		--libdir="${cbuild_libdir:2}"

		# Avoid needing to load the right libpython.so.
		--disable-shared

		# As minimal as possible for the mini CBUILD Python
		# we build just for cross to satisfy --with-build-python.
		--without-lto
		--without-readline
		--disable-optimizations
	)

	mkdir "${WORKDIR}"/${P}-${CBUILD} || die
	pushd "${WORKDIR}"/${P}-${CBUILD} &> /dev/null || die

	# Avoid as many dependencies as possible for the cross build.
	mkdir Modules || die
	cat > Modules/Setup.local <<-EOF || die
		*disabled*
		nis
		_dbm _gdbm
		_sqlite3
		_hashlib _ssl
		_curses _curses_panel
		readline
		_tkinter
		pyexpat
		zlib
		# We disabled these for CBUILD because Python's setup.py can't handle locating
		# libdir correctly for cross. This should be rechecked for the pure Makefile approach,
		# and uncommented if needed.
		#_ctypes _crypt
	EOF

	ECONF_SOURCE="${S}" econf_build "${myeconfargs_cbuild[@]}"

	# Unfortunately, we do have to build this immediately, and
	# not in src_compile, because CHOST configure for Python
	# will check the existence of the --with-build-python value
	# immediately.
	emake
	popd &> /dev/null || die
}

src_configure() {
	# disable automagic bluetooth headers detection
	if ! use bluetooth; then
		local -x ac_cv_header_bluetooth_bluetooth_h=no
	fi

	append-flags -fwrapv
	filter-flags -malign-double

	# Export CXX so it ends up in /usr/lib/python3.X/config/Makefile.
	# PKG_CONFIG needed for cross.
	tc-export CXX PKG_CONFIG

	local dbmliborder=
	if use gdbm; then
		dbmliborder+="${dbmliborder:+:}gdbm"
	fi

	# Set baseline test skip flags.
	COMMON_TEST_SKIPS=(
		# this is actually test_gdb.test_pretty_print
		-x test_pretty_print
	)

	# Arch-specific skips.  See #931888 for a collection of these.
	case ${CHOST} in
		alpha*)
			COMMON_TEST_SKIPS+=(
				-x test_builtin
				-x test_capi
				-x test_cmath
				-x test_float
				# timeout
				-x test_free_threading
				-x test_math
				-x test_numeric_tower
				-x test_random
				-x test_statistics
				# bug 653850
				-x test_resource
				-x test_strtod
			)
			;;
		mips*)
			COMMON_TEST_SKIPS+=(
				-x test_ctypes
				-x test_external_inspection
				-x test_statistics
			)
			;;
		powerpc64-*) # big endian
			COMMON_TEST_SKIPS+=(
				-x test_gdb
			)
			;;
		riscv*)
			COMMON_TEST_SKIPS+=(
				-x test_urllib2
			)
			;;
		sparc*)
			COMMON_TEST_SKIPS+=(
				# bug 788022
				-x test_multiprocessing_fork
				-x test_multiprocessing_forkserver
				-x test_multiprocessing_spawn

				-x test_ctypes
				-x test_gdb
				# bug 931908
				-x test_exceptions
			)
			;;
	esac

	# musl-specific skips
	use elibc_musl && COMMON_TEST_SKIPS+=(
		# various musl locale deficiencies
		-x test__locale
		-x test_c_locale_coercion
		-x test_locale
		-x test_re

		# known issues with find_library on musl
		# https://bugs.python.org/issue21622
		-x test_ctypes

		# fpathconf, ttyname errno values
		-x test_os
	)

	if use pgo; then
		local profile_task_flags=(
			-m test
			"-j$(makeopts_jobs)"
			--pgo-extended
			-u-network

			# We use a timeout because of how often we've had hang issues
			# here. It also matches the default upstream PROFILE_TASK.
			--timeout 1200

			"${COMMON_TEST_SKIPS[@]}"

			-x test_dtrace

			# All of these seem to occasionally hang for PGO inconsistently
			# They'll even hang here but be fine in src_test sometimes.
			# bug #828535 (and related: bug #788022)
			-x test_asyncio
			-x test_concurrent_futures
			-x test_httpservers
			-x test_logging
			-x test_multiprocessing_fork
			-x test_socket
			-x test_xmlrpc

			# Hangs (actually runs indefinitely executing itself w/ many cpython builds)
			# bug #900429
			-x test_tools
		)

		# Arch-specific skips.  See #931888 for a collection of these.
		case ${CHOST} in
			alpha*)
				profile_task_flags+=(
					-x test_os
				)
				;;
			hppa*)
				profile_task_flags+=(
					-x test_descr
					# bug 931908
					-x test_exceptions
					-x test_os
				)
				;;
			powerpc64-*) # big endian
				profile_task_flags+=(
					# bug 931908
					-x test_exceptions
				)
				;;
			riscv*)
				profile_task_flags+=(
					-x test_statistics
				)
				;;
		esac

		if has_version "app-arch/rpm" ; then
			# Avoid sandbox failure (attempts to write to /var/lib/rpm)
			profile_task_flags+=(
				-x test_distutils
			)
		fi
		local -x PROFILE_TASK="${profile_task_flags[*]}"
	fi

	local myeconfargs=(
		# glibc-2.30 removes it; since we can't cleanly force-rebuild
		# Python on glibc upgrade, remove it proactively to give
		# a chance for users rebuilding python before glibc
		ac_cv_header_stropts_h=no

		$(usex static --disable-shared --enable-shared)
		$(usev !static-libs --without-static-libpython)
		--enable-ipv6
		--infodir='${prefix}/share/info'
		--mandir='${prefix}/share/man'
		--with-computed-gotos
		--with-dbmliborder="${dbmliborder}"
		--with-libc=
		$(usev sqlite --enable-loadable-sqlite-extensions)
		--without-ensurepip
		--without-lto
		--with-system-expat
		--with-system-libmpdec
		--with-platlibdir=lib
		--with-pkg-config=yes
		--with-wheel-pkg-dir="${EPREFIX}"/usr/lib/python/ensurepip

		$(use_with debug assertions)
		$(use_enable pgo optimizations)
		$(use_with readline readline "$(usex libedit editline readline)")
		$(use_with valgrind)
	)

	# https://bugs.gentoo.org/700012
	if tc-is-lto; then
		append-cflags $(test-flags-CC -ffat-lto-objects)
		myeconfargs+=(
			--with-lto
		)
	fi

	use static && append-ldflags -static

	# Force-disable modules we don't want built.
	# See Modules/Setup for docs on how this works. Setup.local contains our local deviations.
	cat > Modules/Setup.local <<-EOF || die
*static*

############################################################################
# Modules that should always be present (POSIX and Windows):
array arraymodule.c
_asyncio _asynciomodule.c
_bisect _bisectmodule.c
_contextvars _contextvarsmodule.c
_csv _csv.c
_heapq _heapqmodule.c
_json _json.c
_lsprof _lsprof.c rotatingtree.c
_opcode _opcode.c
_pickle _pickle.c
_queue _queuemodule.c
_random _randommodule.c
_struct _struct.c
_xxsubinterpreters _xxsubinterpretersmodule.c
_xxinterpchannels _xxinterpchannelsmodule.c
_zoneinfo _zoneinfo.c

# needs libm
audioop audioop.c
math mathmodule.c
cmath cmathmodule.c
_statistics _statisticsmodule.c

# needs libm and on some platforms librt
_datetime _datetimemodule.c

# _decimal uses libmpdec
# either static libmpdec.a from Modules/_decimal/libmpdec or libmpdec.so
# with ./configure --with-system-libmpdec
_decimal _decimal/_decimal.c

# compression libs and binascii (optional CRC32 from zlib)
# bindings need -lbz2, -lz, or -llzma, respectively
binascii binascii.c
_bz2 _bz2module.c
_lzma _lzmamodule.c
zlib zlibmodule.c

# dbm/gdbm
# dbm needs either libndbm, libgdbm_compat, or libdb 5.x
_dbm _dbmmodule.c
# gdbm module needs -lgdbm
$(usex gdbm '_gdbm _gdbmmodule.c')

# needs -lreadline or -ledit, sometimes termcap, termlib, or tinfo
$(usex readline 'readline readline.c')

# hashing builtins, can be disabled with --without-builtin-hashlib-hashes
_md5 md5module.c -I${S}/Modules/_hacl/include _hacl/Hacl_Hash_MD5.c -D_BSD_SOURCE -D_DEFAULT_SOURCE
_sha1 sha1module.c -I${S}/Modules/_hacl/include _hacl/Hacl_Hash_SHA1.c -D_BSD_SOURCE -D_DEFAULT_SOURCE
_sha2 sha2module.c -I${S}/Modules/_hacl/include Modules/_hacl/libHacl_Hash_SHA2.a
_sha3 sha3module.c -I${S}/Modules/_hacl/include _hacl/Hacl_Hash_SHA3.c -D_BSD_SOURCE -D_DEFAULT_SOURCE
_blake2 _blake2/blake2module.c _blake2/blake2b_impl.c _blake2/blake2s_impl.c

############################################################################
# XML and text

# pyexpat module uses libexpat
# either static libexpat.a from Modules/expat or libexpat.so with
# ./configure --with-system-expat
pyexpat pyexpat.c

# _elementtree libexpat via CAPI hook in pyexpat.
_elementtree _elementtree.c

_codecs_cn cjkcodecs/_codecs_cn.c
_codecs_hk cjkcodecs/_codecs_hk.c
_codecs_iso2022 cjkcodecs/_codecs_iso2022.c
_codecs_jp cjkcodecs/_codecs_jp.c
_codecs_kr cjkcodecs/_codecs_kr.c
_codecs_tw cjkcodecs/_codecs_tw.c
_multibytecodec cjkcodecs/multibytecodec.c
unicodedata unicodedata.c

############################################################################
# Modules with some UNIX dependencies
#

# needs -lcrypt on some systems
_crypt _cryptmodule.c
fcntl fcntlmodule.c
grp grpmodule.c
mmap mmapmodule.c
# FreeBSD: nis/yp APIs are in libc
# needs sys/soundcard.h or linux/soundcard.h (Linux, FreeBSD)
ossaudiodev ossaudiodev.c
_posixsubprocess _posixsubprocess.c
resource resource.c
select selectmodule.c
_socket socketmodule.c
# AIX has shadow passwords, but does not provide getspent API
spwd spwdmodule.c
syslog syslogmodule.c
termios termios.c

# multiprocessing
_posixshmem _multiprocessing/posixshmem.c
_multiprocessing _multiprocessing/multiprocessing.c _multiprocessing/semaphore.c

############################################################################
# Modules with third party dependencies
#

# needs -lffi and -ldl

# needs -lncurses[w], sometimes -ltermcap/tinfo
$(usev ncurses '_curses _cursesmodule.c')
# needs -lncurses[w] and -lpanel[w]
$(usev ncurses '_curses_panel _curses_panel.c')

$(usev sqlite '_sqlite3 _sqlite/blob.c _sqlite/connection.c _sqlite/cursor.c _sqlite/microprotocols.c _sqlite/module.c _sqlite/prepare_protocol.c _sqlite/row.c _sqlite/statement.c _sqlite/util.c')

# needs -lssl and -lcrypt
$(usev ssl '_ssl _ssl.c')
# needs -lcrypt
_hashlib _hashopenssl.c

# Linux: -luuid, BSD/AIX: libc's uuid_create()
_uuid _uuidmodule.c

		*disabled*
		nis
		$(usev !gdbm '_gdbm _dbm')
		$(usev !sqlite '_sqlite3')
		$(usev !ssl '_hashlib _ssl')
		$(usev !ncurses '_curses _curses_panel')
		$(usev !readline 'readline')
		$(usev !tk '_tkinter')
		$(usev static '_ctypes')

xxsubtype xxsubtype.c
_xxtestfuzz _xxtestfuzz/_xxtestfuzz.c _xxtestfuzz/fuzzer.c
_testbuffer _testbuffer.c
_testinternalcapi _testinternalcapi.c
_testcapi _testcapimodule.c _testcapi/vectorcall.c _testcapi/vectorcall_limited.c _testcapi/heaptype.c _testcapi/abstract.c _testcapi/bytearray.c _testcapi/bytes.c _testcapi/unicode.c _testcapi/dict.c _testcapi/set.c _testcapi/list.c _testcapi/tuple.c _testcapi/getargs.c _testcapi/pytime.c _testcapi/datetime.c _testcapi/docstring.c _testcapi/mem.c _testcapi/watchers.c _testcapi/long.c _testcapi/float.c _testcapi/complex.c _testcapi/numbers.c _testcapi/structmember.c _testcapi/exceptions.c _testcapi/code.c _testcapi/buffer.c _testcapi/pyos.c _testcapi/run.c _testcapi/file.c _testcapi/codec.c _testcapi/immortal.c _testcapi/heaptype_relative.c _testcapi/gc.c _testcapi/sys.c _testcapi/import.c _testcapi/eval.c
_testclinic _testclinic.c

_testimportmultiple _testimportmultiple.c
_testmultiphase _testmultiphase.c
_testsinglephase _testsinglephase.c
_ctypes_test _ctypes/_ctypes_test.c

xxlimited xxlimited.c
xxlimited_35 xxlimited_35.c
	EOF

	# disable implicit optimization/debugging flags
	local -x OPT=

	if tc-is-cross-compiler ; then
		build_cbuild_python
		myeconfargs+=(
			# Point the imminent CHOST build to the Python we just
			# built for CBUILD.
			--with-build-python="${WORKDIR}"/${P}-${CBUILD}/python
		)
	fi

	# pass system CFLAGS & LDFLAGS as _NODIST, otherwise they'll get
	# propagated to sysconfig for built extensions
	local -x CFLAGS_NODIST=${CFLAGS}
	local -x LDFLAGS_NODIST=${LDFLAGS}
	local -x CFLAGS= LDFLAGS=

	# Fix implicit declarations on cross and prefix builds. Bug #674070.
	if use ncurses; then
		append-cppflags -I"${ESYSROOT}"/usr/include/ncursesw
	fi

	DYNLOADFILE=dynload_stub.o econf "${myeconfargs[@]}"

	if grep -q "#define POSIX_SEMAPHORES_NOT_ENABLED 1" pyconfig.h; then
		eerror "configure has detected that the sem_open function is broken."
		eerror "Please ensure that /dev/shm is mounted as a tmpfs with mode 1777."
		die "Broken sem_open function (bug 496328)"
	fi

	sed -i -e 's/#define HAVE_DLOPEN 1.*/#undef HAVE_DLOPEN/' pyconfig.h
	sed -i -e 's/#define HAVE_DYNAMIC_LOADING.*/#undef HAVE_DYNAMIC_LOADING/' pyconfig.h

	# install epython.py as part of stdlib
	echo "EPYTHON='python${PYVER}'" > Lib/epython.py || die
}

src_compile() {
	# Ensure sed works as expected
	# https://bugs.gentoo.org/594768
	local -x LC_ALL=C
	export PYTHONSTRICTEXTENSIONBUILD=1

	# Save PYTHONDONTWRITEBYTECODE so that 'has_version' doesn't
	# end up writing bytecode & violating sandbox.
	# bug #831897
	local -x _PYTHONDONTWRITEBYTECODE=${PYTHONDONTWRITEBYTECODE}

	# Gentoo hack to disable accessing system site-packages
	export GENTOO_CPYTHON_BUILD=1

	if use pgo ; then
		# bug 660358
		local -x COLUMNS=80
		local -x PYTHONDONTWRITEBYTECODE=
		local -x TMPDIR=/var/tmp
	fi

	# also need to clear the flags explicitly here or they end up
	# in _sysconfigdata*
	emake CPPFLAGS= CFLAGS= LDFLAGS=

	# Restore saved value from above.
	local -x PYTHONDONTWRITEBYTECODE=${_PYTHONDONTWRITEBYTECODE}

	# Work around bug 329499. See also bug 413751 and 457194.
	if has_version dev-libs/libffi[pax-kernel]; then
		pax-mark E python
	else
		pax-mark m python
	fi
}

src_test() {
	# Tests will not work when cross compiling.
	if tc-is-cross-compiler; then
		elog "Disabling tests due to crosscompiling."
		return
	fi

	# this just happens to skip test_support.test_freeze that is broken
	# without bundled expat
	# TODO: get a proper skip for it upstream
	local -x LOGNAME=buildbot

	local test_opts=(
		--verbose3
		-u-network
		-j "$(makeopts_jobs)"
		"${COMMON_TEST_SKIPS[@]}"
	)

	# bug 660358
	local -x COLUMNS=80
	local -x PYTHONDONTWRITEBYTECODE=
	local -x TMPDIR=/var/tmp

	nonfatal emake -Onone test EXTRATESTOPTS="${test_opts[*]}" \
		CPPFLAGS= CFLAGS= LDFLAGS= < /dev/tty
	local ret=${?}

	[[ ${ret} -eq 0 ]] || die "emake test failed"
}

src_install() {
	local libdir=${ED}/usr/lib/python${PYVER}

	# the Makefile rules are broken
	# https://github.com/python/cpython/issues/100221
	mkdir -p "${libdir}"/lib-dynload || die

	# -j1 hack for now for bug #843458
	emake -j1 DESTDIR="${D}" TEST_MODULES=no altinstall

	# Fix collisions between different slots of Python.
	use static || rm "${ED}/usr/$(get_libdir)/libpython3.so" || die

	# Cheap hack to get version with ABIFLAGS
	local abiver=$(cd "${ED}/usr/include"; echo python*)
	if [[ ${abiver} != python${PYVER} ]]; then
		# Replace python3.X with a symlink to python3.Xm
		rm "${ED}/usr/bin/python${PYVER}" || die
		dosym "${abiver}" "/usr/bin/python${PYVER}"
		# Create python3.X-config symlink
		dosym "${abiver}-config" "/usr/bin/python${PYVER}-config"
		# Create python-3.5m.pc symlink
		dosym "python-${PYVER}.pc" "/usr/$(get_libdir)/pkgconfig/${abiver/${PYVER}/-${PYVER}}.pc"
	fi

	# python seems to get rebuilt in src_install (bug 569908)
	# Work around it for now.
	if has_version dev-libs/libffi[pax-kernel]; then
		pax-mark E "${ED}/usr/bin/${abiver}"
	else
		pax-mark m "${ED}/usr/bin/${abiver}"
	fi

	rm -r "${libdir}"/ensurepip/_bundled || die
	if ! use sqlite; then
		rm -r "${libdir}/"sqlite3 || die
	fi
	if ! use tk; then
		rm -r "${ED}/usr/bin/idle${PYVER}" || die
		rm -r "${libdir}/"{idlelib,tkinter} || die
	fi

	ln -s ../python/EXTERNALLY-MANAGED "${libdir}/EXTERNALLY-MANAGED" || die

	dodoc Misc/{ACKS,HISTORY,NEWS}

	if use examples; then
		docinto examples
		find Tools -name __pycache__ -exec rm -fr {} + || die
		dodoc -r Tools
	fi
	insinto /usr/share/gdb/auto-load/usr/$(get_libdir) #443510
	local libname=$(
		printf 'e:\n\t@echo $(INSTSONAME)\ninclude Makefile\n' |
		emake --no-print-directory -s -f - 2>/dev/null
	)
	newins Tools/gdb/libpython.py "${libname}"-gdb.py

	newconfd "${FILESDIR}/pydoc.conf" pydoc-${PYVER}
	newinitd "${FILESDIR}/pydoc.init" pydoc-${PYVER}
	sed \
		-e "s:@PYDOC_PORT_VARIABLE@:PYDOC${PYVER/./_}_PORT:" \
		-e "s:@PYDOC@:pydoc${PYVER}:" \
		-i "${ED}/etc/conf.d/pydoc-${PYVER}" \
		"${ED}/etc/init.d/pydoc-${PYVER}" || die "sed failed"

	# python-exec wrapping support
	local pymajor=${PYVER%.*}
	local EPYTHON=python${PYVER}
	local scriptdir=${D}$(python_get_scriptdir)
	mkdir -p "${scriptdir}" || die
	# python and pythonX
	ln -s "../../../bin/${abiver}" "${scriptdir}/python${pymajor}" || die
	ln -s "python${pymajor}" "${scriptdir}/python" || die
	# python-config and pythonX-config
	# note: we need to create a wrapper rather than symlinking it due
	# to some random dirname(argv[0]) magic performed by python-config
	cat > "${scriptdir}/python${pymajor}-config" <<-EOF || die
		#!/bin/sh
		exec "${abiver}-config" "\${@}"
	EOF
	chmod +x "${scriptdir}/python${pymajor}-config" || die
	ln -s "python${pymajor}-config" "${scriptdir}/python-config" || die
	# 2to3, pydoc
	ln -s "../../../bin/2to3-${PYVER}" "${scriptdir}/2to3" || die
	ln -s "../../../bin/pydoc${PYVER}" "${scriptdir}/pydoc" || die
	# idle
	if use tk; then
		ln -s "../../../bin/idle${PYVER}" "${scriptdir}/idle" || die
	fi
}
