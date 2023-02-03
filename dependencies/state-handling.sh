#!/bin/bash

trap "exit 1" TERM

# basedir="$( pwd )"
basedir="$( dirname "$( readlink -f "$0" )" )"
export basedir
if [[ -z $AZURE_HTTP_USER_AGENT ]]; then
   stateDir="${basedir}/metering-data"
else
  # When running in Azure Cloudshell, the data should be stored in the file share.
  stateDir="${HOME}/clouddrive/metering-data"
fi
export stateDir
mkdir --parents "${stateDir}"
CONFIG_FILE="${stateDir}/config.json"

if [ ! -f "$CONFIG_FILE" ]; then
    cp "${basedir}/dependencies/0-config-template.json" "${CONFIG_FILE}"
    echo "✏️ You need to configure deployment settings in ${CONFIG_FILE}"
    exit 1
fi

function get-value {
    local key="$1" ;
    local json ;
    
    json="$( cat "${CONFIG_FILE}" )" ;
    echo "${json}" | jq -r "${key}"
}

function get-value-or-fail {
   local json_path="$1";
   local value;

   value="$( get-value "${json_path}" )"

   [[ -z "${value}"  ]] \
   && { echo "✏️ Please configure ${json_path} in file ${CONFIG_FILE}" > /dev/tty ; kill -s TERM $TOP_PID; }

   echo "$value"
}

function put-value { 
    local key="$1" ;
    local variableValue="$2" ;
    local json ;
    json="$( cat "${CONFIG_FILE}" )" ;
    echo "${json}" \
       | jq --arg x "${variableValue}" "${key}=(\$x)" \
       > "${CONFIG_FILE}"
}

function put-json-value { 
    local key="$1" ;
    local variableValue="$2" ;
    local json ;
    json="$( cat "${CONFIG_FILE}" )" ;
    echo "${json}" \
       | jq --arg x "${variableValue}" "${key}=(\$x | fromjson)" \
       > "${CONFIG_FILE}"
}
