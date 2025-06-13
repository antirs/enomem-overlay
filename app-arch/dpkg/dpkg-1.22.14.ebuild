# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit autotools flag-o-matic toolchain-funcs

DESCRIPTION="Package maintenance system for Debian"
HOMEPAGE="https://packages.qa.debian.org/dpkg"
SRC_URI="mirror://debian/pool/main/d/${PN}/${P/-/_}.tar.xz"

LICENSE="GPL-2+"
SLOT="0"
KEYWORDS="~alpha amd64 arm arm64 hppa ~loong ~m68k ppc ppc64 ~riscv ~s390 sparc x86 ~amd64-linux ~x86-linux"
IUSE="+bzip2 +lzma nls selinux static static-libs test +update-alternatives +zlib +zstd"
RESTRICT="!test? ( test )"

LIB_DEPEND="
	>=app-arch/gzip-1.7
	>=app-arch/tar-1.34-r1
	app-crypt/libmd[static-libs?]
	>=dev-lang/perl-5.32.1:=
	sys-libs/ncurses:=[unicode(+),static-libs?]
	bzip2? ( app-arch/bzip2[static-libs?] )
	elibc_musl? ( sys-libs/obstack-standalone[static-libs?] )
	lzma? ( app-arch/xz-utils[static-libs?] )
	nls? ( virtual/libintl[static-libs?] )
	selinux? ( sys-libs/libselinux[static-libs?] )
	zlib? ( >=sys-libs/zlib-1.1.4[static-libs?] )
	zstd? ( app-arch/zstd:=[static-libs?] )
"
RDEPEND="!static? ( ${LIB_DEPEND} )"
DEPEND="
	${LIB_DEPEND}
	app-arch/xz-utils[static-libs?]
	virtual/pkgconfig
	test? (
		dev-perl/IO-String
		dev-perl/Test-Pod
		virtual/perl-Test-Harness
	)
"
BDEPEND="
	sys-devel/flex
	nls? (
		app-text/po4a
		>=sys-devel/gettext-0.18.2
	)
"
RDEPEND+=" selinux? ( sec-policy/selinux-dpkg )"

PATCHES=(
	"${FILESDIR}"/${PN}-1.22.0-flags.patch
)

MUSL_PATCHES=(
	"${FILESDIR}"/dpkg-undefined-obstack-free.patch
)

src_prepare() {
	default

	use elibc_musl && eapply "${MUSL_PATCHES[@]}"

	sed -i -e 's|\<ar\>|${AR}|g' src/at/deb-format.at src/at/testsuite || die

	eautoreconf
}

src_configure() {
	tc-export AR CC

	local myconf=(
		--disable-compiler-warnings
		--disable-devel-docs
		--disable-dselect
		--disable-start-stop-daemon
		--enable-unicode
		--localstatedir="${EPREFIX}"/var
		$(use_enable nls)
		$(use_enable update-alternatives)
		$(use_with bzip2 libbz2)
		$(use_with lzma liblzma)
		$(use_with selinux libselinux)
		$(use_with zlib libz)
		$(use_with zstd libzstd)
	)

	use static && append-ldflags -static $(test-flags-CCLD --static)

	if [[ -n "${ESYSROOT}" ]]; then
		append-ldflags -L"${ESYSROOT}"/usr/$(get_libdir)
		export PKG_CONFIG_SYSROOT_DIR="${ESYSROOT}"
		export PKG_CONFIG_LIBDIR="${ESYSROOT}"/usr/$(get_libdir)/pkgconfig
		export PKG_CONFIG_PATH="${ESYSROOT}/usr/$(get_libdir)/pkgconfig"
	fi

	if use static; then
		PKG_CONFIG="$(tc-getPKG_CONFIG) --static" econf "${myconf[@]}"
	else
		econf "${myconf[@]}"
	fi
}

src_compile() {
	emake AR="$(tc-getAR)"
}

src_install() {
	local DOCS=( debian/changelog THANKS TODO )
	default

	# https://bugs.gentoo.org/835520
	mv -v "${ED}"/usr/share/zsh/{vendor-completions,site-functions} || die

	# https://bugs.gentoo.org/840320
	insinto /etc/dpkg/origins
	newins - gentoo <<-_EOF_
		Vendor: Gentoo
		Vendor-URL: https://www.gentoo.org/
		Bugs: https://bugs.gentoo.org/
	_EOF_
	dosym gentoo /etc/dpkg/origins/default

	keepdir \
		/usr/$(get_libdir)/db/methods/{mnt,floppy,disk} \
		/var/lib/dpkg/{alternatives,info,parts,updates}

	find "${ED}" -name '*.la' -delete || die

	if ! use static-libs; then
		find "${ED}" -name '*.a' -delete || die
	fi
}
