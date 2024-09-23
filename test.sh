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
diff -u - <(
	curl -sSL --cacert "${SCRIPTDIR:-.}/certs/ca-cert.crt" https://localhost |
	grep -Ff <(
		cat <<-EOF
			PHP Version ${PHP_VERSION}
			Loaded Extensions:
			    PDO
			    curl
			    date
			    hash
			    iconv
			    json
			    mbstring
			    pdo_mysql
			EOF
	)
) <<-EOF
	PHP Version ${PHP_VERSION}
	Loaded Extensions:
	    PDO
	    curl
	    date
	    hash
	    iconv
	    json
	    mbstring
	    pdo_mysql
	EOF

# Check for mariadb connectivity
docker compose exec --no-TTY mariadb mariadb \
	--user="$MARIADB_USER" \
	--password="$MARIADB_PASSWORD" \
	--skip-column-names <<< "select version();"
# Check for mariadb TLS usage
docker compose exec --no-TTY mariadb mariadb \
	--user="$MARIADB_USER" \
	--password="$MARIADB_PASSWORD" \
	--skip-column-names <<< "SHOW SESSION STATUS LIKE 'Ssl_%';" |
grep "Ssl_version\s*TLSv1.3"

echo -e "\033[32m=== SUCCESS ===\033[m"
