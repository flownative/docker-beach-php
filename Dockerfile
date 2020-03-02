FROM docker.pkg.github.com/flownative/docker-base/base:buster
MAINTAINER Robert Lemke <robert@flownative.com>

LABEL org.label-schema.name="PHP FPM"
LABEL org.label-schema.description="Docker image providing PHP FPM or just PHP"
LABEL org.label-schema.vendor="Flownative GmbH"

# -----------------------------------------------------------------------------
# PHP
# Latest versions: https://www.php.net/downloads.php

ARG PHP_VERSION
ENV PHP_VERSION ${PHP_VERSION}

ENV FLOWNATIVE_LIB_PATH="/opt/flownative/lib" \
    PHP_BASE_PATH="/opt/flownative/php" \
    PATH="/opt/flownative/php/bin:$PATH" \
    LOG_DEBUG=false

COPY --from=docker.pkg.github.com/flownative/bash-library/bash-library:1 /lib $FLOWNATIVE_LIB_PATH

COPY root-files/opt /opt
COPY root-files/build.sh /

RUN /build.sh init
RUN /build.sh prepare
RUN /build.sh build

COPY extensions $PHP_BASE_PATH/build/extensions

RUN /build.sh build_extension vips
RUN /build.sh build_extension imagick
RUN /build.sh build_extension yaml
RUN /build.sh build_extension phpredis

# Migrate this to further up:

ENV LOG_DEBUG=true
COPY root-files/entrypoint.sh /
COPY more-root-files/opt /opt

RUN rm -rf ${PHP_BASE_PATH}/src
RUN /build.sh clean

USER 1000
EXPOSE 9000 9001
ENTRYPOINT [ "/entrypoint.sh" ]
CMD [ "run" ]
