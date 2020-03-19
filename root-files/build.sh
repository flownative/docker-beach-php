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
# build_sshd() - Install and configure the SSH daemon
#
# @global SSHD_BASE_PATH
# @return void
#
build_sshd() {
    packages_install openssh-server curl

    # Clean up a few directories / files we don't need:
    rm -rf \
        /etc/ufw \
        /etc/init.d \
        /etc/rc2.d/S01ssh \
        /etc/rc2.d/S01ssh \
        /lib/systemd/system/rescue-ssh.target \
        /lib/systemd/system/ssh*

    # Create directories
    mkdir -p \
        "${SSHD_BASE_PATH}/etc" \
        "${SSHD_BASE_PATH}/sbin" \
        "${SSHD_BASE_PATH}/tmp" \

    # Move SSHD files to correct location:
    mv /usr/sbin/sshd ${SSHD_BASE_PATH}/sbin/

    chown -R 1000 \
        "${SSHD_BASE_PATH}/etc" \
        "${SSHD_BASE_PATH}/tmp"

    info "🛠 SSHD: Creating user beach (1000)"
    useradd --home-dir /application --no-create-home --no-user-group --shell /bin/bash --uid 1000 beach 1>$(debug_device)
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
    banner_flownative 'Beach PHP'
    build_create_directories
    ;;
build)
    build_sshd
    ;;
clean)
    packages_remove_docs_and_caches 1>$(debug_device)
    build_clean
    ;;
esac
