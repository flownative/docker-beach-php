ARG PHP_BASE_IMAGE

FROM ${PHP_BASE_IMAGE}
MAINTAINER Robert Lemke <robert@flownative.com>

LABEL org.label-schema.name="Beach PHP"
LABEL org.label-schema.description="Docker image providing PHP for Beach and Local Beach"
LABEL org.label-schema.vendor="Flownative GmbH"

ENV BANNER_IMAGE_NAME="Beach PHP" \
    BEACH_APPLICATION_PATH="/application" \
    SUPERVISOR_BASE_PATH="/opt/flownative/supervisor" \
    BEACH_CRON_BASE_PATH="/opt/flownative/beach-cron" \
    SSHD_BASE_PATH="/opt/flownative/sshd" \
    SSHD_ENABLE="false"

USER root

COPY root-files /

RUN export FLOWNATIVE_LOG_PATH_AND_FILENAME=/dev/stdout \
    && /build.sh init \
    && /build.sh build \
    && /build.sh clean

USER 1000
EXPOSE 2022 9000 9001

WORKDIR ${BEACH_APPLICATION_PATH}
ENTRYPOINT [ "/entrypoint.sh" ]
CMD [ "run" ]
