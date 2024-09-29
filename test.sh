#!/bin/bash

set -euo pipefail

trap '_trap $LINENO' ERR

_trap()
{
	local status=$?
	local lineno=$1

	echo -en "\033[1;31mFAILED\033[m with status \033[1;37;10m$status\033[m"
	echo -en " in \033[36m$0\033[m(\033[1;37m$lineno\033[m):\n> " >&2
	sed -n "${lineno}p" "$0" >&2

	exit $status
}

readonly SCRIPTDIR=$(dirname "${BASH_SOURCE[0]}")

# Set environment variables
if [ -f "$SCRIPTDIR/.env" ]; then
	source "$SCRIPTDIR/.env"
fi

for f in "${COMPOSE_ENV_FILES[@]}"; do
	source "$f"
done

# Check for certificates, don't care about actual content
openssl s_client \
	-connect localhost:443 \
	-showcerts \
	-servername apache \
	-verify_return_error \
	-CAfile "${SCRIPTDIR:-.}/certs/ca-cert.crt" <<< "" |&
sed '/-----BEGIN CERTIFICATE-----/,/-----END CERTIFICATE-----/d; /TLS session ticket/,/^$/d'

# Check for general connectivity
curl --cacert "${SCRIPTDIR:-.}/certs/ca-cert.crt" https://localhost &>/dev/null

# Check for loaded PHP extensions

# Determine whether this is a development image
iid=$(docker compose images apache --quiet)
image=$(docker inspect "$iid" --format "{{index .RepoTags 0}}")

if [[ $image =~ -devel$ ]]; then
	echo "Detected development environment..."
	DEVELOPMENT=true
	# Development image should display errors
	PHP_DISPLAY_ERRORS=On
else
	# Some extensions are only present for development, filter those via
	# SKIP_CHECK_PHPEXT="foo|bar" instead of coding expected output and grep list twice...
	SKIP_CHECK_PHPEXT="mysqli"
	# Production image MUST NOT display errors
	PHP_DISPLAY_ERRORS=Off
fi

docker compose exec apache \
	grep "^display_errors\s*=\s*$PHP_DISPLAY_ERRORS" /usr/local/etc/php/php.ini

diff -u <(
	# Expected output
	sed -r "${SKIP_CHECK_PHPEXT:+/    $SKIP_CHECK_PHPEXT/d}" <<-EOF
		PHP Version ${PHP_VERSION}
		Loaded Extensions:
		    PDO
		    curl
		    date
		    hash
		    iconv
		    json
		    mbstring
		    mysqli
		    pdo_mysql
		EOF
) <(
	# Filtered list from server
	curl -sSL --cacert "${SCRIPTDIR:-.}/certs/ca-cert.crt" https://localhost |
	grep -Ff <(
		sed -r "${SKIP_CHECK_PHPEXT:+/    $SKIP_CHECK_PHPEXT/d}" <<-EOF
			PHP Version ${PHP_VERSION}
			Loaded Extensions:
			    PDO
			    curl
			    date
			    hash
			    iconv
			    json
			    mbstring
			    mysqli
			    pdo_mysql
			EOF
	)
)

# Check mariadb login - apache has mariadb installed only development environment

for service in ${DEVELOPMENT:+apache} mariadb
do
	# Check for mariadb connectivity
	docker compose exec --no-TTY "$service" mariadb \
		--user="$MARIADB_USER" \
		--password="$MARIADB_PASSWORD" \
		--skip-column-names <<< "select version();"

	# Check for mariadb TLS usage
	docker compose exec --no-TTY "$service" mariadb \
		--user="$MARIADB_USER" \
		--password="$MARIADB_PASSWORD" \
		--skip-column-names <<< "SHOW SESSION STATUS LIKE 'Ssl_%';" |
	grep "Ssl_version\s*TLSv1.3"
done

# Check phpMyAdmin running on port 8443

if [[ ${DEVELOPMENT:-} ]]; then
	curl -sSL --cacert "${SCRIPTDIR:-.}/certs/ca-cert.crt" https://localhost:8443 |
	grep -o "<title>localhost:8443 / mariadb | phpMyAdmin.*</title>"

	curl -sSL --cacert "${SCRIPTDIR:-.}/certs/ca-cert.crt" https://localhost:8443 |
	grep -o "logged_in:true"
fi

if [ -t 1 ]; then
	echo -e "\033[32m=== SUCCESS ===\033[m"
fi
