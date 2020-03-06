#!/bin/bash
# shellcheck disable=SC2086

# ---------------------------------------------------------------------------------------
# extensions_yaml_prepare() - Prepare the system for this extension
#
# @return List of packages
#
extensions_yaml_prepare() {
    echo ""
}

# ---------------------------------------------------------------------------------------
# extensions_yaml_build_packages() - List package names only needed during build time
#
# @return List of packages
#
extensions_yaml_build_packages() {
    local packages="
        libyaml-dev
    "
    echo $packages
}

# ---------------------------------------------------------------------------------------
# extensions_yaml_runtime_packages() - List package names needed during runtime
#
# @return List of packages
#
extensions_yaml_runtime_packages() {
    echo "libyaml-0-2"
}

# ---------------------------------------------------------------------------------------
# extensions_yaml_url() - Returns the URL leading to the source code archive
#
# see: https://github.com/php/pecl-file_formats-yaml
#
# @return string
#
extensions_yaml_url() {
    echo "http://pecl.php.net/get/yaml-2.0.4.tgz"
}

# ---------------------------------------------------------------------------------------
# extensions_yaml_configure_arguments() - Returns additional configure arguments
#
# @return string
#
extensions_yaml_configure_arguments() {
    echo ""
}
