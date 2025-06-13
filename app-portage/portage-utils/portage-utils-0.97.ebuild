# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit flag-o-matic toolchain-funcs

DESCRIPTION="Small and fast Portage helper tools written in C"
HOMEPAGE="https://wiki.gentoo.org/wiki/Portage-utils"

if [[ ${PV} == *9999 ]]; then
	inherit git-r3 autotools
	EGIT_REPO_URI="https://anongit.gentoo.org/git/proj/portage-utils.git"
else
	SRC_URI="https://dev.gentoo.org/~grobian/distfiles/${P}.tar.xz"
	KEYWORDS="~alpha amd64 arm arm64 hppa ~loong ~m68k ~mips ppc ppc64 ~riscv ~s390 sparc x86 ~amd64-linux ~x86-linux ~arm64-macos ~ppc-macos ~x64-macos ~x64-solaris"
fi

LICENSE="GPL-2"
SLOT="0"
IUSE="openmp +qmanifest static static-libs"

LIB_DEPEND="
	qmanifest? (
		app-crypt/gpgme[static-libs?]
		app-crypt/libb2[static-libs?]
		sys-libs/zlib[static-libs?]
	)
"
RDEPEND="
	!static? ( ${LIB_DEPEND} )
	openmp? ( || (
		sys-devel/gcc:*[openmp]
		llvm-runtimes/openmp
	) )
"
DEPEND="
	${RDEPEND}
	${LIB_DEPEND}
"
BDEPEND="virtual/pkgconfig"

# bug #898362, gnulib explicit checks
QA_CONFIG_IMPL_DECL_SKIP=(
	"MIN"
	"unreachable"
	"alignof"
	"static_assert"
)

pkg_setup() {
	[[ ${MERGE_TYPE} != binary ]] && use openmp && tc-check-openmp
}

src_prepare() {
	default
	[[ ${PV} == *9999 ]] && eautoreconf
}

src_configure() {
	local myconf=(
		--disable-maintainer-mode
		--with-eprefix="${EPREFIX}"
		$(use_enable qmanifest)
		$(use_enable openmp)
	)

	use static && append-ldflags -static

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
