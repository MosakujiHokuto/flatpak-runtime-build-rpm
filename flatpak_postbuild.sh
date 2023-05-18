#!/bin/sh

msg() {
    echo "POSTRUN ==> $@"
}

msg "Flatpak post build hook invoked"

export SOURCEDIR=/usr/src/packages/SOURCES
source $SOURCEDIR/buildinfo

export FLATPAK_NAME=$name
export FLATPAK_ARCH=$arch
export FLATPAK_VERSION=$version

msg "Build Info:"
msg "  Name:    $FLATPAK_NAME"
msg "  Arch:    $FLATPAK_ARCH"
msg "  Version: $FLATPAK_VERSION"

cd `mktemp -d`

msg "Entering fakeroot environment..."
fakeroot /usr/lib/build/runtime_build_rpm/postbuild_fakeroot.sh
msg "Leaving fakeroot environment..."
mkdir -p /usr/src/packages/OTHER
if [ -f $FLATPAK_NAME.flatpak ]; then
    msg "Publishing output file..."
    mv $FLATPAK_NAME.flatpak /usr/src/packages/OTHER/
fi
