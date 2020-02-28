#!/bin/bash
# shellcheck disable=SC1090

# =======================================================================================
# LIBRARY: PHP
# =======================================================================================

# Load helper lib

. "${FLOWNATIVE_LIB_PATH}/log.sh"
. "${FLOWNATIVE_LIB_PATH}/files.sh"
. "${FLOWNATIVE_LIB_PATH}/validation.sh"
. "${FLOWNATIVE_LIB_PATH}/os.sh"
. "${FLOWNATIVE_LIB_PATH}/process.sh"

# ---------------------------------------------------------------------------------------
# php_fpm_env() - Load global environment variables for configuring PHP
#
# @global PHP_* The PHP_ evnironment variables
# @return "export" statements which can be passed to eval()
#
php_fpm_env() {
    cat <<"EOF"
export PHP_BASE_PATH="${PHP_BASE_PATH}"
export PHP_CONF_PATH="${PHP_CONF_PATH:-${PHP_BASE_PATH}/etc}"
export PHP_TMP_PATH="${PHP_TMP_PATH:-${PHP_BASE_PATH}/tmp}"
export PHP_LOG_PATH="${PHP_LOG_PATH:-${PHP_BASE_PATH}/log}"

export PHP_FPM_USER="${PHP_FPM_USER:-1000}"
export PHP_FPM_GROUP="${PHP_FPM_GROUP:-1000}"
export PHP_FPM_PORT="${PHP_FPM_PORT:-9000}"
export PHP_FPM_MAX_CHILDREN="${PHP_FPM_MAX_CHILDREN:-5}"
EOF
}

# ---------------------------------------------------------------------------------------
# php_fpm_get_pid() - Return the php process id
#
# @global PHP_* The PHP_ evnironment variables
# @return Returns the PHP process id, if it is running, otherwise 0
#
php_fpm_get_pid() {
    local pid
    pid=$(process_get_pid_from_file "${PHP_TMP_PATH}/php-fpm.pid")

    if [[ -n "${pid}" ]]; then
        echo "${pid}"
    else
        false
    fi
}

# ---------------------------------------------------------------------------------------
# php_fpm_start() - Start PHP
#
# @global PHP_* The PHP_ evnironment variables
# @return void
#
php_fpm_start() {
    local pid

    trap 'php_fpm_stop' SIGINT SIGTERM

    info "PHP-FPM: Starting ..."
    "${PHP_BASE_PATH}/sbin/php-fpm" >/dev/null 2>/dev/null &
    pid="$!"
    echo "${pid}" > "${PHP_TMP_PATH}/php-fpm.pid"

    info "PHP-FPM: Running as process #${pid}"
}

# ---------------------------------------------------------------------------------------
# php_fpm_stop() - Stop the php process based on the current PID
#
# @global PHP_* The PHP_ evnironment variables
# @return void
#
php_fpm_stop() {
    local pid
    pid=$(php_fpm_get_pid)

    is_process_running "${pid}" || (info "PHP-FPM: Could not stop, because the process was not running (detected pid: ${pid})" && return);
    info "PHP-FPM: Stopping ..."

    process_stop "${pid}"

    info "PHP-FPM: Process stopped, good-bye ... 👋"
}

# ---------------------------------------------------------------------------------------
# php_fpm_conf_validate() - Validates configuration options passed as PHP_* env vars
#
# @global PHP_* The PHP_* environment variables
# @return void
#
#php_fpm_conf_validate() {
#    echo ""
#}

# ---------------------------------------------------------------------------------------
# php_fpm_initialize() - Initialize PHP configuration and check required files and dirs
#
# @global PHP_* The PHP_* environment variables
# @return void
#
php_fpm_initialize() {
    if [[ $(id --user) == 0 ]]; then
        error "PHP-FPM: Container is running as root, but only unprivileged users are supported"
        exit 1
    fi;

    info "PHP-FPM: Initializing configuration ..."
    envsubst < "${PHP_CONF_PATH}/php-fpm.conf.template" > "${PHP_CONF_PATH}/php-fpm.conf"
 }
