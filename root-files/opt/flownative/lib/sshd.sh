#!/bin/bash
# shellcheck disable=SC1090
# shellcheck disable=SC2046

# =======================================================================================
# LIBRARY: SSHD
# =======================================================================================

# This library contains functions for providing SSH access to this container

# Load helper lib

. "${FLOWNATIVE_LIB_PATH}/log.sh"
. "${FLOWNATIVE_LIB_PATH}/process.sh"

# ---------------------------------------------------------------------------------------
# sshd_env() - Load global environment variables for configuring SSHD
#
# @global SSHD_* The SSHD_ environment variables
# @return "export" statements which can be passed to eval()
#
sshd_env() {
    cat <<"EOF"
export SSHD_BASE_PATH="${SSHD_BASE_PATH}"
export SSHD_HOST_KEYS_PATH="${SSHD_HOST_KEYS_PATH:-${SSHD_BASE_PATH}/etc}"
export SSHD_ENABLE=${SSHD_ENABLE:-false}
export SSHD_AUTHORIZED_KEYS_SERVICE_ENDPOINT="${SSHD_AUTHORIZED_KEYS_SERVICE_ENDPOINT:-http://beach-controlpanel.beach-system.svc.cluster.local/api/v1}"
EOF
}

# ---------------------------------------------------------------------------------------
# sshd_generate_host_keys() - Generate host keys, if none exist
#
# @global SSHD_* The SSHD_ environment variables
# @return void
#
sshd_generate_host_keys() {
    if [ ! -e "${SSHD_HOST_KEYS_PATH}/ssh_host_rsa_key" ]; then
        info "SSHD: Generating new host keys ..."

        mkdir -p "${SSHD_HOST_KEYS_PATH}"

        ssh-keygen -f "${SSHD_HOST_KEYS_PATH}/ssh_host_rsa_key" -N '' -t rsa 2>&1 1>/dev/null | (sed 's/^/SSHD: /' | output)
        ssh-keygen -f "${SSHD_HOST_KEYS_PATH}/ssh_host_dsa_key" -N '' -t dsa 2>&1 1>/dev/null | (sed 's/^/SSHD: /' | output)
        ssh-keygen -f "${SSHD_HOST_KEYS_PATH}/ssh_host_ecdsa_key" -N '' -t ecdsa 2>&1 1>/dev/null | (sed 's/^/SSHD: /' | output)
        ssh-keygen -f "${SSHD_HOST_KEYS_PATH}/ssh_host_ed25519_key" -N '' -t ed25519 2>&1 1>/dev/null | (sed 's/^/SSHD: /' | output)

        if [ "${SSHD_HOST_KEYS_PATH}" != "${SSHD_BASE_PATH}/etc" ]; then
            rm -f "${SSHD_HOST_KEYS_PATH}/ssh_host_dsa_key.pub"
            rm -f "${SSHD_HOST_KEYS_PATH}/ssh_host_ecdsa_key.pub"
            rm -f "${SSHD_HOST_KEYS_PATH}/ssh_host_ed25519_key.pub"
            rm -f "${SSHD_HOST_KEYS_PATH}/ssh_host_rsa_key.pub"
        fi
    elif [ -f "${SSHD_HOST_KEYS_PATH}/ssh_host_rsa_key" ] && [ "${SSHD_HOST_KEYS_PATH}" != "${SSHD_BASE_PATH}/etc" ]; then
        info "SSHD: Copying host keys to ${SSHD_BASE_PATH}/etc ..."

        cp -f "${SSHD_HOST_KEYS_PATH}/ssh_host_rsa_key" "${SSHD_BASE_PATH}/etc/ssh_host_rsa_key"
        cp -f "${SSHD_HOST_KEYS_PATH}/ssh_host_dsa_key" "${SSHD_BASE_PATH}/etc/ssh_host_dsa_key"
        cp -f "${SSHD_HOST_KEYS_PATH}/ssh_host_ecdsa_key" "${SSHD_BASE_PATH}/etc/ssh_host_ecdsa_key"
        cp -f "${SSHD_HOST_KEYS_PATH}/ssh_host_ed25519_key" "${SSHD_BASE_PATH}/etc/ssh_host_ed25519_key"
    fi

    chmod 600 "${SSHD_BASE_PATH}"/etc/*_key
    chmod 644 "${SSHD_BASE_PATH}"/etc/*_key.pub

    info "SSHD: Found $(find "${SSHD_BASE_PATH}"/etc/*_key | wc -l) host keys"
}

# ---------------------------------------------------------------------------------------
# sshd_get_pid() - Return the SSHD process id
#
# @global SSHD_* The SSHD_ evnironment variables
# @return Returns the SSHD process id, if it is running, otherwise 0
#
sshd_get_pid() {
    local pid
    pid=$(process_get_pid_from_file "${SSHD_BASE_PATH}/tmp/sshd.pid")

    if [[ -n "${pid}" ]]; then
        echo "${pid}"
    else
        false
    fi
}

# ---------------------------------------------------------------------------------------
# sshd_has_pid() - Checks if a PID file exists
#
# @global SSHD_* The SSHD_ environment variables
# @return Returns false if no PID file exists
#
sshd_has_pid() {
    if [[ ! -f "${SSHD_BASE_PATH}/tmp/sshd.pid" ]]; then
        false
    fi
}


# ---------------------------------------------------------------------------------------
# sshd_start() - Start SSHD
#
# @global SSHD_* The SSHD_ evnironment variables
# @return void
#
sshd_start() {
    local pid

    info "SSHD: Starting ..."

    supervisorctl start sshd 1>$(debug_device)
    pid=$(supervisorctl pid sshd)

    info "SSHD: Using ${SSHD_AUTHORIZED_KEYS_SERVICE_ENDPOINT} as authorized keys service endpoint"
    info "SSHD: Running as process #${pid} on host $(hostname)"
}

# ---------------------------------------------------------------------------------------
# sshd_stop() - Stop the SSHD process based on the current PID
#
# @global SSHD_* The SSHD_ evnironment variables
# @return void
#
sshd_stop() {
    local pid
    pid=$(sshd_get_pid)

    is_process_running "${pid}" || (info "SSHD: Could not stop, because the process was not running (detected pid: ${pid})" && return)
    info "SSHD: Stopping ..."

    process_stop "${pid}"

    info "SSHD: Process stopped"
}

# ---------------------------------------------------------------------------------------
# sshd_initialize() - Set up configuration
#
# @global SSHD_* The SSHD_* environment variables
# @return void
#
sshd_initialize() {
    if [[ $(id --user) == 0 ]]; then
        error "SSHD: Container is running as root, but only unprivileged users are supported"
        exit 1
    fi;

    info "SSHD: Initializing configuration"
    sshd_generate_host_keys
    envsubst < "${SSHD_BASE_PATH}/etc/sshd_config.template" > "${SSHD_BASE_PATH}/etc/sshd_config"
}
