ARG PHP_BASE_IMAGE

# -----------------------------------------------------------------------------
# Build php-fpm_exporter for the target architecture.
#
# Upstream has not published a release since v2.2.0 (May 2022), and that
# binary is built with Go 1.17. The master branch only received dependency
# updates since then, so we build a pinned commit of it with a current Go
# toolchain instead of copying the binary from the upstream image.
#
# The stage runs on the build platform and cross-compiles, so no emulation is
# involved.

FROM --platform=$BUILDPLATFORM golang:1-alpine AS php-fpm-exporter-builder

ARG PHP_FPM_EXPORTER_VERSION=0ef3d973d5046059993d90dc32c86f36eab0929f
ARG TARGETOS
ARG TARGETARCH

WORKDIR /src
RUN go mod init php-fpm-exporter-build \
    && go get github.com/hipages/php-fpm_exporter@${PHP_FPM_EXPORTER_VERSION} \
    && CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} \
       go build -ldflags "-X main.commit=${PHP_FPM_EXPORTER_VERSION}" \
       -o /out/php-fpm_exporter github.com/hipages/php-fpm_exporter

# -----------------------------------------------------------------------------
# The actual image

FROM ${PHP_BASE_IMAGE}

ENV BANNER_IMAGE_NAME="Beach PHP" \
    BEACH_APPLICATION_PATH="/application" \
    SUPERVISOR_BASE_PATH="/opt/flownative/supervisor" \
    BEACH_CRON_BASE_PATH="/opt/flownative/beach-cron" \
    SITEMAP_CRAWLER_BASE_PATH="/opt/flownative/sitemap-crawler" \
    SSHD_BASE_PATH="/opt/flownative/sshd" \
    SSHD_ENABLE="false"

USER root

COPY root-files /

COPY --from=blackfire/blackfire:2 /usr/local/bin/blackfire /opt/flownative/php/bin/

COPY --from=php-fpm-exporter-builder /out/php-fpm_exporter /opt/flownative/php/bin/php-fpm-exporter

RUN export FLOWNATIVE_LOG_PATH_AND_FILENAME=/dev/stdout \
    && /build.sh init \
    && /build.sh build \
    && /build.sh clean

USER 1000

EXPOSE 2022 9000 9001 9002

WORKDIR ${BEACH_APPLICATION_PATH}
ENTRYPOINT [ "/entrypoint.sh" ]
CMD [ "run" ]
