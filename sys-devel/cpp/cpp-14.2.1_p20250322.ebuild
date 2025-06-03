# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

# Maintenance notes and explanations of GCC handling are on the wiki:
# https://wiki.gentoo.org/wiki/Project:Toolchain/sys-devel/gcc

TOOLCHAIN_PATCH_DEV="sam"
TOOLCHAIN_HAS_TESTS=1
PATCH_GCC_VER="14.2.0"
PATCH_VER="8"
MUSL_VER="1"
MUSL_GCC_VER="14.1.0"
PYTHON_COMPAT=( python3_{10..13} )

if [[ -n ${TOOLCHAIN_GCC_RC} ]] ; then
	# Cheesy hack for RCs
	MY_PV=$(ver_cut 1).$((($(ver_cut 2) + 1))).$((($(ver_cut 3) - 1)))-RC-$(ver_cut 5)
	MY_P=gcc-${MY_PV}
	GCC_TARBALL_SRC_URI="mirror://gcc/snapshots/${MY_PV}/${MY_P}.tar.xz"
	TOOLCHAIN_SET_S=no
	S="${WORKDIR}"/${MY_P}
fi

inherit flag-o-matic toolchain

if tc_is_live ; then
	# Needs to be after inherit (for now?), bug #830908
	EGIT_BRANCH=releases/gcc-$(ver_cut 1)
elif [[ -z ${TOOLCHAIN_USE_GIT_PATCHES} ]] ; then
	# m68k doesnt build (ICE, bug 932733)
	KEYWORDS="~alpha ~amd64 ~arm ~arm64 ~hppa ~loong ~mips ~ppc ~ppc64 ~riscv ~s390 ~sparc ~x86"
	:;
fi

if [[ ${CATEGORY} != cross-* ]] ; then
	# Technically only if USE=hardened *too* right now, but no point in complicating it further.
	# If GCC is enabling CET by default, we need glibc to be built with support for it.
	# bug #830454
	RDEPEND="elibc_glibc? ( sys-libs/glibc[cet(-)?] )"
	DEPEND="${RDEPEND}"
fi

src_prepare() {
	local p upstreamed_patches=(
		# add them here
	)
	for p in "${upstreamed_patches[@]}"; do
		rm -v "${WORKDIR}/patch/${p}" || die
	done

	toolchain_src_prepare

	eapply "${FILESDIR}"/gcc-13-fix-cross-fixincludes.patch
	eapply_user
}

IUSE="+custom-cflags +static"

src_configure() {
	EXTRA_ECONF=(--disable-bootstrap
				 --disable-host-pie
				 --disable-host-shared
				 --disable-lto
				 --disable-multilib
				 --disable-nls
				 --disable-shared
				 --enable-static
				 --with-stage1-ldflags=-static "${EXTRA_ECONF}")
	export EXTRA_ECONF="${EXTRA_ECONF[@]}"

	toolchain_src_configure
	append-ldflags "-static"
}

src_compile() {
	touch "${S}"/gcc/c-gperf.h || die

	# Do not make manpages if we do not have perl ...
	[[ ! -x "${BROOT}"/usr/bin/perl ]] \
		&& find "${WORKDIR}"/build -name '*.[17]' -exec touch {} +

	# Older gcc versions did not detect bash and re-exec itself, so force the
	# use of bash for them.
	# This needs to be set for compile as well, as it's used in libtool
	# generation, which will break install otherwise (at least in 3.3.6): bug #664486
	local gcc_shell="${BROOT}"/bin/bash
	if tc_version_is_at_least 11.2 ; then
		gcc_shell="${BROOT}"/bin/sh
	fi

	GCC_MAKE_TARGET=all-build-libiberty
	CONFIG_SHELL="${gcc_shell}" \
		gcc_do_make ${GCC_MAKE_TARGET}

	GCC_MAKE_TARGET=all-build-libcpp
	CONFIG_SHELL="${gcc_shell}" \
		gcc_do_make ${GCC_MAKE_TARGET}

	GCC_MAKE_TARGET=all-libcpp
	CONFIG_SHELL="${gcc_shell}" \
		gcc_do_make ${GCC_MAKE_TARGET}

	GCC_MAKE_TARGET=all-libdecnumber
	CONFIG_SHELL="${gcc_shell}" \
		gcc_do_make ${GCC_MAKE_TARGET}

	GCC_MAKE_TARGET=all-libbacktrace
	CONFIG_SHELL="${gcc_shell}" \
		gcc_do_make ${GCC_MAKE_TARGET}

	GCC_MAKE_TARGET=configure-gcc
	CONFIG_SHELL="${gcc_shell}" \
		gcc_do_make ${GCC_MAKE_TARGET}

	GCC_MAKE_TARGET=all-gcc-cpp
	einfo "Compiling ${PN} (${GCC_MAKE_TARGET})..."
	pushd "${WORKDIR}"/build/gcc >/dev/null || die
	emake cpp
	emake cc1

	popd >/dev/null || die
}

src_install() {
	cd "${WORKDIR}"/build || die

	S="${WORKDIR}"/build

	# This one comes with binutils
	find "${ED}" -name libiberty.a -delete || die

	dodir /usr/bin
	dobin "${S}"/gcc/cpp
	dobin "${S}"/gcc/cc1
}
