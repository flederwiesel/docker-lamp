# syntax=docker/dockerfile:1.4

ARG PHP_VERSION

FROM php:${PHP_VERSION}-apache

COPY docker-php-entrypoint /usr/local/bin/

RUN <<_RUN
	# Install module build deps
	set -eux
	apt-get update
	DEBIAN_FRONTEND=non-interactive \
	apt-get install --yes --no-install-recommends \
		libonig-dev \
		wget

	rm -rf /var/lib/apt/lists/*
_RUN

RUN <<_RUN
	# Install extentions

	for ext in \
		json \
		mbstring \
		pdo_mysql \

	do
		php -m | grep -qxF "$ext" ||
			docker-php-ext-install -j "$(nproc)" "$ext"
	done
_RUN

RUN a2enmod ssl headers

WORKDIR /var/www/html
