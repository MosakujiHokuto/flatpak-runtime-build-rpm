#!/bin/sh

set -e
set -u

msg() {
    echo "POSTRUN FAKEROOT ==> $@"
}

prepare_to_ostree() {
    local src=/usr/src/packages/KIWI-tbz/build/image-root
    local dst=buildroot-prepare

    rm -rf $dst
    mkdir -p $dst/{var,dev,proc,run,sys,sysroot}

    ln -s ../var/opt $dst/opt
    ln -s ../var/srv $dst/srv
    ln -s ../var/mnt $dst/mnt
    ln -s ../var/roothome $dst/root
    ln -s ../var/home $dst/home
    ln -s ../run/media $dst/media
    ln -s ../sysroot/ostree $dst/ostree
    ln -s ../sysroot/tmp $dst/tmp

    mv $src/usr $dst/usr
    mv $src/etc $dst/etc
    ln -s var/lib/rpm $dst/usr/share/rpm
    cp -r $dst/usr/local $dst/var/usrlocal
}

commit_subtree() {
    local src=$1
    shift
    local dst=$1
    shift
    local metadata=$1
    shift

    local tmpdir=`mktemp -d .commit-XXXXXX`

    cp $metadata $tmpdir/metadata
    while (( "$#" )); do
	mkdir -p `dirname $tmpdir/$2`
	ostree checkout --repo=repo --subpath=$1 -U $src $tmpdir/42
	shift 2;
    done

    cat $metadata | xargs -0 -I XXX ostree commit \
			  --repo=repo --no-xattrs --owner-uid=0 --owner-gid=0 \
			  --link-checkout-speedup -s "Commit" --branch $dst \
			  $tmpdir --add-metadata-string xa.metadata=XXX

    rm -rf $tmpdir
}

cd `mktemp -d`

msg "Generating metadata..."
cat >>metadata <<EOF
[Runtime]
name=$FLATPAK_NAME/$FLATPAK_ARCH/$FLATPAK_VERSION
runtime=$FLATPAK_NAME/$FLATPAK_ARCH/$FLATPAK_VERSION
sdk=$FLATPAK_NAME/$FLATPAK_ARCH/$FLATPAK_VERSION

EOF
if [[ -f $SOURCEDIR/metadata.in ]]; then
    cat $SOURCEDIR/metadata.in >>metadata
fi

msg "Initializing ostree repositories..."
ostree init --repo=repo --mode=bare-user
ostree init --repo=exportrepo --mode=archive-z2
msg "Preparing to ostree..."
prepare_to_ostree
msg "Commiting initial build..."
ostree --repo=repo commit -s 'initial build' \
       -b base/$FLATPAK_NAME/$FLATPAK_ARCH/$FLATPAK_VERSION \
       --tree=dir=$PWD/buildroot-prepare
chown -R `whoami` repo
msg "Commiting subtree..."
commit_subtree \
    base/$FLATPAK_NAME/$FLATPAK_ARCH/$FLATPAK_VERSION \
    runtime/$FLATPAK_NAME/$FLATPAK_ARCH/$FLATPAK_VERSION \
    metadata \
    /usr files
msg "Pulling into export repo..."
ostree pull-local --repo=exportrepo repo\
       runtime/$FLATPAK_NAME/$FLATPAK_ARCH/$FLATPAK_VERSION
flatpak build-update-repo exportrepo
msg "Building and exporting bundle..."
flatpak build-bundle --runtime exportrepo platform.flatpak \
	$FLATPAK_NAME $FLATPAK_VERSION
