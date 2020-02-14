#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

# Load library
. "${FLOWNATIVE_LIB_PATH}/nginx.sh"
. "${FLOWNATIVE_LIB_PATH}/log.sh"
. "${FLOWNATIVE_LIB_PATH}/os.sh"

# Load Nginx environment variables
eval "$(nginx_env)"

# Start Nginx
with_backoff nginx_start
