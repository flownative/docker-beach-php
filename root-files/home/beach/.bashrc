# If this shell was started by SSHD, the environment variables need to be set:
if [[ -z "${FLOWNATIVE_LIB_PATH}" ]]; then
    source /home/beach/.env
fi

# If not running interactively, skip the banner
if [[ -z "$PS1" ]]; then
    export BANNER_FLOWNATIVE_SKIP="yes"
fi

export PATH="$PATH":/usr/local/bin:/usr/bin:$HOME:${SUPERVISOR_BASE_PATH}/bin
export FLOW_ROOTPATH="${BEACH_APPLICATION_PATH}"

alias l='ls -laG'
umask 002

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

if [[ -n "${BEACH_INSTANCE_IDENTIFIER}" ]]; then
    if [[ -n "${BEACH_PROJECT_NAME}" ]]; then
        banner_generic "Flownative Beach" "${BEACH_PROJECT_NAME} / ${BEACH_INSTANCE_NAME}" "${BEACH_INSTANCE_IDENTIFIER}"
    else
        banner_generic "Flownative Beach" "${BEACH_INSTANCE_NAME}" "${BEACH_INSTANCE_IDENTIFIER}"
    fi
else
    banner_generic "Flownative Local Beach" "" "${BEACH_INSTANCE_NAME}"
fi

cd "${BEACH_APPLICATION_PATH}"
