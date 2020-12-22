#!/bin/bash
# shellcheck disable=SC1090

# =======================================================================================
# LIBRARY: BEACH LEGACY
# =======================================================================================

# This library contains functions for providing backwards-compatibility with earlier
# versions of the Beach PHP-FPM image.

# Load helper lib

. "${FLOWNATIVE_LIB_PATH}/log.sh"

# ---------------------------------------------------------------------------------------
# beach_legacy_env() - Load global environment variables for configuring PHP
#
# @global BEACH_* The BEACH_ environment variables
# @return "export" statements which can be passed to eval()
#
beach_legacy_env() {
    cat <<"EOF"
export PHP_DATE_TIMEZONE=${BEACH_PHP_TIMEZONE:-}
export PHP_MEMORY_LIMIT=${PHP_MEMORY_LIMIT:-${BEACH_PHP_MEMORY_LIMIT:-}}
EOF
}
