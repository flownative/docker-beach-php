#!/bin/bash
# shellcheck disable=SC1090
# shellcheck disable=SC2086
# shellcheck disable=SC2046

# Load helper libraries

. "${FLOWNATIVE_LIB_PATH}/banner.sh"
. "${FLOWNATIVE_LIB_PATH}/log.sh"
. "${FLOWNATIVE_LIB_PATH}/packages.sh"

set -o errexit
set -o nounset
set -o pipefail

# ---------------------------------------------------------------------------------------
# build_create_directories() - Create directories and set access rights accordingly
#
# @global PHP_BASE_PATH
# @global BEACH_APPLICATION_PATH
# @return void
#
build_create_directories() {
    mkdir -p \
        "${PHP_BASE_PATH}/bin" \
        "${PHP_BASE_PATH}/etc/conf.d" \
        "${PHP_BASE_PATH}/ext" \
        "${PHP_BASE_PATH}/tmp" \
        "${PHP_BASE_PATH}/log" \
        "${BEACH_APPLICATION_PATH}/Data"

    chown -R 1000 "${BEACH_APPLICATION_PATH}"

    # Forward error log to Docker log collector
    ln -sf /dev/stderr "${PHP_BASE_PATH}/log/error.log"
}

# ---------------------------------------------------------------------------------------
# build_get_build_packages() - Returns a list of packages which are only needed for building
#
# @global PHP_BASE_PATH
# @return List of packages
#
build_get_build_packages() {
    local packages="
        autoconf
        bison
        build-essential
        cmake
        curl
        pkg-config
        re2c
        file

        libcurl4-openssl-dev
        libgmp-dev
        libicu-dev
        libltdl-dev
        libmcrypt-dev
        libmcrypt-dev
        libonig-dev
        libpspell-dev
        libreadline-dev
        libssl-dev
        libxml2-dev
        libzip-dev

        libfreetype6-dev
        libjpeg62-turbo-dev
        libpng-dev
        libwebp-dev

        libmariadb-dev
        libsqlite3-dev
   "
    echo $packages
}

# ---------------------------------------------------------------------------------------
# build_get_runtime_packages() - Returns a list of packages which are needed during runtime
#
# @return List of packages
#
build_get_runtime_packages() {
    local packages="
        libcurl4
        libonig5
        libreadline7
        libssl1.1
        libzip4

        libsqlite3-0
   "
    echo $packages
}

# ---------------------------------------------------------------------------------------
# build_get_unneccessary_packages() - Not needed packages, can be removed
#
# @return List of packages
#
build_get_unneccessary_packages() {
    local packages="
        cmake
   "
    echo $packages
}

# ---------------------------------------------------------------------------------------
# build_compile_php() -
#
# @global PHP_BASE_PATH
# @return void
#
build_compile_php() {
    local php_source_url

    php_source_url="https://www.php.net/distributions/php-${PHP_VERSION}.tar.gz"
    info "🛠 Downloading source code for PHP ${PHP_VERSION} from ${php_source_url} ..."
    with_backoff "curl -sSL ${php_source_url} -o php.tar.gz" || (
        error "Failed downloading PHP source from ${php_source_url}"
        exit 1
    )

    mkdir -p "${PHP_BASE_PATH}/src"
    tar -xf php.tar.gz -C "${PHP_BASE_PATH}/src" --strip-components=1
    rm php.tar.gz*

    cd "${PHP_BASE_PATH}/src"

    # For GCC warning options see: https://gcc.gnu.org/onlinedocs/gcc-3.4.4/gcc/Warning-Options.html
    export CFLAGS='-Wno-deprecated-declarations -Wno-stringop-overflow -Wno-implicit-function-declaration'

    info "🛠 Running configure for PHP ..."
    ./configure \
        --prefix=${PHP_BASE_PATH} \
        --with-config-file-path="${PHP_BASE_PATH}/etc" \
        --with-config-file-scan-dir="${PHP_BASE_PATH}/etc/conf.d" \
        --disable-cgi \
        --enable-fpm \
        --enable-gd \
        --enable-pcntl \
        --enable-calendar \
        --enable-exif \
        --enable-ftp \
        --enable-mbstring \
        --enable-intl \
        --with-curl \
        --with-freetype \
        --with-jpeg \
        --with-gmp \
        --with-mysqli \
        --with-openssl \
        --with-pdo-mysql \
        --with-readline \
        --with-system-ciphers \
        --with-webp \
        --with-zip \
        --with-zlib \
        --without-pear \
        >$(debug_device)

    info "🛠 Compiling PHP ..."
    make -j"$(nproc)" >$(debug_device)
    make install >$(debug_device)

    info "🛠 Cleaning up ..."
    make clean >$(debug_device)
    rm -rf /tmp/pear
}

# ---------------------------------------------------------------------------------------
# build_php_extension() - Download, move and compile PHP extension source code
#
# @global PHP_BASE_PATH
# @arg Extension name, e.g. "yaml"
# @return void
#
build_php_extension() {

    # -----------------------------------------------------------------------------------
    # Prepare variables

    local -r extension_name="${1:-missing extension name}"
    local -r extension_build_configration_script="${PHP_BASE_PATH}/build/extensions/${extension_name}/${extension_name}.sh"

    . "${extension_build_configration_script}" || (
        error "Failed sourcing extension build configuration script from ${extension_build_configration_script}"
        exit 1
    )

    local -r extensions_dir="${PHP_BASE_PATH}/src/ext"
    local -r extension_dir="${extensions_dir}/${extension_name}"
    local -r extension_url=$(eval "extensions_${extension_name}_url")
    local -r extension_configure_arguments=$(eval "extensions_${extension_name}_configure_arguments")
    local -r extension_ini_path_and_filename="${PHP_BASE_PATH}/etc/conf.d/php-ext-${extension_name}.ini"
    local -r extension_build_packages=$(eval "extensions_${extension_name}_build_packages")
    local -r extension_runtime_packages=$(eval "extensions_${extension_name}_runtime_packages")

    eval "extensions_${extension_name}_prepare"

    # -----------------------------------------------------------------------------------
    # Install packages
    if [[ "${extension_runtime_packages}" != "" ]]; then
        info "🔌 ${extension_name}: Installing runtime packages required by extension"
        packages_install ${extension_runtime_packages} 1>$(debug_device)
    else
        info "🔌 ${extension_name}: No additional runtime packages to install"
    fi

    if [[ "${extension_build_packages}" != "" ]]; then
        info "🔌 ${extension_name}: Installing build packages required by extension"
        packages_install ${extension_build_packages} 1>$(debug_device)
    else
        info "🔌 ${extension_name}: No additional build packages to install"
    fi

    if [[ "${extension_url}" != "" ]]; then
        # ---------------------------------------------------------------------------------
        # Download and extract source code
        info "🔌 ${extension_name}: Downloading extension source code from ${extension_url} ..."

        with_backoff "curl -sSL ${extension_url} -o ${extension_name}.tar.gz" || (
            error "Failed downloading extension ${extension_name}"
            exit 1
        )
        tar -xf ${extension_name}.tar.gz -C ${extensions_dir} 2>/dev/null || (
            error "Tar failed extracting the archive downloaded from ${extension_url}, returned exit code $?"
            exit 1
        )

        mv "${extensions_dir}/${extension_name}"-* "${extension_dir}"
        rm -f ${extension_name}.tar.gz "${extensions_dir}/package.xml"
    else
        info "🔌 ${extension_name}: No download URL specified, so not downloading extension source code"
    fi

    # ---------------------------------------------------------------------------------
    # Configure

    cd "${extension_dir}"
    test -f config.m4 || (
        error "No config.m4 file found in extension directory ${extension_dir}"
        exit 1
    )

    info "🔌 ${extension_name}: Running phpize ..."
    phpize 1>$(debug_device)

    if [[ ${extension_configure_arguments} == "" ]]; then
        info "🔌 ${extension_name}: Running configure without additional arguments ..."
    else
        info "🔌 ${extension_name}: Running configure ${extension_configure_arguments} ..."
    fi

    # For GCC warning options see: https://gcc.gnu.org/onlinedocs/gcc-3.4.4/gcc/Warning-Options.html
    export CFLAGS='-Wno-deprecated-declarations -Wno-stringop-overflow -Wno-implicit-function-declaration'

    ./configure ${extension_configure_arguments} 1>$(debug_device) || (
        error "Configure failed for extension ${extension_name}"
        exit 1
    )

    # ---------------------------------------------------------------------------------
    # Compile
    info "🔌 ${extension_name}: Compiling extension ..."

    make 1>$(debug_device)
    make install 1>$(debug_device)

    # -----------------------------------------------------------------------------------
    # Write extension's .ini file
    info "🔌 ${extension_name}: Writing ini-file ..."

    if [[ "${extension_url}" != "" ]]; then
        for module in "${extension_dir}"/modules/*.so; do
            if [ -f "$module" ]; then
                if grep -q zend_extension_entry "${module}"; then
                    line="zend_extension=$(basename "$module")"
                else
                    line="extension=$(basename "${module}")"
                fi
                if ! grep -q "${line}" "${extension_ini_path_and_filename}" &>/dev/null; then
                    echo "$line" >>${extension_ini_path_and_filename}
                fi
            fi
        done
    fi

    # -----------------------------------------------------------------------------------
    # Clean up

    info "🔌 ${extension_name}: Cleaning up ..."

    make clean 1>$(debug_device)
    make distclean 1>$(debug_device)

    if [[ "${extension_build_packages}" != "" ]]; then
        info "🔌 ${extension_name}: Removing build packages"
        packages_remove ${extension_build_packages} 1>$(debug_device)
    fi
}

# ---------------------------------------------------------------------------------------
# build_sshd() - Install and configure the SSH daemon
#
# @global SSHD_BASE_PATH
# @return void
#
build_sshd() {
    packages_install openssh-server

    # Clean up a few directories / files we don't need:
    rm -rf \
        /etc/ufw \
        /etc/init.d \
        /etc/rc2.d/S01ssh \
        /etc/rc2.d/S01ssh \
        /lib/systemd/system/rescue-ssh.target \
        /lib/systemd/system/ssh*

    # Create directories
    mkdir -p \
        "${SSHD_BASE_PATH}/etc" \
        "${SSHD_BASE_PATH}/sbin" \
        "${SSHD_BASE_PATH}/tmp" \

    # Move SSHD files to correct location:
    mv /usr/sbin/sshd ${SSHD_BASE_PATH}/sbin/

    chown -R 1000 \
        "${SSHD_BASE_PATH}/etc" \
        "${SSHD_BASE_PATH}/tmp"

    info "SSHD: Creating user beach (1000)"
    useradd --home-dir /application --no-create-home --no-user-group --shell /bin/bash --uid 1000 beach 1>$(debug_device)
}

# ---------------------------------------------------------------------------------------
# build_adjust_permissions() - Adjust permissions for a few paths and files
#
# @global PHP_BASE_PATH
# @return void
#
build_adjust_permissions() {
    chown -R root:root "${PHP_BASE_PATH}"
    chmod -R g+rwX "${PHP_BASE_PATH}"

    chown -R 1000 \
        "${PHP_BASE_PATH}/etc" \
        "${PHP_BASE_PATH}/tmp"
}

# ---------------------------------------------------------------------------------------
# build_clean() - Clean up obsolete building artifacts and temporary files
#
# @global PHP_BASE_PATH
# @return void
#
build_clean() {
    rm -rf \
        /etc/emacs \
        /usr/include \
        /var/cache/* \
        /var/log/* \
        "${PHP_BASE_PATH}/include" \
        "${PHP_BASE_PATH}/php/man" \
        "${PHP_BASE_PATH}/src"
}

# ---------------------------------------------------------------------------------------
# Main routine

case $1 in
init)
    banner_flownative PHP
    build_create_directories
    ;;
prepare)
    packages_install $(build_get_runtime_packages) 1>$(debug_device)
    packages_install $(build_get_build_packages) 1>$(debug_device)
    ;;
build)
    build_compile_php
    ;;
build_extension)
    build_php_extension $2
    ;;
sshd)
    build_sshd
    ;;
clean)
    build_adjust_permissions

    packages_remove $(build_get_build_packages) 1>$(debug_device)
    packages_remove $(build_get_unneccessary_packages) 1>$(debug_device)
    packages_remove_docs_and_caches 1>$(debug_device)
    build_clean
    ;;
esac
