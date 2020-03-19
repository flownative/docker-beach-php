# Docker PHP image

![](https://github.com/flownative/docker-beach-php/workflows/Build%20Docker%20Image/badge.svg)
![](https://github.com/flownative/docker-beach-php/workflows/Daily%20Releases/badge.svg)

A Docker image providing [PHP-FPM](https://www.php.net/). Compared to
other PHP images, this one is tailored to run without root privileges.
All processes use an unprivileged user (uid 1000). And much work has
been put into providing proper console output and meaningful messages.

![Screenshot with example log output](docs/beach-php-log-example.png
"Example log output")

## tl;dr

```bash
$ docker run flownative/php
```

## Example usage

Here's an example of a Docker Compose configuration using this image as
a PHP-FPM container. The configuration should give you an idea of how to
integrate the image, but you'll certainly need to provide more code in
order to get it running with your specific application.

For a full-working solution tailored to Neos CMS and Neos Flow, please
have a look at [Local Beach](https://flownative.com/localbeach) instead.

```yaml
version: '3.7'

volumes:
  application:
    name: app
    driver: local

services:
  webserver:
    image: flownative/nginx:3
    ports:
      - "8080"
    volumes:
      - application:/application
    environment:
      - NGINX_PHP_FPM_HOST=app_php.local_beach

  php:
    image: flownative/php:7.4
    volumes:
      - application:/application
    environment:

```

## Configuration

### Logging

By default, the PHP logs are written to STDOUT / STDERR. That way, you
can follow logs by watching container logs with `docker logs` or using a
similar mechanism in Kubernetes or your actual platform.

### Environment variables

| Variable Name                  | Type    | Default                               | Description                                                        |
|:-------------------------------|:--------|:--------------------------------------|:-------------------------------------------------------------------|
| PHP_BASE_PATH                  | string  | /opt/flownative/php                   | Base path for PHP (read-only)                                      |
| PHP_FPM_USER                   | string  | 1000                                  | User id for running PHP (read-only)                                |
| PHP_FPM_GROUP                  | string  | 1000                                  | Group id for running PHP (read-only)                               |
| PHP_FPM_PORT                   | string  | 9000                                  | Port the PHP-FPM process listens to                                |
| PHP_FPM_MAX_CHILDREN           | string  | 20                                    | Maximum number of children to run                                  |

## Security aspects

This image is designed to run as a non-root container. Using an
unprivileged user generally improves the security of an image, but may
have a few side-effects, especially when you try to debug something by
logging in to the container using `docker exec`.

When you are running this image with Docker or in a Kubernetes context,
you can take advantage of the non-root approach by disallowing privilege
escalation:

```yaml
$ docker run flownative/php:7.4 --security-opt=no-new-privileges
```

When you exec into this container running bash, you will notice your
prompt claiming "I have no name!". That's nothing to worry about: The
container runs as a user with uid 1000, but in fact that user does not
even exist.

```
$ docker run -ti --name php --rm flownative/php:7.4 bash
I have no name!@5a0adf17e426:/$ whoami
whoami: cannot find name for user ID 1000
```

## Building this image

Build this image with `docker build`. You need to specify the desired
version for some of the tools as build arguments:

```bash
docker build \
    --build-arg PHP_VERSION=7.4.3 \
    -t flownative/php:latest .
```

Check the latest stable release on the tool's respective websites:

- PHP: https://www.php.net
