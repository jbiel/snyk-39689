#!/usr/bin/env bash
set -euo pipefail

# Set some env variables
source /etc/os-release
export DEBIAN_FRONTEND=noninteractive


# Add unstable repo
cat <<- EOF > /etc/apt/sources.list.d/unstable.list
	deb http://httpredir.debian.org/debian unstable main
	deb-src http://httpredir.debian.org/debian unstable main
EOF


cat <<- EOF > /etc/apt/preferences
	Package: *
	Pin: release n=${VERSION_CODENAME}
	Pin-Priority: 700

	Package: *
	Pin: release n=unstable
	Pin-Priority: 600
EOF

# Update lists and all packages
apt-get update
apt-get -o Dpkg::Options::="--force-confnew" -y dist-upgrade


# Create work dir
CURL_BASE_DIR=$(mktemp -d)


# Install build prereq
apt-get install -y dpkg-dev devscripts


# Get curl deb package source
cd $CURL_BASE_DIR
apt-get source curl/unstable
CURL_SOURCE_DIR=$(ls -d $CURL_BASE_DIR/*/)


# Fixups for building on this version of Debian
## Change debhelper version
grep -RPl "debhelper-compat \(= \d\d\)" . | xargs sed -i "s/debhelper-compat (= .\+)/debhelper-compat (= $VERSION_ID)/g"

## Remove python-impacket dependency
sed -i "/python3-impacket.*,$/d" $CURL_SOURCE_DIR/debian/control
sed -i 's/, python3-impacket <!nocheck>,/,/' *.dsc


# Install build deps from dsc
mk-build-deps -t "apt-get -o Debug::pkgProblemResolver=yes --no-install-recommends -y" -i *.dsc


# Build packages (tests are skipped)
cd $CURL_SOURCE_DIR
DEB_BUILD_OPTIONS=nocheck dpkg-buildpackage -rfakeroot


# Install packages
cd $CURL_BASE_DIR

DPKG_ARCH=$(dpkg --print-architecture)
CURL_PKG_VERSION=$(grep "^Version:" *.dsc | awk -F ': ' '{print $2}')

dpkg -i curl_${CURL_PKG_VERSION}_${DPKG_ARCH}.deb libcurl4_${CURL_PKG_VERSION}_${DPKG_ARCH}.deb


# Hold packages so they don't get upgraded
apt-mark hold curl libcurl4


# Output version and run a test
echo "===CURL VERSION==="
curl --version
echo "===CURL TEST==="
curl https://1.1.1.1 > /dev/null


# Remove all build deps
apt-get remove -y curl-build-deps dpkg-dev devscripts
apt-get autoremove -y
apt-get clean


# cleanup work dir
cd
rm -rf $CURL_BASE_DIR
