#!/bin/bash
# shellcheck disable=SC1090

# =======================================================================================
# LIBRARY: BEACH
# =======================================================================================

# This library contains functions for configuring Flow / Neos and Beach related features.

# Load helper lib

. "${FLOWNATIVE_LIB_PATH}/log.sh"

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
# beach_env_unset_by_whitelist() - Unsets all env variables except for given whitelist
#
# @global BEACH_* The BEACH_ evnironment variables
# @return void
#
beach_env_unset_by_whitelist() {
    local environmentVariableNames
    local systemVariableNames
    local allowedVariableNames

    environmentVariableNames=$(env | cut -f1 -d=)
    whitelistedVariableNames=$(base64 -d <<< "${BEACH_ENVIRONMENT_VARIABLES_WHITELIST}")
    systemVariableNames=(
        _
        BASH
        BASH_ALIASES
        BASH_ARGC
        BASH_ARGV
        BASH_CMDS
        BASH_LINENO
        BASH_SOURCE
        BASH_VERSINFO
        BASH_VERSION
        BASHOPTS
        BEACH_ADDON_BLACKFIRE_AGENT_HOST
        BEACH_ADDON_BLACKFIRE_AGENT_PORT
        BEACH_ADDON_BLACKFIRE_ENABLE
        BEACH_APPLICATION_PATH
        BEACH_DATABASE_HOST
        BEACH_DATABASE_NAME
        BEACH_DATABASE_PASSWORD
        BEACH_DATABASE_PORT
        BEACH_DATABASE_USERNAME
        BEACH_INSTANCE_NAME
        BEACH_INSTANCE_IDENTIFIER
        BEACH_INSTANCE_IMAGE_NAME
        BEACH_PHP_FPM_ENABLE
        BEACH_PHP_FPM_MAX_CHILDREN
        BEACH_PHP_FPM_PORT
        BEACH_PHP_MEMORY_LIMIT
        BEACH_PHP_TIMEZONE
        BEACH_REDIS_HOST
        BEACH_REDIS_PASSWORD
        BEACH_REDIS_PORT
        DEBIAN_FRONTEND
        DIRSTACK
        EUID
        FLOW_CONTEXT
        FLOWNATIVE_LIB_PATH
        GROUPS
        HOME
        HOSTNAME
        HOSTTYPE
        IFS
        LANG
        LANGUAGE
        LC_ALL
        LESSCLOSE
        LESSOPEN
        LOG_DEBUG
        LS_COLORS
        MACHTYPE
        MICRO_VERSION
        OPTERR
        OPTIND
        OSTYPE
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
        PPID
        PS4
        PWD
        SHELL
        SHELLOPTS
        SHLVL
        SSHD_AUTHORIZED_KEYS_SERVICE_ENDPOINT
        SSHD_BASE_PATH
        SSHD_ENABLE
        SSHD_HOST_KEYS_PATH
        TERM
        UID
    );

    allowedVariableNames=("${whitelistedVariableNames[@]}" "${systemVariableNames[@]}");
    # shellcheck disable=SC2068
    for variableName in ${environmentVariableNames[@]}
    do
        variableAllowed=false
        for allowedVariableName in ${allowedVariableNames[@]}
        do
        if [[ ${allowedVariableName} == "${variableName}" ]]; then
            variableAllowed=true
            break
            fi
        done
        if [[ ${variableAllowed} != true ]]; then
            debug "Beach: Unsetting environment variable ${variableName}"
            unset "${variableName}"
        fi
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
    cat > /home/beach/.my.cnf <<- EOM
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
# beach_custom_startup() - Invoke a custom startup script, if one exists
#
# @global BEACH_* The BEACH_* environment variables
# @return void
#
beach_custom_startup() {
    if [ ! -f "${BEACH_APPLICATION_PATH}/beach-startup.sh" ]; then
        info "Beach: No custom startup script found"
        return
    fi

    info "Beach: Running custom startup script ..."
    chmod +x "${BEACH_APPLICATION_PATH}/beach-startup.sh"
    "${BEACH_APPLICATION_PATH}/beach-startup.sh" 2>&1 | (sed 's/^/Beach: (flow) /' | output)
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

    if [ -n "${BEACH_ENVIRONMENT_VARIABLES_WHITELIST}" ]; then
        info "Beach: Unsetting environment variables according to given whitelist"
        beach_env_unset_by_whitelist
    fi

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

    beach_custom_startup

    debug "Beach: Writing .warmupdone flag"
    touch /application/.warmupdone
}
