#!/bin/sh
# CIMITRA SERVER INSTALL SCRIPT

set -e

CIMITRA_URI="https://raw.githubusercontent.com/cimitrasoftware/server/master/cimitra_server_install.sh"

curl -LJO --fail --location --progress-bar --output "cimitra_server_install.sh" "$CIMITRA_URI"

chmod +x "./cimitra_server_install.sh"

./cimitra_server_install.sh

