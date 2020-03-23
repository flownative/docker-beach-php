#!/bin/bash
# shellcheck disable=SC1090

set -o errexit
set -o nounset
set -o pipefail

# Load lib
. "${FLOWNATIVE_LIB_PATH}/banner.sh"
. "${FLOWNATIVE_LIB_PATH}/validation.sh"
. "${FLOWNATIVE_LIB_PATH}/php-fpm.sh"
. "${FLOWNATIVE_LIB_PATH}/beach-legacy.sh"
. "${FLOWNATIVE_LIB_PATH}/beach.sh"
. "${FLOWNATIVE_LIB_PATH}/sshd.sh"

eval "$(beach_legacy_env)"
eval "$(beach_env)"
eval "$(php_fpm_env)"
eval "$(sshd_env)"

banner_flownative 'Beach PHP'

if is_boolean_yes "$BEACH_WAIT_FOR_SYNC"; then
    info "Beach: Waiting for sync to get ready ..."
    while [ ! -f "${BEACH_APPLICATION_PATH}/.sync.ready" ]; do sleep 1; done
fi

beach_initialize
beach_prepare

if [[ "$*" = *"run"* ]]; then
    php_fpm_initialize

    if is_boolean_yes "$SSHD_ENABLE"; then
        trap 'php_fpm_stop; sshd_stop' SIGINT SIGTERM
        php_fpm_start
        sshd_initialize
        sshd_start
    else
        trap 'php_fpm_stop' SIGINT SIGTERM
        php_fpm_start
    fi

    wait "$(php_fpm_get_pid)"
    # This line will not be reached, because a trap handles termination
else
    "$@"
fi
