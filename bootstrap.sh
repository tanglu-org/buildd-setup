#!/bin/bash

set -x # Verbose

apt-get update
apt-get upgrade -y --force-yes
apt-get install -y --force-yes --no-install-recommends \
    sudo devscripts dpkg-dev debootstrap git vim \
    schroot sbuild aptitude lintian dput-ng python-dput python-debian \
    python-requests python-yaml python-schroot python-sqlalchemy \
    python-virtualenv virtualenv python-pip

adduser --system --shell /bin/bash --home=/srv/buildd --ingroup sbuild --disabled-password buildd

export STABLE=bartholomea
export DEVEL=chromodoris

mkdir -p /srv/buildd/chroots

export MIRROR="http://archive.tanglu.org/tanglu"

for ARCH in i386 amd64; do

    export $ARCH

    sbuild-createchroot --arch=${ARCH} \
        --components="main,contrib,non-free" \
        --include=aptitude \
        --keep-sbuild-chroot-dir \
        --make-sbuild-tarball=/srv/buildd/chroots/${STABLE}-${ARCH}.tar.gz \
        ${STABLE} \
        /srv/buildd/chroots/${STABLE}-${ARCH} \
        $MIRROR

    sbuild-createchroot --arch=${ARCH} \
        --components="main,contrib,non-free" \
        --include=aptitude \
        --keep-sbuild-chroot-dir \
        --make-sbuild-tarball=/srv/buildd/chroots/${DEVEL}-${ARCH}.tar.gz \
        ${DEVEL} \
        /srv/buildd/chroots/${DEVEL}-${ARCH} \
        $MIRROR

    cp -a /srv/buildd/chroots/${DEVEL}-${ARCH} /srv/buildd/chroots/staging-${ARCH}

    for SUITE in ${STABLE} ${DEVEL} staging; do
        rm /srv/buildd/chroots/${SUITE}-${ARCH}/dev/ptmx
        ln -s pts/ptmx /srv/buildd/chroots/${SUITE}-${ARCH}/dev/ptmx
        echo force-unsafe-io >/srv/buildd/chroots/${SUITE}-${ARCH}/etc/dpkg/dpkg.cfg.d/90sbuild
    done

    echo "deb ${MIRROR} ${STABLE}-updates main contrib non-free"     >>/srv/buildd/chroots/${STABLE}-${ARCH}/etc/apt/sources.list
    echo "deb-src ${MIRROR} ${STABLE}-updates main contrib non-free" >>/srv/buildd/chroots/${STABLE}-${ARCH}/etc/apt/sources.list
    echo "deb ${MIRROR} staging main contrib non-free"     >>/srv/buildd/chroots/staging-${ARCH}/etc/apt/sources.list
    echo "deb-src ${MIRROR} staging main contrib non-free" >>/srv/buildd/chroots/staging-${ARCH}/etc/apt/sources.list

    mv /etc/schroot/chroot.d/${STABLE}-${ARCH}-sbuild-* /etc/schroot/chroot.d/${STABLE}-${ARCH}
    cp /etc/schroot/chroot.d/${STABLE}-${ARCH} /etc/schroot/chroot.d/${STABLE}-updates-${ARCH}
    mv /etc/schroot/chroot.d/${DEVEL}-${ARCH}-sbuild-* /etc/schroot/chroot.d/${DEVEL}-${ARCH}
    cp /etc/schroot/chroot.d/${DEVEL}-${ARCH} /etc/schroot/chroot.d/staging-${ARCH}

    sed -e "s,${STABLE}-${ARCH}-sbuild,${STABLE}-${ARCH},g" -i /etc/schroot/chroot.d/${STABLE}-${ARCH}
    sed -e "s,${STABLE}-${ARCH}-sbuild,${STABLE}-updates-${ARCH},g" -i /etc/schroot/chroot.d/${STABLE}-updates-${ARCH}
    sed -e "s,${DEVEL}-${ARCH}-sbuild,${DEVEL}-${ARCH},g" -i /etc/schroot/chroot.d/${DEVEL}-${ARCH}
    sed -e "s,${DEVEL}-${ARCH}-sbuild,staging-${ARCH},g" -e "s,${DEVEL},staging,g" -i /etc/schroot/chroot.d/staging-${ARCH}

    for SUITE in ${STABLE} ${DEVEL} staging; do
        tar caf /srv/buildd/chroots/${SUITE}-${ARCH}.tar.gz -C /srv/buildd/chroots/${SUITE}-${ARCH} . && rm -r /srv/buildd/chroots/${SUITE}-${ARCH}
    done

    sbuild-update --update --upgrade --clean ${STABLE}-${ARCH} ${DEVEL}-${ARCH} staging-${ARCH}

done

chown buildd: /srv/buildd/

# import builder keys if they exist (when re-provisioning)
if [ -e /vagrant/keys ]; then

    hostname=$(hostname)

    cp /vagrant/keys/${hostname}.pgp /srv/buildd/
    cp /vagrant/keys/${hostname}.key /srv/buildd/
    cp /vagrant/keys/${hostname}.crt /srv/buildd/
    chown buildd: /srv/buildd/*pgp /srv/buildd/*.key /srv/buildd/*.crt
    chmod go-rwx /srv/buildd/*.key

    cp /vagrant/keys/sbuild-key.pub /var/lib/sbuild/apt-keys/
    cp /vagrant/keys/sbuild-key.sec /var/lib/sbuild/apt-keys/
    chown buildd:sbuild -R /var/lib/sbuild/apt-keys/*
    chmod go-rwx /var/lib/sbuild/apt-keys/sbuild-key.sec

    sudo -u buildd gpg --allow-secret-key-import --import /vagrant/keys/${hostname}.sec

fi

cd /srv/buildd/

git clone git://gitorious.org/tanglu/debile.git debile-git
cp debile-git/contrib/tanglu/tanglu-buildd.crt .

# debile setup
cd debile-git
virtualenv --system-site-packages ENV
. ENV/bin/activate
pip install -r requirements-slave.txt
make develop

# debile configuration
mkdir -p /etc/debile/
cp /vagrant/debile/slave.yaml /etc/debile/
fingerprint=$(sudo -u buildd gpg --fingerprint $hostname@buildd.tanglu.org | grep fingerprint | cut -f 2 -d = | sed 's/\s*//g')
sed -e "s/ELEMENT/$hostname/g" \
    -e "s/GPGKEY_FINGERPRINT/$fingerprint/g" \
    -e "s/STABLE/$STABLE/g" \
    -i /etc/debile/slave.yaml

cp /vagrant/debile/tanglu_meta.json /etc/dput.d/metas/tanglu.json
cp /vagrant/debile/tanglu_profile.json /etc/dput.d/profiles/tanglu.json

cp /vagrant/debile/sbuild.conf /etc/sbuild/sbuild.conf

cp debian/debile-slave.init /etc/init.d/debile-slave
sed -e "s#^BASE#\. /srv/buildd/debile-git/ENV/bin/activate\nBASE#" \
    -e 's#^DEBILE=.*#DEBILE=/srv/buildd/debile-git/ENV/bin/$BASE#' \
    -e 's#^DEBILE_USER=.*#DEBILE_USER=buildd#' \
    -i /etc/init.d/debile-slave
update-rc.d debile-slave defaults
