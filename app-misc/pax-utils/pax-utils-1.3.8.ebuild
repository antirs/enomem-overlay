# Copyright 2022-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

# Note: if bumping pax-utils because of syscall changes in glibc, please
# revbump glibc and update the dependency in its ebuild for the affected
# versions.
PYTHON_COMPAT=( python3_{10..13} )

inherit flag-o-matic meson python-single-r1

DESCRIPTION="ELF utils that can check files for security relevant properties"
HOMEPAGE="https://wiki.gentoo.org/wiki/Hardened/PaX_Utilities"

if [[ ${PV} == 9999 ]]; then
	EGIT_REPO_URI="https://anongit.gentoo.org/git/proj/pax-utils.git"
	inherit git-r3
else
	SRC_URI="
		https://dev.gentoo.org/~sam/distfiles/${CATEGORY}/${PN}/${P}.tar.xz
		https://dev.gentoo.org/~vapier/dist/${P}.tar.xz
	"
	KEYWORDS="~alpha amd64 arm arm64 hppa ~loong ~m68k ~mips ppc ppc64 ~riscv ~s390 sparc x86 ~amd64-linux ~x86-linux ~arm64-macos ~ppc-macos ~x64-macos ~x64-solaris"
fi

LICENSE="GPL-2"
SLOT="0"
IUSE="caps man python seccomp static test"
REQUIRED_USE="
	python? ( ${PYTHON_REQUIRED_USE} )
	test? ( python )
"
RESTRICT="!test? ( test )"

MY_PYTHON_DEPS="
	${PYTHON_DEPS}
	$(python_gen_cond_dep '
		dev-python/pyelftools[${PYTHON_USEDEP}]
	')
"
RDEPEND="
	!static? ( caps? ( >=sys-libs/libcap-2.24 ) )
	python? ( ${MY_PYTHON_DEPS} )
"
DEPEND="${RDEPEND}
	static? ( caps? ( >=sys-libs/libcap-2.24[static-libs] ) )
"
BDEPEND="
	caps? ( virtual/pkgconfig )
	man? ( app-text/xmlto )
	python? ( ${MY_PYTHON_DEPS} )
"

STATIC_PATCHES=(
	"${FILESDIR}"/${PN}-1.3.8-static-dependencies.patch
)

pkg_setup() {
	if use test || use python; then
		python-single-r1_pkg_setup
	fi
}

src_prepare() {
	cd "${WORKDIR}"/${P} || die
	default

	if use static; then
		eapply  "${STATIC_PATCHES[@]}"
	fi
}

src_configure() {
	local emesonargs=(
		"-Dlddtree_implementation=$(usex python python sh)"
		$(meson_feature caps use_libcap)
		$(meson_feature man build_manpages)
		$(meson_use seccomp use_seccomp)
		$(meson_use test tests)

		# fuzzing is currently broken
		-Duse_fuzzing=false
	)
	use static && append-ldflags -static

	if [[ -n "${ESYSROOT}" ]]; then
		export PKG_CONFIG_SYSROOT_DIR="${ESYSROOT}"
		export PKG_CONFIG_PATH="${ESYSROOT}/usr/$(get_libdir)/pkgconfig"
	fi

	meson_src_configure
}

src_install() {
	meson_src_install

	use python && python_fix_shebang "${ED}"/usr/bin/lddtree
}
