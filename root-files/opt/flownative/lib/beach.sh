#!/bin/bash
# shellcheck disable=SC1090

# =======================================================================================
# LIBRARY: BEACH
# =======================================================================================

# This library contains functions for configuring Flow / Neos and Beach related features.

# Load helper lib

. "${FLOWNATIVE_LIB_PATH}/log.sh"
. "${FLOWNATIVE_LIB_PATH}/validation.sh"

# ---------------------------------------------------------------------------------------
# beach_env() - Load global environment variables for configuring PHP
#
# @global BEACH_* The BEACH_ evnironment variables
# @return "export" statements which can be passed to eval()
#
beach_env() {
    cat <<"EOF"
export BEACH_APPLICATION_PATH=${BEACH_APPLICATION_PATH:-/application}
export BEACH_APPLICATION_PATH=${BEACH_APPLICATION_PATH%/}
export BEACH_WAIT_FOR_SYNC=${BEACH_WAIT_FOR_SYNC:-false}
export BEACH_APPLICATION_USER_SERVICE_ENABLE=${BEACH_APPLICATION_USER_SERVICE_ENABLE:-false}
export BEACH_APPLICATION_USER_SERVICE_USERNAME=${BEACH_APPLICATION_USER_SERVICE_USERNAME:-beach}
export BEACH_APPLICATION_STARTUP_SCRIPT_USERNAME=${BEACH_APPLICATION_STARTUP_SCRIPT_USERNAME:-beach}

export BEACH_INSTANCE_IDENTIFIER=${BEACH_INSTANCE_IDENTIFIER:-}
export BEACH_INSTANCE_NAME=${BEACH_INSTANCE_NAME:-}

export BEACH_FLOW_BASE_CONTEXT=${BEACH_FLOW_BASE_CONTEXT:-Production}
export BEACH_FLOW_SUB_CONTEXT=${BEACH_FLOW_SUB_CONTEXT:-}
if [ -z ${BEACH_FLOW_SUB_CONTEXT} ]; then
    export BEACH_FLOW_CONTEXT=${BEACH_FLOW_BASE_CONTEXT}/Beach/Instance
else
    export BEACH_FLOW_CONTEXT=${BEACH_FLOW_BASE_CONTEXT}/Beach/${BEACH_FLOW_SUB_CONTEXT}
fi
export FLOW_CONTEXT=${BEACH_FLOW_CONTEXT}

export BEACH_DATABASE_HOST=${BEACH_DATABASE_HOST:-}
export BEACH_DATABASE_SOCKET=${BEACH_DATABASE_SOCKET:-}
export BEACH_DATABASE_PORT=${BEACH_DATABASE_PORT:-3306}
export BEACH_DATABASE_NAME=${BEACH_DATABASE_NAME:-}
export BEACH_DATABASE_USERNAME=${BEACH_DATABASE_USERNAME:-}
export BEACH_DATABASE_PASSWORD=${BEACH_DATABASE_PASSWORD:-}

export BEACH_ENVIRONMENT_VARIABLES_WHITELIST=${BEACH_ENVIRONMENT_VARIABLES_WHITELIST:-}

EOF
}

# ---------------------------------------------------------------------------------------
# beach_write_env() - Writes environment variables into ~/.env for SSH users
#
# @global BEACH_* The BEACH_ evnironment variables
# @return void
#
beach_write_env() {
    local systemVariableNames
    local allowedVariableNames

    if [ -z "${BEACH_ENVIRONMENT_VARIABLES_WHITELIST}" ]; then
        info "Beach: No whitelist defined for environment variables, exporting all variables to user profile ..."
        env >> /home/beach/.env
        return
    fi

    whitelistedVariableNames=$(base64 -d <<<"${BEACH_ENVIRONMENT_VARIABLES_WHITELIST}")
    systemVariableNames=(
        BEACH_INSTANCE_NAME
        BEACH_INSTANCE_IDENTIFIER
        BEACH_INSTANCE_IMAGE_NAME
        FLOW_CONTEXT
        FLOWNATIVE_LIB_PATH
        PATH
        PHP_BASE_PATH
        PHP_CONF_PATH
        PHP_DATE_TIMEZONE
        PHP_FPM_GROUP
        PHP_FPM_MAX_CHILDREN
        PHP_FPM_PORT
        PHP_FPM_USER
        PHP_LOG_PATH
        PHP_MEMORY_LIMIT
        PHP_TMP_PATH
        PHP_VERSION
        SSHD_AUTHORIZED_KEYS_SERVICE_ENDPOINT
        SSHD_BASE_PATH
        SSHD_ENABLE
        SSHD_HOST_KEYS_PATH
        SUPERVISOR_BASE_PATH
    )
    allowedVariableNames=("${whitelistedVariableNames[@]}" "${systemVariableNames[@]}")

    info "Beach: Exporting ${#allowedVariableNames[@]} variables to user profile according to the specified whitelist ..."

    # shellcheck disable=SC2068
    for variableName in ${allowedVariableNames[@]}; do
        echo "export ${variableName}='${!variableName//\'/\'\\\'\'}'" >> /home/beach/.env
    done
}

# ---------------------------------------------------------------------------------------
# beach_setup_user_profile() - Run doctrine:migrate
#
# @global BEACH_* The BEACH_* environment variables
# @return void
#
beach_setup_user_profile() {
    info "Beach: Setting up user profile for user beach ..."
    cat >/home/beach/.my.cnf <<-EOM
[client]
port                  = 3306
default-character-set = utf8
host                  = ${BEACH_DATABASE_HOST}
user                  = ${BEACH_DATABASE_USERNAME}
password              = ${BEACH_DATABASE_PASSWORD}
database              = ${BEACH_DATABASE_NAME}
EOM

    chown beach:beach /home/beach/.my.cnf
}

# ---------------------------------------------------------------------------------------
# beach_run_doctrine_migrate() - Run doctrine:migrate
#
# @global BEACH_* The BEACH_* environment variables
# @return void
#
beach_run_doctrine_migrate() {
    if [ -n "${BEACH_DATABASE_HOST}" ] || [ -n "${BEACH_DATABASE_SOCKET}" ]; then
        set +e
        info "Beach: Running doctrine:migrate on host ${BEACH_DATABASE_HOST}:${BEACH_DATABASE_PORT} for database '${BEACH_DATABASE_NAME}' as database user '${BEACH_DATABASE_USERNAME}'"
        "${BEACH_APPLICATION_PATH}/flow" doctrine:migrate 2>&1 | (sed 's/^/Beach: (flow) /' | output)
    else
        info "Beach: Skipping doctrine:migrate, because no database credentials are set"
    fi
}

# ---------------------------------------------------------------------------------------
# beach_run_resource_publish() - Run resource:publish
#
# @global BEACH_* The BEACH_* environment variables
# @return void
#
beach_run_resource_publish() {
    info "Beach: Running resource:publish --collection static"
    "${BEACH_APPLICATION_PATH}/flow" resource:publish --collection static 2>&1 | (sed 's/^/Beach: (flow) /' | output)
}

# ---------------------------------------------------------------------------------------
# beach_run_cache_warmup() - Run cache:warmup
#
# @global BEACH_* The BEACH_* environment variables
# @return void
#
beach_run_cache_warmup() {
    info "Beach: Warming up caches"
    "${BEACH_APPLICATION_PATH}/flow" cache:warmup 2>&1 | (sed 's/^/Beach: (flow) /' | output)
}

# ---------------------------------------------------------------------------------------
# beach_run_custom_startup() - Invoke a custom startup script, if one exists
#
# @global BEACH_* The BEACH_* environment variables
# @return void
#
beach_run_custom_startup() {
    if [ ! -f "${BEACH_APPLICATION_PATH}/beach-startup.sh" ]; then
        info "Beach: No custom startup script found"
        return
    fi

    info "Beach: Running custom startup script ..."
    chmod +x "${BEACH_APPLICATION_PATH}/beach-startup.sh"
    "${BEACH_APPLICATION_PATH}/beach-startup.sh" 2>&1 | (sed 's/^/Beach: (flow) /' | output)
}

# ---------------------------------------------------------------------------------------
# beach_enable_user_services() - Set up user services for Supervisor
#
# @global BEACH_*
# @global SUPERVISOR_BASE_PATH
# @return void
#
beach_enable_user_services() {
    if is_boolean_no "$BEACH_APPLICATION_USER_SERVICE_ENABLE"; then
        info "Beach: User-defined services are disabled"
        return
    fi

    serviceNumber=1
    servicePathsAndFilenames=$(find "${BEACH_APPLICATION_PATH}" -maxdepth 1 -name "beach-service*.sh")
    for servicePathAndFilename in ${servicePathsAndFilenames}
    do
        if [ -f "${servicePathAndFilename}" ]; then
            cat > "${SUPERVISOR_BASE_PATH}/etc/conf.d/beach-user-${serviceNumber}.conf" <<- EOM
[program:beach-user-${serviceNumber}]
process_name=%(program_name)s
command=${servicePathAndFilename}
autostart=true
autorestart=true
numprocs=1
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
redirect_stderr=true
EOM
            chmod 644 "${SUPERVISOR_BASE_PATH}/etc/conf.d/beach-user-${serviceNumber}.conf"

            info "Beach: Enabled ${servicePathAndFilename} as user-defined service script"
        fi
        (( serviceNumber++ ))
    done

    if [[ $serviceNumber == 1 ]]; then
        info "Beach: No user-defined services found"
        return
    fi

}

# ---------------------------------------------------------------------------------------
# beach_initialize() - Set up configuration
#
# @global BEACH_* The BEACH_* environment variables
# @return void
#
beach_initialize() {
    info "Beach: Initializing configuration"
    info "Beach: Flow is going to run in context '${BEACH_FLOW_CONTEXT}'"

    beach_write_env
    beach_setup_user_profile
}

# ---------------------------------------------------------------------------------------
# beach_prepare_flow() - Prepare a Flow application before going online
#
# @global BEACH_* The BEACH_* environment variables
# @return void
#
beach_prepare_flow() {
    if [ ! -f "${BEACH_APPLICATION_PATH}"/flow ]; then
        warn "Beach: No Flow application detected, skipping preparations"
        return
    fi

    beach_run_doctrine_migrate
    beach_run_resource_publish
    beach_run_cache_warmup
    beach_run_custom_startup

    beach_enable_user_services

    debug "Beach: Writing .warmupdone flag"
    touch /application/.warmupdone
}
