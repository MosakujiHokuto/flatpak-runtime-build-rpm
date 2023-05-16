#!/bin/sh

msg() {
    echo "POSTRUN ==> $@"
}


msg "Flatpak post build hook invoked"

ls -r /usr/src/packages
