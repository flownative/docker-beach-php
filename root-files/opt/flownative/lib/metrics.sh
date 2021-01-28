#!/bin/bash
# shellcheck disable=SC1090

# =======================================================================================
# LIBRARY: METRICS
# =======================================================================================

# This library contains functions for providing Prometheus metrics.

# Load helper lib

. "${FLOWNATIVE_LIB_PATH}/log.sh"

# ---------------------------------------------------------------------------------------
# metrics_env() - Load global environment variables
#
# @global METRICS_* The METRICS_ environment variables
# @return "export" statements which can be passed to eval()
#
metrics_env() {
    cat <<"EOF"
export METRICS_PHP_FPM_ENABLE=${METRICS_PHP_FPM_ENABLE:-false}
export METRICS_PHP_FPM_LISTEN_ADDRESS=${METRICS_PHP_FPM_LISTEN_ADDRESS:-127.0.0.1:9002}
export METRICS_PHP_FPM_TELEMETRY_PATH=${METRICS_PHP_FPM_TELEMETRY_PATH:-/metrics}
EOF
}

# ---------------------------------------------------------------------------------------
# metrics_start() - Start Metric
#
# @global METRICS_* The METRICS_ environment variables
# @return void
#
metrics_start() {
    local pid

    info "Metrics: Starting ..."

    supervisorctl start php-fpm-exporter 1>$(debug_device)
    pid=$(supervisorctl pid php-fpm-exporter)

    info "Metrics: PHP-FPM exporter listening on ${METRICS_PHP_FPM_LISTEN_ADDRESS}"
    info "Metrics: Running as process #${pid} on host $(hostname)"
}

# ---------------------------------------------------------------------------------------
# metrics_stop() - Stop the Metric process based on the current PID
#
# @global METRICS_* The METRICS_ environment variables
# @return void
#
metrics_stop() {
    supervisorctl stop php-fpm-exporter 1>$(debug_device)

    info "Metrics: Process stopped"
}
