#!/bin/sh

msg() {
    echo "POSTRUN ==> $@"
}


msg "Flatpak post build hook invoked"

ls -R /usr/src/packages/SOURCES
