#!/bin/bash
# shellcheck disable=SC1090

set -o errexit
set -o nounset
set -o pipefail

# Load lib
. "${FLOWNATIVE_LIB_PATH}/banner.sh"
. "${FLOWNATIVE_LIB_PATH}/validation.sh"
. "${FLOWNATIVE_LIB_PATH}/supervisor.sh"
. "${FLOWNATIVE_LIB_PATH}/php-fpm.sh"
. "${FLOWNATIVE_LIB_PATH}/beach-legacy.sh"
. "${FLOWNATIVE_LIB_PATH}/beach.sh"
. "${FLOWNATIVE_LIB_PATH}/sshd.sh"

eval "$(supervisor_env)"
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
beach_prepare_flow

php_fpm_initialize

supervisor_initialize
supervisor_start

trap 'supervisor_stop' SIGINT SIGTERM

if is_boolean_yes "$SSHD_ENABLE"; then
    sshd_initialize
    supervisorctl start sshd
fi

if [[ "$*" = *"run"* ]]; then
    supervisor_pid=$(supervisor_get_pid)

    supervisorctl status
    info "Entrypoint: Start up complete"
    # We can't use "wait" because supervisord is not a direct child of this shell:
    while [ -e "/proc/${supervisor_pid}" ]; do sleep 1.1; done
    info "Good bye 👋"
else
    "$@"
fi
