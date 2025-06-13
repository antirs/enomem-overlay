# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit meson-multilib

DESCRIPTION="zstd fast compression library"
HOMEPAGE="https://facebook.github.io/zstd/"
SRC_URI="https://github.com/facebook/zstd/releases/download/v${PV}/${P}.tar.gz"
S="${WORKDIR}"/${P}/build/meson

LICENSE="|| ( BSD GPL-2 )"
SLOT="0/1"
KEYWORDS="~alpha ~amd64 ~arm ~arm64 ~hppa ~loong ~m68k ~mips ~ppc ~ppc64 ~riscv ~s390 ~sparc ~x86 ~amd64-linux ~x86-linux ~arm64-macos ~ppc-macos ~x64-macos ~x64-solaris"
IUSE="+lzma lz4 noshared static static-libs test zlib"
RESTRICT="!test? ( test )"

REQUIRED_USE="
		static? ( noshared )
		noshared? ( static )
"

LIB_DEPEND="
	lzma? ( app-arch/xz-utils[static-libs?] )
	lz4? ( app-arch/lz4:=[static-libs?] )
	zlib? ( sys-libs/zlib[static-libs?] )
"
RDEPEND="
	!static? ( ${LIB_DEPEND} )
"
DEPEND="
	${RDEPEND}
	${LIB_DEPEND}
"

MESON_PATCHES=(
	# Workaround until Valgrind bugfix lands
	"${FILESDIR}"/${PN}-1.5.4-no-find-valgrind.patch
)

PATCHES=(
	"${FILESDIR}"/${PN}-1.5.7-move-pragma-before-static.patch
)

STATIC_PATCHES=(
	"${FILESDIR}"/${PN}-1.5.7-static-dependencies.patch
)

src_prepare() {
	cd "${WORKDIR}"/${P} || die
	default

	if use static; then
		eapply  "${STATIC_PATCHES[@]}"
	fi

	cd "${S}" || die
	eapply "${MESON_PATCHES[@]}"
}

multilib_src_configure() {
	local native_file="${T}"/meson.${CHOST}.${ABI}.ini.local

	# This replaces the no-find-valgrind patch once bugfix lands in a meson
	# release + we can BDEPEND on it (https://github.com/mesonbuild/meson/pull/11372)
	cat >> ${native_file} <<-EOF || die
	[binaries]
	valgrind='valgrind-falseified'
	EOF

	local default_library=$(multilib_native_usex static-libs both shared)
	if use noshared; then
		default_library="static"
	fi

	local emesonargs=(
		-Ddefault_library="${default_library}"

		$(meson_native_true bin_programs)
		$(meson_native_true bin_contrib)
		$(meson_use test bin_tests)

		$(meson_native_use_feature zlib)
		$(meson_native_use_feature lzma)
		$(meson_native_use_feature lz4)

		--native-file "${native_file}"
	)

	use static && append-ldflags -static

	if [[ -n "${ESYSROOT}" ]]; then
		use static && append-ldflags -L"${ESYSROOT}/usr/$(get_libdir)"
		export PKG_CONFIG_SYSROOT_DIR="${ESYSROOT}"
		export PKG_CONFIG_PATH="${ESYSROOT}/usr/$(get_libdir)/pkgconfig"
	fi

	meson_src_configure
}

multilib_src_test() {
	meson_src_test --timeout-multiplier=2
}
