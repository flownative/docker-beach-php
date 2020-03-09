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
    BEACH_APPLICATION_PATH="/application" \
    SSHD_BASE_PATH="/opt/flownative/sshd" \
    SSHD_ENABLE="false" \
    LOG_DEBUG="true"

COPY --from=docker.pkg.github.com/flownative/bash-library/bash-library:1 /lib $FLOWNATIVE_LIB_PATH

COPY root-files /
COPY root-files/opt/flownative/php/build $PHP_BASE_PATH/build/extensions

RUN /build.sh init \
    && /build.sh prepare \
    && /build.sh build \
    && /build.sh build_extension vips \
    && /build.sh build_extension imagick \
    && /build.sh build_extension yaml \
    && /build.sh build_extension phpredis \
    && /build.sh clean

COPY more-root-files/opt /opt
COPY more-root-files/build.sh /build.sh
COPY more-root-files/entrypoint.sh /entrypoint.sh

RUN /build.sh sshd \
    && /build.sh clean

COPY more-root-files/entrypoint.sh /

USER 1000
EXPOSE 2022 9000 9001

WORKDIR $BEACH_APPLICATION_PATH
ENTRYPOINT [ "/entrypoint.sh" ]
CMD [ "run" ]
