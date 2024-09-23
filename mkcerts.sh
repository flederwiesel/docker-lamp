#!/bin/bash

# Create SSL certificates to be used with apache and MariaDB

set -euo pipefail

# Check dependencies

dpkg -l git jq openssl &>/dev/null ||
{
	cat <<-"EOF" >&2
		Requirements not met!
		Install necessary programs by
		    `apt install git jq openssl`

		EOF

	exit 1
}

readonly SCRIPTDIR=$(realpath "$(dirname "${BASH_SOURCE[0]}")")

[ -d  "$SCRIPTDIR/mkcert" ] ||
	git clone https://github.com/flederwiesel/mkcert.git "$SCRIPTDIR/mkcert"

mkdir -p "${SCRIPTDIR:-.}/ssl/"

# Set defaults, if unset or empty

: "${ROOT_CA_NAME:=$USER-root}"
: "${ROOT_CA_PASSWORD:=********************************}"
: "${INTERMEDIATE_CA_NAME:=$USER}"
: "${INTERMEDIATE_CA_PASSWORD:=************************}"
: "${APACHE_PASSWORD:=****************}"
: "${MARIADB_PASSWORD:=****************}"

[ -f "$SCRIPTDIR/ssl/mkcert-ca-complete.conf.json" ] ||
cat <<EOF > "$SCRIPTDIR/ssl/mkcert-ca-complete.conf.json"
{
	"certs": [
		{
			"name": "$ROOT_CA_NAME",
			"issuer": "$ROOT_CA_NAME",
			"subject": "/C=??/O=none/CN=$ROOT_CA_NAME",
			"ca": "root",
			"dir": "CA/$ROOT_CA_NAME",
			"passwd": "$ROOT_CA_PASSWORD",
			"distcrl": "URI:https://www.example.com/CA/$ROOT_CA_NAME.crl"
		},
		{
			"name": "$INTERMEDIATE_CA_NAME",
			"issuer": "$ROOT_CA_NAME",
			"subject": "/C=??/O=none/CN=$INTERMEDIATE_CA_NAME",
			"ca": "intermediate",
			"dir": "CA/$INTERMEDIATE_CA_NAME",
			"passwd": "$INTERMEDIATE_CA_PASSWORD",
			"distcrl": "URI:https://www.example.com/CA/${INTERMEDIATE_CA_NAME:-$USER}.crl"
		},
		{
			"name": "apache",
			"issuer": "$INTERMEDIATE_CA_NAME",
			"subject": "/C=??/O=none/CN=apache",
			"dir": "",
			"passwd": "$APACHE_PASSWORD",
			"altnames": "DNS.0=apache DNS.1=localhost IP.1=127.0.0.1 IP.2=::1"
		},
		{
			"name": "mariadb",
			"issuer": "${INTERMEDIATE_CA_NAME:-$USER}",
			"subject": "/C=??/O=none/CN=mariadb",
			"dir": "",
			"passwd": "$MARIADB_PASSWORD",
			"altnames": "DNS.0=mariadb DNS.1=localhost IP.1=127.0.0.1 IP.2=::1"
		}
	]
}
EOF

# Check whether to create certificates
certs=()

# Must be in order of creation: root -> intermediate -> user
[ -f "${SCRIPTDIR:-.}/ssl/CA/$ROOT_CA_NAME/certs/$ROOT_CA_NAME.crt" ] || \
	certs+=($ROOT_CA_NAME)
[ -f "${SCRIPTDIR:-.}/ssl/CA/$INTERMEDIATE_CA_NAME/certs/$INTERMEDIATE_CA_NAME.crt" ] || \
	certs+=($INTERMEDIATE_CA_NAME)
[ -f "${SCRIPTDIR:-.}/ssl/certs/apache.crt" ] || certs+=(apache)
[ -f "${SCRIPTDIR:-.}/ssl/certs/mariadb.crt" ] || certs+=(mariadb)

if [[ ${certs[*]} ]]; then
	"${SCRIPTDIR:-.}/mkcert/mkcert-ca-complete.sh" \
		--verbose \
		--config "${SCRIPTDIR:-.}/ssl/mkcert-ca-complete.conf.json" \
		--ssldir "${SCRIPTDIR:-.}/ssl" \
		"${certs[@]}"
fi

mkdir -p "${SCRIPTDIR:-.}/certs/"{apache,mariadb}

cp "${SCRIPTDIR:-.}/ssl/CA/$ROOT_CA_NAME/certs/$ROOT_CA_NAME.crt" "${SCRIPTDIR:-.}/certs/ca-cert.crt"
cp "${SCRIPTDIR:-.}/ssl/private/apache.key" "${SCRIPTDIR:-.}/certs/apache/"
cp "${SCRIPTDIR:-.}/ssl/private/mariadb.key" "${SCRIPTDIR:-.}/certs/mariadb/"
cp "${SCRIPTDIR:-.}/ssl/certs/"apache{,-chain}.crt "${SCRIPTDIR:-.}/certs/apache/"
cp "${SCRIPTDIR:-.}/ssl/certs/"mariadb{,-chain}.crt "${SCRIPTDIR:-.}/certs/mariadb/"

chmod 644 "${SCRIPTDIR:-.}/certs/"*/*
chmod 644 "${SCRIPTDIR:-.}/certs/ca-cert.crt"
