FROM docker.pkg.github.com/flownative/docker-base/base:1
LABEL maintainer="Robert Lemke <robert@flownative.com>"

LABEL org.label-schema.name="Beach PHP"
LABEL org.label-schema.description="Docker image providing PHP for Beach instances"
LABEL org.label-schema.vendor="Flownative GmbH"

ENV PHP_INI_DIR /usr/local/etc/php
RUN mkdir -p $PHP_INI_DIR/conf.d

# https://secure.php.net/gpg-keys.php#gpg-7.2
#RUN gpg --keyserver pool.sks-keyservers.net --recv-keys B1B44D8F021E4E2D6021E995DC9FF8D3EE5AF27F \
# && gpg --keyserver pool.sks-keyservers.net --recv-keys 1729F83938DA44E27BA0F4D3DBDB397470D12172

ENV PHP_VERSION 7.2.26
ENV PHP_EXTRA_CONFIGURE_ARGS --enable-fpm --with-fpm-user=beach --with-fpm-group=beach

RUN buildDependencies=" \
        build-essential \
        git-core \
        autoconf \
        bison \
        libxml2-dev \
        libbz2-dev \
        libmcrypt-dev \
        libcurl4-openssl-dev \
        libltdl-dev \
        libpspell-dev \
        libreadline-dev \
        libicu-dev \
        libxml2-dev \
        libpng-dev \
        libmcrypt-dev \
        libssl-dev \
        libfreetype6 \
        libfreetype6-dev \
        libreadline6-dev \
        pkg-config \
        zlib1g-dev \
        libmysqlclient-dev \
        cmake \
    "; \
    set -x \
    && apt-get update && apt-get install --yes --no-install-recommends $buildDependencies && rm -rf /var/lib/apt/lists/* \
    && curl -SL "https://www.php.net/distributions/php-$PHP_VERSION.tar.gz" -o php.tar.gz \
    && mkdir -p /usr/src/php \
    && tar -xf php.tar.gz -C /usr/src/php --strip-components=1 \
    && rm php.tar.gz* \
    && cd /usr/src/php \
    && ./configure \
        --with-config-file-path="$PHP_INI_DIR" \
        --with-config-file-scan-dir="$PHP_INI_DIR/conf.d" \
        $PHP_EXTRA_CONFIGURE_ARGS \
        --disable-cgi \
        --enable-intl \
        --with-mysqli \
        --with-pdo-mysql \
        --with-curl \
        --with-openssl \
        --with-readline \
        --with-zlib \
        --enable-pcntl \
        --enable-calendar \
        --enable-ftp \
        --enable-exif \
        --enable-soap \
    && make -j"$(nproc)" \
    && make install \
    && { find /usr/local/bin /usr/local/sbin -type f -executable -exec strip --strip-all '{}' + || true; } \
    && make clean \
    && apt-get purge --yes --auto-remove $buildDependencies

COPY docker-php-ext-* /usr/local/bin/

RUN extensionDependencies=" \
        libpng16-16 \
        libfreetype6 \
        libjpeg-turbo8 \
        libtiff5 \
        libmagickwand-6.q16-3 \
        libvips42 \
        ghostscript \
        libsqlite3-0 \
        libyaml-0-2 \
        libcurl4-openssl-dev \
        libgmp10 \
    "; \
    set -x \
    && apt-get update && apt-get install --yes --no-install-recommends $extensionDependencies && rm -rf /var/lib/apt/lists/*

RUN buildDependencies=" \
        build-essential \
        autoconf \
        libpng-dev \
        libfreetype6-dev \
        libjpeg-turbo8-dev \
        libtiff5-dev \
        libgsf-1-dev \
        glib2.0-dev \
        libexpat1-dev \
        libvips-dev \
        libmagickwand-dev \
        libsqlite3-dev \
        libyaml-dev \
        libgmp-dev \
    "; \
    set -x \
    && apt-get update && apt-get install --yes --no-install-recommends $buildDependencies && rm -rf /var/lib/apt/lists/* \
    && curl -SL "https://github.com/jcupitt/php-vips-ext/raw/master/vips-1.0.10.tgz" -o vips.tar.gz \
    && tar -xf vips.tar.gz -C /usr/src/php/ext \
    && mv /usr/src/php/ext/vips-1.0.10 /usr/src/php/ext/vips \
    && rm vips.tar.gz \
    && curl -SL "https://pecl.php.net/get/imagick-3.4.4.tgz" -o imagick.tar.gz \
    && tar -xf imagick.tar.gz -C /usr/src/php/ext \
    && mv /usr/src/php/ext/imagick-3.4.4 /usr/src/php/ext/imagick \
    && rm imagick.tar.gz \
    && curl -SL "https://pecl.php.net/get/zip-1.15.5.tgz" -o zip.tar.gz \
    && tar -xf zip.tar.gz -C /usr/src/php/ext \
    && mv /usr/src/php/ext/zip-1.15.5 /usr/src/php/ext/zip \
    && rm zip.tar.gz \
    && curl -SL "http://pecl.php.net/get/yaml-2.0.4.tgz" -o yaml.tar.gz \
    && tar -xf yaml.tar.gz -C /usr/src/php/ext \
    && mv /usr/src/php/ext/yaml-2.0.4 /usr/src/php/ext/yaml \
    && rm yaml.tar.gz \
    && curl -SL "https://github.com/phpredis/phpredis/archive/5.1.1.tar.gz" -o phpredis.tar.gz \
    && tar -xf phpredis.tar.gz -C /usr/src/php/ext \
    && mv /usr/src/php/ext/phpredis-5.1.1 /usr/src/php/ext/phpredis \
    && rm phpredis.tar.gz \
    && docker-php-ext-install mbstring \
    && docker-php-ext-configure gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/ \
    && docker-php-ext-install gd \
    && docker-php-ext-configure vips \
    && docker-php-ext-install vips \
    && docker-php-ext-configure imagick --with-quantum-depth=8 \
    && docker-php-ext-install imagick \
    && docker-php-ext-install zip \
    && docker-php-ext-install yaml \
    && docker-php-ext-install gmp \
    && docker-php-ext-configure phpredis \
    && docker-php-ext-install phpredis \
    && apt-get purge --yes --auto-remove $buildDependencies

RUN mkdir -p /usr/local/etc/php \
    && chown -R www-data:www-data /usr/local/etc/php \
    && ln -s /usr/local/bin/php /usr/bin/php

COPY php.ini /usr/local/etc/php/php.ini

RUN groupadd -r -g 1000 beach && useradd -s /bin/bash -r -g beach -G beach -p "*" -u 1000 beach
RUN mkdir -p /home/beach \
    && chown beach:beach /home/beach

COPY ready.sh /ready.sh
RUN chmod u=rwx /ready.sh

COPY ImageMagick/policy.xml /etc/ImageMagick-6/policy.xml

CMD ["/sbin/my_init"]
