#!/bin/bash
. "${FLOWNATIVE_LIB_PATH}/log.sh"
. "${FLOWNATIVE_LIB_PATH}/os.sh"

set -e
set -u

# ---------------------------------------------------------------------------------------
# packages_install() - Install packages via apt-get and retry if installation fails
#
# @arg A list of packages
# @return exit code
#
packages_install() {
    local -r packages="${@:?missing package names}"
    export DEBIAN_FRONTEND=noninteractive

    cat >/etc/dpkg/dpkg.cfg.d/01_nodoc <<-EOM
# /etc/dpkg/dpkg.cfg.d/01_nodoc

# Don't install locales
path-exclude=/usr/share/locale/*

# Don't install manpages
path-exclude=/usr/share/man/*

# Don't install docs
path-exclude=/usr/share/doc/*
path-include=/usr/share/doc/*/copyright
EOM

    info "📦 Installing the following packages: ${packages}"
    with_backoff "packages_apt_get_install ${packages}" || (
        error "Failed installing packages"
        exit 1
    )
}

# ---------------------------------------------------------------------------------------
# packages_remove() - Remove packages via apt-get
#
# @arg A list of packages
# @return exit code
#
packages_remove() {
    local -r packages="${@:?missing package names}"
    export DEBIAN_FRONTEND=noninteractive

    info "📦 Removing the following packages: ${packages}"

    apt-get purge -y "$@" 1>"$(debug_device)"
    apt-get autoremove -y 1>"$(debug_device)"
}

# ---------------------------------------------------------------------------------------
# packages_apt_get_install() - Internal, runs apt-get update && apt-get install
#
# @arg A list of packages
# @return exit code
#
packages_apt_get_install() {
    apt-get update -qq 1>"$(debug_device)" &&
        apt-get install \
            -o Dpkg::Options::=--force-confold \
            -o Dpkg::Options::=--force-confdef \
            -y \
            --allow-downgrades \
            --allow-remove-essential \
            --allow-change-held-packages \
            --no-install-recommends \
            "$@" 1>"$(debug_device)"
}

# ---------------------------------------------------------------------------------------
# packages_remove_docs_and_caches() - Removes all manpages, docs and various caches
#
# @return void
#
packages_remove_docs_and_caches() {
    info "🧹 Removing cache files and documentation ..."
    rm -rf \
        /var/cache/apt/archives \
        /var/cache/debconf \
        /var/lib/apt/lists \
        /var/log/apt/* \
        /var/log/dpkg* \
        /usr/share/doc/* \
        /usr/share/man/* \
        /usr/share/locale/* \
        1>"$(debug_device)"
}
