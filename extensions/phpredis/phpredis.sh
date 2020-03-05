#!/bin/bash
# shellcheck disable=SC2086

# ---------------------------------------------------------------------------------------
# extensions_phpredis_prepare() - Prepare the system for this extension
#
# @return List of packages
#
extensions_phpredis_prepare() {
    echo ""
}

# ---------------------------------------------------------------------------------------
# extensions_phpredis_build_packages() - List package names only needed during build time
#
# @return List of packages
#
extensions_phpredis_build_packages() {
    local packages="
    "
    echo $packages
}

# ---------------------------------------------------------------------------------------
# extensions_phpredis_runtime_packages() - List package names needed during runtime
#
# @return List of packages
#
extensions_phpredis_runtime_packages() {
    echo ""
}

# ---------------------------------------------------------------------------------------
# extensions_phpredis_url() - Returns the URL leading to the source code archive
#
# see: https://github.com/phpredis/phpredis
#      https://github.com/phpredis/phpredis/blob/develop/INSTALL.markdown
#
# @return string
#
extensions_phpredis_url() {
    echo "https://github.com/phpredis/phpredis/archive/5.1.1.tar.gz"
}

# ---------------------------------------------------------------------------------------
# extensions_phpredis_configure_arguments() - Returns additional configure arguments
#
# @return string
#
extensions_phpredis_configure_arguments() {
    echo ""
}
