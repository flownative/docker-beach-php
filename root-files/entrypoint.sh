#!/bin/bash
# shellcheck disable=SC1090

set -o errexit
set -o nounset
set -o pipefail

# Load lib
. "${FLOWNATIVE_LIB_PATH}/syslog-ng.sh"
. "${FLOWNATIVE_LIB_PATH}/supervisor.sh"
. "${FLOWNATIVE_LIB_PATH}/banner.sh"
. "${FLOWNATIVE_LIB_PATH}/validation.sh"
. "${FLOWNATIVE_LIB_PATH}/php-fpm.sh"
. "${FLOWNATIVE_LIB_PATH}/metrics.sh"
. "${FLOWNATIVE_LIB_PATH}/beach-legacy.sh"
. "${FLOWNATIVE_LIB_PATH}/beach.sh"
. "${FLOWNATIVE_LIB_PATH}/sshd.sh"

eval "$(syslog_env)"
syslog_initialize
syslog_start

eval "$(supervisor_env)"
eval "$(beach_legacy_env)"
eval "$(beach_env)"
eval "$(php_fpm_env)"
eval "$(metrics_env)"
eval "$(sshd_env)"

banner_flownative "${BANNER_IMAGE_NAME}"

beach_initialize
beach_prepare_flow

php_fpm_initialize

supervisor_initialize
supervisor_start

trap 'supervisor_stop; syslog_stop' SIGINT SIGTERM SIGQUIT

beach_finalize_flow

if is_boolean_yes "$SSHD_ENABLE"; then
    sshd_initialize
    supervisorctl start sshd 2>&1 | (sed 's/^/Supervisor: /' | output)
fi

if is_boolean_yes "$METRICS_PHP_FPM_ENABLE"; then
    metrics_start
fi

if is_boolean_yes "$BEACH_CRON_ENABLE"; then
    info "Beach: Enabling Beach simple cron support"
    supervisorctl start beach-cron 2>&1 | (sed 's/^/Supervisor: /' | output)
fi

if [[ "$*" = *"run"* ]]; then
    supervisor_pid=$(supervisor_get_pid)

    sleep 1
    set +o errexit
    supervisorctl status 2>&1 | (sed 's/^/Supervisor: /' | output)
    set -o errexit
    info "Entrypoint: Start up complete"
    # We can't use "wait" because supervisord is not a direct child of this shell:
    while [ -e "/proc/${supervisor_pid}" ]; do sleep 1.1; done
    info "Good bye 👋"
else
    "$@"
fi
