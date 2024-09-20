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
# @global BEACH_* The BEACH_ environment variables
# @return "export" statements which can be passed to eval()
#
beach_env() {
    cat <<"EOF"
export BEACH_APPLICATION_PATH=${BEACH_APPLICATION_PATH:-/application}
export BEACH_APPLICATION_PATH=${BEACH_APPLICATION_PATH%/}
export BEACH_APPLICATION_USER_SERVICE_ENABLE=${BEACH_APPLICATION_USER_SERVICE_ENABLE:-false}
export BEACH_APPLICATION_USER_SERVICE_USERNAME=${BEACH_APPLICATION_USER_SERVICE_USERNAME:-beach}
export BEACH_APPLICATION_STARTUP_SCRIPTS_ENABLE=${BEACH_APPLICATION_STARTUP_SCRIPTS_ENABLE:-true}
export BEACH_APPLICATION_CUSTOM_STARTUP_SCRIPTS_ENABLE=${BEACH_APPLICATION_CUSTOM_STARTUP_SCRIPTS_ENABLE:-true}

export BEACH_INSTANCE_IDENTIFIER=${BEACH_INSTANCE_IDENTIFIER:-}
export BEACH_INSTANCE_NAME=${BEACH_INSTANCE_NAME:-}
export BEACH_PROJECT_NAME=${BEACH_PROJECT_NAME:-}

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
export BEACH_ENVIRONMENT_VARIABLES_ALLOW_LIST=${BEACH_ENVIRONMENT_VARIABLES_ALLOW_LIST:-${BEACH_ENVIRONMENT_VARIABLES_WHITELIST:-}}
export BEACH_CRON_ENABLE=${BEACH_CRON_ENABLE:-false}

export SITEMAP_CRAWLER_ENABLE=${SITEMAP_CRAWLER_ENABLE:-false}
export SITEMAP_CRAWLER_SITEMAP_URL=${SITEMAP_CRAWLER_SITEMAP_URL:-http://localhost:8080/sitemap.xml}
export SITEMAP_CRAWLER_INTERNAL_BASE_URL=${SITEMAP_CRAWLER_INTERNAL_BASE_URL:-http://localhost:8080}

export BEACH_ADDON_BLACKFIRE_ENABLE=${BEACH_ADDON_BLACKFIRE_ENABLE:-false}
export BEACH_ADDON_BLACKFIRE_SERVER_ID=${BEACH_ADDON_BLACKFIRE_SERVER_ID:-${BLACKFIRE_SERVER_ID:-}}
export BEACH_ADDON_BLACKFIRE_SERVER_TOKEN=${BEACH_ADDON_BLACKFIRE_SERVER_TOKEN:-${BLACKFIRE_SERVER_TOKEN:-}}

export BLACKFIRE_LOG_LEVEL=3
export BLACKFIRE_LOG_FILE=/opt/flownative/log/blackfire.log
export BLACKFIRE_AGENT_SOCKET=${BLACKFIRE_AGENT_SOCKET:-tcp://127.0.0.1:8307}
export BLACKFIRE_SERVER_ID=${BEACH_ADDON_BLACKFIRE_SERVER_ID}
export BLACKFIRE_SERVER_TOKEN=${BEACH_ADDON_BLACKFIRE_SERVER_TOKEN}

EOF
}

# ---------------------------------------------------------------------------------------
# beach_write_env() - Writes environment variables into ~/.env for SSH users
#
# @global BEACH_* The BEACH_ environment variables
# @return void
#
beach_write_env() {
    local systemVariableNames
    local allowedVariableNames
    local variableName

    systemVariableNames=(
        BEACH_INSTANCE_NAME
        BEACH_INSTANCE_IDENTIFIER
        BEACH_PROJECT_NAME
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
        SITEMAP_CRAWLER_BASE_PATH
        SSHD_AUTHORIZED_KEYS_SERVICE_ENDPOINT
        SSHD_BASE_PATH
        SSHD_ENABLE
        SSHD_HOST_KEYS_PATH
        SUPERVISOR_BASE_PATH
    )

    if [ -n "${BEACH_ENVIRONMENT_VARIABLES_ALLOW_LIST}" ]; then
        allowedVariableNames=$(base64 -d <<<"${BEACH_ENVIRONMENT_VARIABLES_ALLOW_LIST}")
        allowedVariableNames=("${allowedVariableNames[@]}" "${systemVariableNames[@]}")
    else
        info "Beach: No list of allowed environment variables defined, exporting all variables to user profile ..."
        allowedVariableNames=()
        while IFS='' read -r line; do allowedVariableNames+=("$line"); done < <(compgen -e)
    fi

    info "Beach: Exporting environment variables to user profile ..."

    set +o nounset
    # shellcheck disable=SC2068
    for variableName in ${allowedVariableNames[@]}; do
        echo "export ${variableName}='${!variableName//\'/\'\\\'\'}'" >> /home/beach/.env
    done
    set -o nounset
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
[mysql]
database              = ${BEACH_DATABASE_NAME}
[mysqldump]
no-tablespaces
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
# beach_run_sitemap_crawler() - Invoke a crawler which warms up caches for all urls of a sitemap
#
# @global SITEMAP_CRAWLER_SITEMAP_URL
# @global SITEMAP_CRAWLER_INTERNAL_BASE_URL
# @return void
#
beach_run_sitemap_crawler() {
    # Run the sitemap-crawler in a background process and make sure that it does not run
    # longer than 10 minutes:
    timeout 600 "${SITEMAP_CRAWLER_BASE_PATH}/sitemap-crawler.php" &
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
            serviceFilenameWithoutSuffix=$(basename ${servicePathAndFilename} .sh)
            cat > "${SUPERVISOR_BASE_PATH}/etc/conf.d/${serviceFilenameWithoutSuffix}.conf" <<- EOM
[program:${serviceFilenameWithoutSuffix}]
process_name=%(program_name)s
command=${servicePathAndFilename}
autostart=true
autorestart=true
numprocs=1
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
redirect_stderr=true
EOM
            chmod 644 "${SUPERVISOR_BASE_PATH}/etc/conf.d/${serviceFilenameWithoutSuffix}.conf"
            chmod 775 "${servicePathAndFilename}"

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
# beach_setup_igbinary() - Set up the igbinary extension
#
# @global PHP_*
# @return void
#
beach_setup_igbinary() {
    if is_boolean_yes "${PHP_IGBINARY_ENABLE}"; then
        if [ -f "${PHP_CONF_PATH}/conf.d/php-ext-igbinary.ini.inactive" ]; then
            info "Beach: igbinary is enabled"
            mv -f "${PHP_CONF_PATH}/conf.d/php-ext-igbinary.ini.inactive" "${PHP_CONF_PATH}/conf.d/php-ext-igbinary.ini"
        fi
    else
        info "Beach: igbinary is disabled"
    fi
}

# ---------------------------------------------------------------------------------------
# beach_setup_addon_blackfire() - Set up the Blackfire probe
#
# @global BEACH_*
# @global PHP_BASE_PATH
# @return void
#
beach_setup_addon_blackfire() {
    if is_boolean_no "$BEACH_ADDON_BLACKFIRE_ENABLE"; then
        info "Beach: Blackfire add-on is disabled"
        return
    fi

    info "Beach: Enabling Blackfire agent extension"
    cat > "${PHP_BASE_PATH}/etc/conf.d/php-ext-blackfire.ini" <<- EOM
extension=blackfire.so
EOM
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
    beach_setup_igbinary
    beach_setup_addon_blackfire
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

    if is_boolean_yes "$BEACH_APPLICATION_STARTUP_SCRIPTS_ENABLE"; then
        info "Beach: Running built-in startup scripts ..."
        beach_run_doctrine_migrate
        beach_run_resource_publish
        beach_run_cache_warmup
    else
        info "Beach: Skipping built-in startup scripts"
    fi

    if is_boolean_yes "$BEACH_APPLICATION_CUSTOM_STARTUP_SCRIPTS_ENABLE"; then
        info "Beach: Running custom startup scripts ..."
        beach_run_custom_startup
    else
        info "Beach: Skipping custom startup scripts"
    fi

    beach_enable_user_services
}

# ---------------------------------------------------------------------------------------
# beach_finalize_flow() - Finalize a Flow application before going online
#
# @global BEACH_* The BEACH_* environment variables
# @return void
#
beach_finalize_flow() {
    if [ ! -f "${BEACH_APPLICATION_PATH}"/flow ]; then
        warn "Beach: No Flow application detected, skipping finialize"
        return
    fi

    if is_boolean_yes "$SITEMAP_CRAWLER_ENABLE"; then
        info "Beach: Running sitemap crawler ..."
        beach_run_sitemap_crawler
    fi

    debug "Beach: Writing .warmupdone flag"
    touch /application/.warmupdone
}
