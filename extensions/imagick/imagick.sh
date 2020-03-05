#!/bin/bash
# shellcheck disable=SC2086

# ---------------------------------------------------------------------------------------
# extensions_imagick_prepare() - Prepare the system for this extension
#
# @return List of packages
#
extensions_imagick_prepare() {
    # see: https://imagemagick.org/script/security-policy.php
    rm -f /etc/ImageMagick-6/policy.xml
    ln -s ${PHP_BASE_PATH}/build/extensions/imagick/policy.xml /etc/ImageMagick-6/policy.xml
}

# ---------------------------------------------------------------------------------------
# extensions_imagick_build_packages() - List package names only needed during build time
#
# @return List of packages
#
extensions_imagick_build_packages() {
    local packages="
        file
        libmagickwand-dev
    "
    echo $packages
}

# ---------------------------------------------------------------------------------------
# extensions_imagick_runtime_packages() - List package names needed during runtime
#
# @return List of packages
#
extensions_imagick_runtime_packages() {
    local packages="
        libmagickwand-6.q16
    "
    echo $packages
}

# ---------------------------------------------------------------------------------------
# extensions_imagick_url() - Returns the URL leading to the source code archive
#
# @return string
#
extensions_imagick_url() {
    echo "https://pecl.php.net/get/imagick-3.4.4.tgz"
}

# ---------------------------------------------------------------------------------------
# extensions_imagick_configure_arguments() - Returns additional configure arguments
#
# Arguments mentioned in the Imagemagick docs (for example, --with-quantum-depth) don't
# seem to work with here (https://imagemagick.org/script/advanced-unix-installation.php).
#
# @return string
#
extensions_imagick_configure_arguments() {
    echo ""
}
