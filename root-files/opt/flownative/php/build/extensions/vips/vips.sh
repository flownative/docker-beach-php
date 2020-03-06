#!/bin/bash
# shellcheck disable=SC2086

# ---------------------------------------------------------------------------------------
# extensions_vips_prepare() - Prepare the system for this extension
#
# @return List of packages
#
extensions_vips_prepare() {
    echo ""
}

# ---------------------------------------------------------------------------------------
# extensions_vips_build_packages() - List package names only needed during build time
#
# @return List of packages
#
extensions_vips_build_packages() {
    local packages="
        libvips-dev
    "
    echo $packages
}

# ---------------------------------------------------------------------------------------
# extensions_vips_runtime_packages() - List package names needed during runtime
#
# @return List of packages
#
extensions_vips_runtime_packages() {
    echo "libvips42"
}

# ---------------------------------------------------------------------------------------
# extensions_vips_url() - Returns the URL leading to the source code archive
#
# @return string
#
extensions_vips_url() {
    echo "https://github.com/jcupitt/php-vips-ext/raw/master/vips-1.0.10.tgz"
}

# ---------------------------------------------------------------------------------------
# extensions_vips_configure_arguments() - Returns additional configure arguments
#
# @return string
#
extensions_vips_configure_arguments() {
    echo ""
}
