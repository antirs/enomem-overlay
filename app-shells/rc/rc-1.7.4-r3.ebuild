# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit autotools flag-o-matic

DESCRIPTION="A reimplementation of the Plan 9 shell"
HOMEPAGE="http://static.tobold.org/"
SRC_URI="http://static.tobold.org/${PN}/${P}.tar.gz"

LICENSE="rc"
SLOT="0"
KEYWORDS="~amd64 ~x86"
IUSE="libedit readline static"

RDEPEND="!static? ( sys-libs/ncurses:= )
	!static? ( readline? ( sys-libs/readline:= ) )
	!static? ( libedit? ( dev-libs/libedit ) )"
DEPEND="${RDEPEND}"
BDEPEND="
	static? ( sys-libs/ncurses:=[static-libs] )
	static? ( readline? ( sys-libs/readline:=[static-libs] ) )
	static? ( libedit? ( dev-libs/libedit[static-libs] ) )
"

DOCS=( AUTHORS ChangeLog NEWS README )

PATCHES=(
	"${FILESDIR}"/"${P}"-libedit.patch
	"${FILESDIR}"/"${P}"-C23.patch
)

src_prepare() {
	default
	eautoreconf
}

src_configure() {
	local myconf="--with-history"
	use readline && myconf="--with-edit=readline"
	use libedit && myconf="--with-edit=edit"

	use static && append-cflags -static
	use static && append-ldflags -static

	econf "${myconf}"
}

src_install() {
	into /usr
	newbin "${PN}" "${PN}sh"
	newman "${PN}.1" "${PN}sh.1"
	einstalldocs
}

pkg_postinst() {
	if ! grep -q '^/usr/bin/rcsh$' "${EROOT}"/etc/shells ; then
		ebegin "Updating /etc/shells"
		echo "/usr/bin/rcsh" >> "${EROOT}"/etc/shells
		eend $?
	fi
}
