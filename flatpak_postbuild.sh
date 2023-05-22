#!/bin/sh

msg() {
    echo "POSTRUN ==> $@"
}

prepare_to_ostree() {
    local src=/usr/src/packages/KIWI-tbz/build/image-root
    local dst=buildroot-prepare

    sudo rm -rf $dst
    sudo mkdir -p $dst/{var,dev,proc,run,sys,sysroot}

    sudo ln -s ../var/opt $dst/opt
    sudo ln -s ../var/srv $dst/srv
    sudo ln -s ../var/mnt $dst/mnt
    sudo ln -s ../var/roothome $dst/root
    sudo ln -s ../var/home $dst/home
    sudo ln -s ../run/media $dst/media
    sudo ln -s ../sysroot/ostree $dst/ostree
    sudo ln -s ../sysroot/tmp $dst/tmp

    sudo cp -r $src/usr $dst/usr
    sudo cp -r $src/etc $dst/etc
    sudo ln -s var/lib/rpm $dst/usr/share/rpm
    sudo cp -r $dst/usr/local $dst/var/usrlocal
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

    sudo rm -rf $tmpdir
}

set -e
set -u

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

cd `mktemp -d flatpak_build.XXXXXX`

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
sudo ostree --repo=repo commit -s 'initial build' \
       -b base/$FLATPAK_NAME/$FLATPAK_ARCH/$FLATPAK_VERSION \
       --tree=dir=$PWD/buildroot-prepare
sudo chown -R `whoami` repo

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

msg "Installing runtime into build environment..."
sudo mkdir /var/lib/flatpak/runtime
ls -R /var/lib/flatpak/
sudo flatpak repair --system -v --ostree-verbose
sudo flatpak remote-add --no-gpg-verify exportrepo exportrepo
sudo flatpak install --noninteractive --assumeyes exportrepo $FLATPAK_NAME

msg "Creating and publishing tarball..."
TARFILE=$FLATPAK_NAME-v$FLATPAK_VERSION.$FLATPAK_ARCH.tar.gz
sudo tar cvpaf $TARFILE -C /var/lib/flatpak/runtime \
     /var/lib/flatpak/runtime/$FLATPAK_NAME/$FLATPAK_ARCH/$FLATPAK_VERSION
mv $TARFILE /usr/src/packages/OTHER
