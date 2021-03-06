#!/usr/bin/env bash

# This mkimage-alpine.sh is a modified version from
# https://github.com/docker/docker/blob/master/contrib/mkimage-alpine.sh.
# Changes were inspired by work done by Eivind Uggedal (uggedal) and
# Luis Lavena (luislavena).

declare REL="${REL:-edge}"
declare MIRROR="${MIRROR:-http://nl.alpinelinux.org/alpine}"

set -eo pipefail; [[ "$TRACE" ]] && set -x

[[ "$(id -u)" -eq 0 ]] || {
	printf >&2 '%s requires root\n' "$0" && exit 1
}

usage() {
	printf >&2 '%s: [-r release] [-m mirror] [-s] [-e] [-c] [-t timezone] [-p packages] [-b]\n' "$0" && exit 1
}

output_redirect() {
	if [[ "$STDOUT" ]]; then
		cat - 1>&2
	else
		cat -
	fi
}

build() {
	declare mirror="$1" rel="$2" packages="${3:-alpine-base}"
	local repo="$mirror/$rel/main"
	local arch="$(uname -m)"

	# tmp
	local tmp="$(mktemp -d "${TMPDIR:-/var/tmp}/alpine-docker-XXXXXXXXXX")"
	local rootfs="$(mktemp -d "${TMPDIR:-/var/tmp}/alpine-docker-rootfs-XXXXXXXXXX")"
	# trap "rm -rf $tmp $rootfs" EXIT TERM INT

	# conf
	{
		echo "$repo"
		[[ "$REPO_EXTRA" ]] && {
			[[ "$rel" == "edge" ]] || echo "@edge $mirror/edge/main"
			echo "@testing $mirror/edge/testing"
		}
	} > /etc/apk/repositories

	# mkbase
	{
		apk --update-cache fetch --recursive --output "$tmp" ${packages//,/ }
		[[ "$ADD_BASELAYOUT" ]] && \
			apk fetch --stdout alpine-base | tar -xvz -C "$rootfs" etc
		[[ "$TIMEZONE" ]] && install -Dm 644 \
			"/usr/share/zoneinfo/$TIMEZONE" "$rootfs/etc/localtime"
		apk --root "$rootfs" --allow-untrusted add --initdb "$tmp"/*.apk
		install -Dm 644 /etc/apk/repositories "$rootfs/etc/apk/repositories"
	} | output_redirect

	[[ "$ADD_APK_SCRIPT" ]] && cp /apk-install "$rootfs/usr/sbin/apk-install"

	# save
	tar -z -f rootfs.tar.gz --numeric-owner -C "$rootfs" -c .
	[[ "$STDOUT" ]] && cat rootfs.tar.gz

	return 0
}

main() {
	while getopts "hr:m:t:secp:b" opt; do
		case $opt in
			r) REL="$OPTARG";;
			m) MIRROR="$OPTARG";;
			s) STDOUT=1;;
			e) REPO_EXTRA=1;;
			t) TIMEZONE="$OPTARG";;
			c) ADD_APK_SCRIPT=1;;
			p) PACKAGES="$OPTARG";;
			b) ADD_BASELAYOUT=1;;
			*) usage;;
		esac
	done

	build "$MIRROR" "$REL" "$PACKAGES"
}

main "$@"
