#!/bin/sh
# CIMITRA SERVER INSTALL SCRIPT
# Author, Tay Kratzer tay@cimitra.com

set -e

CIMITRA_URI="https://raw.githubusercontent.com/cimitrasoftware/server/master/cimitra_server_install.sh"

curl -LJO --fail --location --progress-bar --output "go" "$CIMITRA_URI"

chmod +x "./cimitra_server_install.sh"

./cimitra_server_install.sh

