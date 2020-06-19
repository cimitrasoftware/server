#!/bin/sh
# CIMITRA SERVER INSTALL SCRIPT

SCRIPT_NAME=`basename $0`
GET_DIRECTIVE="1"

echo "SCRIPT_NAME = $SCRIPT_NAME"

SCRIPT_NAME_HAS_GET_DIRECTIVE=`echo "${SCRIPT_NAME}" | grep -c "get_"`

if [ $SCRIPT_NAME_HAS_GET_DIRECTIVE = $GET_DIRECTIVE ]
then
GET_DIRECTIVE_NAME=`echo "${SCRIPT_NAME}" | awk -F "get_" '{printf $2}'`
LOCAL_SCRIPT="go_${GET_DIRECTIVE_NAME}"
else
LOCAL_SCRIPT="cimitra_server_install.sh"
fi

set -e

CIMITRA_URI="https://raw.githubusercontent.com/cimitrasoftware/server/master/cimitra_server_install.sh"

curl -LJO --fail --location --progress-bar --output "$LOCAL_SCRIPT" "$CIMITRA_URI"

chmod +x "./$LOCAL_SCRIPT"

./$LOCAL_SCRIPT

