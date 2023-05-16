#!/bin/sh

msg() {
    echo "POSTRUN ==> $@"
}


msg "Flatpak post build hook invoked"

source /usr/src/packages/SOURCES/buildinfo

export FLATPAK_NAME=$name
export FLATPAK_ARCH=$arch
export FLATPAK_VERSION=$version

msg "Build Info:"
msg "\tName:\t$FLATPAK_NAME"
msg "\tArch:\t$arch"
msg "\tVersion:\t$version"
