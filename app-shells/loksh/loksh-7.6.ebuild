# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit flag-o-matic meson

DESCRIPTION="Linux port of OpenBSD's ksh"
HOMEPAGE="https://github.com/dimkr/loksh/"

if [[ "${PV}" == *9999* ]] ; then
	inherit git-r3

	EGIT_REPO_URI="https://github.com/dimkr/${PN}.git"
else
	SRC_URI="https://github.com/dimkr/${PN}/releases/download/${PV}/${P}.tar.xz"

	KEYWORDS="amd64 arm arm64 ~ppc64 ~riscv ~x86"
fi

LICENSE="public-domain"
SLOT="0"
IUSE="static static-libs"

LIB_DEPEND="
	sys-libs/ncurses[static-libs?]
"
RDEPEND="
	!static? ( ${LIB_DEPEND} )
	!app-shells/ksh
"
DEPEND="
	${RDEPEND}
	${LIB_DEPEND}
"

src_prepare() {
	default

	sed -i "/install_dir/s@loksh@${PF}@" ./meson.build || die
}

src_configure() {
	use static && append-ldflags -static

	if [[ -n "${ESYSROOT}" ]]; then
		export PKG_CONFIG_SYSROOT_DIR="${ESYSROOT}"
		export PKG_CONFIG_PATH="${ESYSROOT}/usr/$(get_libdir)/pkgconfig"
	fi

	# we want it as /bin/ksh
	meson_src_configure --bindir=../bin
}
