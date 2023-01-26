# Beach PHP

[![MIT license](http://img.shields.io/badge/license-MIT-brightgreen.svg)](http://opensource.org/licenses/MIT)
[![Maintenance level: Love](https://img.shields.io/badge/maintenance-%E2%99%A1%E2%99%A1%E2%99%A1-ff69b4.svg)](https://www.flownative.com/en/products/open-source.html)
![](https://github.com/flownative/docker-beach-php/workflows/Build%20Docker%20Image/badge.svg)
![](https://github.com/flownative/docker-beach-php/workflows/Daily%20Releases/badge.svg)

A Docker image providing [PHP-FPM](https://www.php.net/) for Flownative
Beach and Local Beach. Compared to other PHP images, this one is
tailored to run without root privileges. All processes use an
unprivileged user and much work has been put into providing proper
console output and meaningful messages.

![Screenshot with example log output](docs/beach-php-log-example.png
"Example log output")

## tl;dr

```bash
$ docker run flownative/beach-php
```

## Usage

This image can be used in two scenarios:

- as a container as part of
  [Local Beach](https://www.flownative.com/localbeach) or other Docker
  Compose setup
- as a container as part of [Beach](https://www.flownative.com/beach) in
  a Kubernetes setup

You may be able to tweak this image to fit into other setups. Please
make sure you understand the internals of this image before you try to
do so.

## Configuration

### Logging

By default, the PHP logs are written to STDOUT / STDERR. That way, you
can follow logs by watching container logs with `docker logs` or using a
similar mechanism in Kubernetes or your actual platform.

## Environment variables

### Flow

| Variable Name                                   | Type    | Default                   | Description                                                                          |
|:------------------------------------------------|:--------|:--------------------------|:-------------------------------------------------------------------------------------|
| BEACH_WAIT_FOR_SYNC                             | boolean | false                     |                                                                                      |
| BEACH_APPLICATION_USER_SERVICE_ENABLE           | boolean | false                     | If user-defined services (beach-service*.sh) should be enabled                       |
| BEACH_APPLICATION_STARTUP_SCRIPTS_ENABLE        | boolean | true                      | If standard startup scripts (doctrine migrate, resource publish etc.) should be run  |
| BEACH_APPLICATION_CUSTOM_STARTUP_SCRIPTS_ENABLE | boolean | true                      | If custom startup scripts (beach-startup.sh) should be run                           |
| BEACH_FLOW_BASE_CONTEXT                         | string  | Production                | Base context, either "Development" or "Production"                                   |
| BEACH_FLOW_SUB_CONTEXT                          | string  | Instance                  | Sub context                                                                          |
| BEACH_FLOW_CONTEXT                              | string  | Production/Beach/Instance | (read-only) The actual Flow context; pattern: "{…BASE_CONTEXT}/Beach/{…SUB_CONTEXT}" |
| BEACH_ENVIRONMENT_VARIABLES_ALLOW_LIST          | string  |                           | If set, only these environment variables are promoted to the "beach" user's shell    |
| BEACH_CRON_ENABLE                               | boolean | false                     | If user-defined cron-jobs (beach-cron-hourly.sh) should be enabled                   |

### SSHD

| Variable Name                         | Type    | Default                                                         | Description                                           |
|:--------------------------------------|:--------|:----------------------------------------------------------------|:------------------------------------------------------|
| SSHD_ENABLE                           | boolean | false                                                           | If the SSH daemon should be enabled                   |
| SSHD_BASE_PATH                        | string  | /opt/flownative/sshd                                            | Base path of SSHD (read-only)                         |
| SSHD_HOST_KEYS_PATH                   | string  | /opt/flownative/sshd/etc                                        | Path where to store SSH host keys                     |
| SSHD_AUTHORIZED_KEYS_SERVICE_ENDPOINT | string  | http://beach-controlpanel.beach-system.svc.cluster.local/api/v1 | URL of the Beach SSH authorized keys service endpoint |

### PROMETHEUS METRICS

| Variable Name                  | Type    | Default                             | Description                                                        |
|:-------------------------------|:--------|:------------------------------------|:-------------------------------------------------------------------|
| METRICS_PHP_FPM_ENABLE         | boolean | false                               | If PHP-FPM metrics should be exported                              |
| METRICS_PHP_FPM_SCRAPE_URI     | string  | tcp://127.0.0.1:9000/php-fpm-status | FastCGI address pointing to the PHP-FPM status page                |
| METRICS_PHP_FPM_LISTEN_ADDRESS | string  | 127.0.0.1:9002                      | Host and port the PHP-FPM exporter listens to for scraping metrics |
| METRICS_PHP_FPM_TELEMETRY_PATH | string  | /metrics                            | Path at which PHP-FPM exporter listens to for scraping metrics     |

### Blackfire

| Variable Name                      | Type    | Default   | Description                                       |
|:-----------------------------------|:--------|:----------|:--------------------------------------------------|
| BEACH_ADDON_BLACKFIRE_ENABLE       | boolean | false     | Enables the Blackfire probe extension             |
| BEACH_ADDON_BLACKFIRE_SERVER_ID    | string  |           | Server id to authenticate with Blackfire          |
| BEACH_ADDON_BLACKFIRE_SERVER_TOKEN | string  |           | Server token to authenticate with Blackfire       |

### Beach

| Variable Name                    | Type    | Default   | Description                                       |
|:---------------------------------|:--------|:----------|:--------------------------------------------------|
| BEACH_INSTANCE_IDENTIFIER        | string  |           | The Beach instance identifier                     |
| BEACH_INSTANCE_NAME              | string  |           | The Beach instance name                           |
| BEACH_PROJECT_NAME               | string  |           | The Beach project name                            |

### Sitemap Crawler

| Variable Name                     | Type    | Default                           | Description                                                                      |
|:----------------------------------|:--------|:----------------------------------|:---------------------------------------------------------------------------------|
| SITEMAP_CRAWLER_ENABLE            | boolean | false                             | Enables the Sitemap Crawler                                                      |
| SITEMAP_CRAWLER_SITEMAP_URL       | string  | http://localhost:8080/sitemap.xml | URL to retrieve the sitemap from; can be a comma separated list of multiple URLs |
| SITEMAP_CRAWLER_INTERNAL_BASE_URL | string  | http://localhost:8080             | Internal base URL for crawling the site                                          |

### Deprecated

These variables are handled for reasons of backwards-compatibility.
Please avoid using them, as they will be removed once Flownative Beach
has fully migrated to the new configuration options.

| Variable Name          | Type   | Default | Description            |
|:-----------------------|:-------|:--------|:-----------------------|
| BEACH_PHP_TIMEZONE     | string |         | Sets PHP_DATE_TIMEZONE |
| BEACH_PHP_MEMORY_LIMIT | string |         | Sets PHP_MEMORY_LIMIT  |

## Included tools

This image provides a few tools to SSH user, so they have an easier time
debugging typical issues, such as connection problems or
misconfiguration.

The included tools are:

| Name        | Command  | Description                                                  |
|:------------|:---------|:-------------------------------------------------------------|
| vim         | vi / vim | Text editor                                                  |
| cURL        | curl     | Data transfer agent for HTTP(S), FTP and more                |
| MariaDB     | mysql    | MySQL client, including tools like mysqldump and mysqlimport |
| Netcat      | nc       | Universal TCP and UDP tool                                   |
| Ghostscript | gs       | Used for thumbnail rendering in Neos                         |

### Image optimization tools

In order to support image optimization for websites, the following tools
are available:

| Format | Commands                                                                                     |
|:-------|:---------------------------------------------------------------------------------------------|
| GIF    | gifsicle, gifdiff, gifview                                                                   |
| PNG    | optipng, pngcrush, pngquant                                                                  |
| JPEG   | jpegoptim, cjpeg, djpeg, exifautotran, jpegexiforient, jpegtran, rdjpgcom, tjbench, wrjpgcom |
| WebP   | cwebp, dwebp, gif2webp, img2webp, vwebp, webpinfo, webpmux                                   |

## Cron

This image contains a very simple and naïve implementation for running a
script on a regular basis. When the feature is enabled using the
environment variable `BEACH_CRON_ENABLE`, a daemon will check if there's
a script called `/application/beach-cron-hourly.sh` and if it exists,
calls the script once every hour.

Since this type of traditional cron-jobs does not fit very well into
container setups like Kubernetes, this feature is only a temporary
solution.

## SSHD

This image contains SSHD, the [OpenSSH](https://www.openssh.com/) SSH
daemon. The configuration of the SSH server is tailored to [Flownative
Beach](https://www.flownative.com/beach) and won't work with other
environments out of the box.

SSH support is disabled by default and can be enabled by setting the
environment variable `SSHD_ENABLE` to `true`.

In order to run SSHD with an unprivileged user, the daemon is configured
to listen on a non-privileged port (2022).

SSHD is configured to use a custom authorized keys script which
authenticates connecting users. The script passes the Beach instance
identifier to a REST service specified in
`SSHD_AUTHORIZED_KEYS_SERVICE_ENDPOINT` and receives a list of
authorized public keys in return. If the public key of the current
client can be found in that list, access is granted.

Only connections as user "beach" using public key authentication are
accepted. Connections as "root" or with authentication via password are
rejected.

## Security aspects

This image is designed to run as a non-root container. Using an
unprivileged user generally improves the security of an image, but may
have a few side-effects, especially when you try to debug something by
logging in to the container using `docker exec`.

When you are running this image with Docker or in a Kubernetes context,
you can take advantage of the non-root approach by disallowing privilege
escalation:

```yaml
$ docker run flownative/beach-php:7.4 --security-opt=no-new-privileges
```

## Building this image

Build this image with `docker build`. You need to specify the desired
version of `flownative/php`, which this image is derived from:

```bash
docker build \
    --build-arg PHP_BASE_IMAGE=flownative/php:7.4.3 \
    -t flownative/beach-php:7.4.3 .
```
