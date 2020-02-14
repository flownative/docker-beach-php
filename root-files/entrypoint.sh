#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

# Load lib
. "${FLOWNATIVE_LIB_PATH}/nginx.sh"
. "${FLOWNATIVE_LIB_PATH}/nginx-legacy.sh"

eval "$(nginx_env)"
eval "$(nginx_legacy_env)"

if [[ "$*" = *"/run.sh"* ]]; then
    nginx_initialize
    nginx_legacy_initialize

    trap nginx_stop EXIT
fi
exec "$@"
