# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit flag-o-matic libtool optfeature

DESCRIPTION="A powerful light-weight programming language designed for extending applications"
HOMEPAGE="https://www.lua.org/"
# tarballs produced from ${PV} branches in https://gitweb.gentoo.org/proj/lua-patches.git
SRC_URI="https://dev.gentoo.org/~soap/distfiles/${P}.tar.xz"

LICENSE="MIT"
SLOT="5.4"
KEYWORDS="~alpha amd64 arm arm64 hppa ~loong ~m68k ~mips ppc ppc64 ~riscv ~s390 sparc x86 ~amd64-linux ~x86-linux ~ppc-macos ~x64-macos ~x64-solaris"
IUSE="+deprecated readline static static-libs"

LIB_DEPEND="
	readline? ( sys-libs/readline:=[static-libs?] )
"
RDEPEND="
	!static? ( ${LIB_DEPEND} )
	>=app-eselect/eselect-lua-3
	!dev-lang/lua:0
"
DEPEND="
	${RDEPEND}
	${LIB_DEPEND}
"
BDEPEND="virtual/pkgconfig"

PATCHES=(
	# Backported variant of upstream patch to fix sparc tests, bug #914562
	"${FILESDIR}"/${PN}-5.4.6-sparc-tests.patch
)

src_prepare() {
	default
	elibtoolize

	if use elibc_musl; then
		# locales on musl are non-functional (#834153)
		# https://wiki.musl-libc.org/open-issues.html#Locale-limitations
		sed -e 's|os.setlocale("pt_BR") or os.setlocale("ptb")|false|g' \
			-i tests/literals.lua || die
	fi
}

src_configure() {
	use deprecated && append-cppflags -DLUA_COMPAT_5_3

	use static && append-ldflags -static $(test-flags-CCLD --static)

	if [[ -n "${ESYSROOT}" ]]; then
		append-ldflags -L"${ESYSROOT}"/usr/$(get_libdir)
		export PKG_CONFIG_SYSROOT_DIR="${ESYSROOT}"
		export PKG_CONFIG_LIBDIR="${ESYSROOT}/usr/$(get_libdir)/pkgconfig"
		export PKG_CONFIG_PATH="${ESYSROOT}/usr/$(get_libdir)/pkgconfig"
	fi

	if use static; then
		PKG_CONFIG="$(tc-getPKG_CONFIG) --static" econf $(use_with readline)
	else
		econf $(use_with readline)
	fi
}

src_install() {
	default
	find "${ED}" -name '*.la' -delete || die
}

pkg_postinst() {
	eselect lua set --if-unset "${PN}${SLOT}"

	optfeature "Lua support for Emacs" app-emacs/lua-mode
}
