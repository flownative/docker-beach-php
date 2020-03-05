#!/bin/bash

# Workaround for missing pkg-config support in certain PHP versions
#
# see:      https://bugs.php.net/bug.php?id=76324
# fixed in: https://github.com/php/php-src/commit/2d03197749696ac3f8effba6b7977b0d8729fef3
exec pkg-config "$@" freetype2
