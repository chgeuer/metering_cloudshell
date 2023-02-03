#!/bin/bash

trap "exit 1" TERM
export TOP_PID=$$
source "$( dirname "$( readlink -f "$0" )" )/dependencies/state-handling.sh"

query='resources
  | where type =~ "microsoft.solutions/applications"
  | extend provisioningState = properties.provisioningState
  | extend managedResourceGroupName = substring(properties.managedResourceGroupId, 1 + indexof(properties.managedResourceGroupId, match = "/", start = 0, length = -1, occurrence = 4))
  | extend managedAppId = id
  | project subscriptionId, managedResourceGroupName, managedAppId
  '

# List all managed apps of my customers
az graph query -q "${query}" | jq -r '["subscription", "managedResourceGroup", "managedApp"], (.data[] | [.subscriptionId, .managedResourceGroupName, .managedAppId]) | @tsv'
