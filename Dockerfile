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
    BEACH_APPLICATION_PATH=/application \
    LOG_DEBUG=true

COPY --from=docker.pkg.github.com/flownative/bash-library/bash-library:1 /lib $FLOWNATIVE_LIB_PATH

COPY root-files/opt /opt
COPY root-files/build.sh /
COPY extensions $PHP_BASE_PATH/build/extensions

RUN /build.sh init \
    && /build.sh prepare \
    && /build.sh build \
    && /build.sh build_extension vips \
    && /build.sh build_extension imagick \
    && /build.sh build_extension yaml \
    && /build.sh build_extension phpredis

COPY more-root-files/opt /opt
#RUN /build.sh clean

RUN        chown -R root:root "${PHP_BASE_PATH}" \
        && chmod -R g+rwX "${PHP_BASE_PATH}"\
        && chmod 777 "${PHP_BASE_PATH}"/etc\
        && rm -rf \
            /var/cache/* \
            /var/log/* \
            "${PHP_BASE_PATH}/src"

COPY root-files/entrypoint.sh /

USER 1000
EXPOSE 9000 9001

WORKDIR $BEACH_APPLICATION_PATH
ENTRYPOINT [ "/entrypoint.sh" ]
CMD [ "run" ]
