#!/bin/sh
# CIMITRA SERVER INSTALL SCRIPT

set -e

SCRIPT_NAME_HAS_GO_DIRECTIVE=`echo ${SCRIPT_NAME} | grep -c "go_"`

echo "SCRIPT_NAME_HAS_GO_DIRECTIVE = $SCRIPT_NAME_HAS_GO_DIRECTIVE"

CIMITRA_URI="https://raw.githubusercontent.com/cimitrasoftware/server/master/cimitra_server_install.sh"

curl -LJO --fail --location --progress-bar --output "go" "$CIMITRA_URI"

chmod +x "./cimitra_server_install.sh"

./cimitra_server_install.sh

