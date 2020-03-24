# Beach PHP

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

## Example usage

tbd.

## Configuration

### Logging

By default, the PHP logs are written to STDOUT / STDERR. That way, you
can follow logs by watching container logs with `docker logs` or using a
similar mechanism in Kubernetes or your actual platform.

## Environment variables

### Flow

| Variable Name                         | Type    | Default                   | Description                   |
|:--------------------------------------|:--------|:--------------------------|:------------------------------|
| BEACH_WAIT_FOR_SYNC                   | boolean | false                     |                               |
| BEACH_APPLICATION_USER_SERVICE_ENABLE | boolean | false                     |                               |
| BEACH_FLOW_BASE_CONTEXT               | string  | Production                |                               |
| BEACH_FLOW_BASE_CONTEXT               | string  | Production                |                               |
| BEACH_FLOW_SUB_CONTEXT                | string  | Instance                  |                               |
| BEACH_FLOW_CONTEXT                    | string  | Production/Beach/Instance | (read-only)                   |
| BEACH_ENVIRONMENT_VARIABLES_WHITELIST | string  |                           |                               |

### SSHD

| Variable Name                         | Type    | Default                                                         | Description                                           |
|:--------------------------------------|:--------|:----------------------------------------------------------------|:------------------------------------------------------|
| SSHD_ENABLE                           | boolean | false                                                           | If the SSH daemon should be enabled                   |
| SSHD_BASE_PATH                        | string  | /opt/flownative/sshd                                            | Base path of SSHD (read-only)                         |
| SSHD_HOST_KEYS_PATH                   | string  | /opt/flownative/sshd/etc                                        | Path where to store SSH host keys                     |
| SSHD_AUTHORIZED_KEYS_SERVICE_ENDPOINT | string  | http://beach-controlpanel.beach-system.svc.cluster.local/api/v1 | URL of the Beach SSH authorized keys service endpoint |

### Deprecated

| Variable Name          | Type   | Default | Description            |
|:-----------------------|:-------|:--------|:-----------------------|
| BEACH_PHP_TIMEZONE     | string |         | Sets PHP_DATE_TIMEZONE |
| BEACH_PHP_MEMORY_LIMIT | string |         | Sets PHP_MEMORY_LIMIT  |

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
