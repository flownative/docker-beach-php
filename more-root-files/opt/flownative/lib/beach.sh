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
export BEACH_APPLICATION_USER_SERVICE_ENABLE=${BEACH_APPLICATION_USER_SERVICE_ENABLE:-false}
export BEACH_APPLICATION_USER_SERVICE_USERNAME=${BEACH_APPLICATION_USER_SERVICE_USERNAME:-beach}
export BEACH_APPLICATION_STARTUP_SCRIPT_USERNAME=${BEACH_APPLICATION_STARTUP_SCRIPT_USERNAME:-beach}

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
        BASH
        BASHOPTS
        BASH_ALIASES
        BASH_ARGC
        BASH_ARGV
        BASH_CMDS
        BASH_LINENO
        BASH_SOURCE
        BASH_VERSINFO
        BASH_VERSION
        BEACH_APPLICATION_PATH
        BEACH_INSTANCE_IMAGE_NAME
        BEACH_PHP_FPM_ENABLE
        BEACH_PHP_FPM_PORT
        BEACH_PHP_FPM_MAX_CHILDREN
        DEBIAN_FRONTEND
        DIRSTACK
        EUID
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
        PHP_FPM_GROUP
        PHP_FPM_USER
        PHP_FPM_PORT
        PHP_FPM_MAX_CHILDREN
        PHP_LOG_PATH
        PHP_TMP_PATH
        PHP_VERSION
        PPID
        PS4
        PWD
        SHELL
        SHELLOPTS
        SHLVL
        TERM
        UID
        _
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
}

# ---------------------------------------------------------------------------------------
# beach_prepare_flow() - Prepare a Flow application before going online
#
# @global BEACH_* The BEACH_* environment variables
# @return void
#
beach_prepare() {
    if [ ! -f "${BEACH_APPLICATION_PATH}"/flow ]; then
        warn "Beach: No Flow application detected, skipping preparations"
        return
    fi

    if [ -n "${BEACH_DATABASE_HOST}" ] || [ -n "${BEACH_DATABASE_SOCKET}" ]; then
        set +e
        info "Beach: Running doctrine:migrate on host ${BEACH_DATABASE_HOST}:${BEACH_DATABASE_PORT} for database '${BEACH_DATABASE_NAME}' as database user '${BEACH_DATABASE_USERNAME}'"
        "${BEACH_APPLICATION_PATH}/flow" doctrine:migrate > >(sed 's/^/Beach: (flow) /' | output)
    fi

    info "Beach: Running resource:publish --collection static"
    "${BEACH_APPLICATION_PATH}/flow" resource:publish --collection static > >(sed 's/^/Beach: (flow) /' | output)

    info "Beach: Warming up caches"
    "${BEACH_APPLICATION_PATH}/flow" cache:warmup > >(sed 's/^/Beach: (flow) /' | output)

    debug "Beach: Writing .warmupdone flag"
    touch /application/.warmupdone
}
