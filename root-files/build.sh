#!/bin/bash
# shellcheck disable=SC1090
# shellcheck disable=SC2086
# shellcheck disable=SC2046

# Load helper libraries

. "${FLOWNATIVE_LIB_PATH}/banner.sh"
. "${FLOWNATIVE_LIB_PATH}/log.sh"
. "${FLOWNATIVE_LIB_PATH}/packages.sh"

set -o errexit
set -o nounset
set -o pipefail

# ---------------------------------------------------------------------------------------
# build_create_directories() - Create directories and set access rights accordingly
#
# @global BEACH_APPLICATION_PATH
# @return void
#
build_create_directories() {
    mkdir -p "${BEACH_APPLICATION_PATH}/Data"
    chown -R 1000 "${BEACH_APPLICATION_PATH}"
}

# ---------------------------------------------------------------------------------------
# build_create_user() - Create the beach user and group
#
# @global BEACH_APPLICATION_PATH
# @return void
#
build_create_user() {
    info "🛠 Beach: Creating user and group beach (1000)"
    groupadd --gid 1000 beach
    useradd --home-dir /home/beach --shell /bin/bash --gid beach --uid 1000 beach 1>$(debug_device)

    chown beach:beach /home/beach ${SUPERVISOR_BASE_PATH}/etc/conf.d
    chmod 775 /home/beach ${SUPERVISOR_BASE_PATH}/etc/conf.d

    chmod 644 /home/beach/.profile /home/beach/.bashrc /home/beach/.env
    chown beach:beach /home/beach/.profile /home/beach/.bashrc /home/beach/.env
}

# ---------------------------------------------------------------------------------------
# build_tools() - Install tools to be used by Beach users via SSH
#
# @return void
#
build_tools() {
    packages_install netcat-traditional vim less curl locales locales-all mariadb-client ghostscript gpg gpg-agent unzip nano htop bat hostname ncurses-bin
}

# ---------------------------------------------------------------------------------------
# build_image_optimizers() - Install tools to be used by Beach users via SSH and/or PHP
#
# @return void
#
build_image_optimizers() {
    packages_install optipng pngcrush pngquant gifsicle libjpeg-turbo-progs jpegoptim webp
}

# ---------------------------------------------------------------------------------------
# build_sshd() - Install and configure the SSH daemon
#
# @global SSHD_BASE_PATH
# @return void
#
build_sshd() {
    # openssh-server needs a sysusers implementation; without the standalone
    # package, apt would pick the full systemd suite to satisfy that dependency
    # (and with it mount and its setuid binaries):
    packages_install openssh-server systemd-standalone-sysusers curl

    # Clean up a few directories / files we don't need:
    rm -rf \
        /etc/init.d \
        /etc/rc2.d/S01ssh \
        /etc/rc2.d/S01ssh \
        /lib/systemd/system/rescue-ssh.target \
        /lib/systemd/system/ssh*

    # Create directories
    mkdir -p \
        "${SSHD_BASE_PATH}/etc" \
        "${SSHD_BASE_PATH}/sbin" \
        "${SSHD_BASE_PATH}/tmp"

    # Move SSHD files to correct location:
    mv /usr/sbin/sshd ${SSHD_BASE_PATH}/sbin/

    chown -R beach \
        "${SSHD_BASE_PATH}/etc" \
        "${SSHD_BASE_PATH}/tmp"
}

# ---------------------------------------------------------------------------------------
# build_blackfire() - Install and configure the Blackfire probe and Blackfire agent
#
# @global PHP_BASE_PATH
# @return void
#
build_blackfire() {
    ${PHP_BASE_PATH}/bin/blackfire php:install

    # Remove the automatically created inclusion, because we want to enable
    # Blackfire dynamically based on BEACH_ADDON_BLACKFIRE_ENABLE
    rm -f ${PHP_BASE_PATH}/etc/conf.d/*blackfire.ini

    mkdir -p /etc/blackfire
}

# ---------------------------------------------------------------------------------------
# build_strip_setuid() - Remove setuid/setgid bits from all binaries
#
# Nothing running in this container may escalate privileges. The base image
# already stripped its own binaries; the packages installed here bring new ones
# (ssh-agent and ssh-keysign, at least). The statoverride makes sure that
# package upgrades do not restore the bits.
#
# @return void
#
build_strip_setuid() {
    for f in $(find / -xdev -perm /6000 -type f); do
        dpkg-statoverride --update --add root root 0755 "$f" 1>$(debug_device)
    done
}

# ---------------------------------------------------------------------------------------
# build_clean() - Clean up obsolete building artifacts and temporary files
#
# @global PHP_BASE_PATH
# @return void
#
build_clean() {
    rm -rf \
        /var/cache/* \
        /var/log/*
}

# ---------------------------------------------------------------------------------------
# Main routine

case $1 in
init)
    banner_flownative "${BANNER_IMAGE_NAME}"
    build_create_directories
    build_create_user
    ;;
build)
    build_tools
    build_image_optimizers
    build_sshd
    build_blackfire
    build_strip_setuid
    ;;
clean)
    packages_remove_docs_and_caches 1>$(debug_device)
    build_clean
    ;;
esac
