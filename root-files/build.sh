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
    packages_install netcat-traditional vim less curl locales locales-all mariadb-client ghostscript gpg
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
    packages_install openssh-server curl

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
    ;;
clean)
    packages_remove_docs_and_caches 1>$(debug_device)
    build_clean
    ;;
esac
