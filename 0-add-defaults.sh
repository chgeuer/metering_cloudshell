#!/bin/bash

# curl --silent --get --url https://gist.githubusercontent.com/chgeuer/3f1260cc555732a437aed8249a7b84ab/raw/2359f18c591b97e640736b9fce2a51c76f2c5f84/metering.sh > metering.sh

trap "exit 1" TERM
export TOP_PID=$$
source "$( dirname "$( readlink -f "$0" )" )/dependencies/state-handling.sh"

put-value '.publisher.subscriptionId'  "$( az account show | jq -r '.id' )"
put-value '.publisher.aadTenantId'     "$( az account show | jq -r '.tenantId' )"
put-value '.publisher.resourceGroup'   "marketplace-metering-idp-backend"
