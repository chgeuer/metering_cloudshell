#!/bin/bash

if [[ -z $AZURE_HTTP_USER_AGENT ]]; then
   stateDirectory="."
else
   stateDirectory="${HOME}/clouddrive"
fi

echo "Using ${stateDirectory}"


echo "-$1 hour"
