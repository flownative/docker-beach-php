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
# @global BEACH_* The BEACH_ evnironment variables
# @return "export" statements which can be passed to eval()
#
beach_env() {
    cat <<"EOF"
export BEACH_ENVIRONMENT_VARIABLES_WHITELIST=${BEACH_REMOTE_ENVIRONMENT_VARIABLE_NAMES:-}


EOF
}
