#!/bin/bash

trap "exit 1" TERM
export TOP_PID=$$
source "$( dirname "$( readlink -f "$0" )" )/dependencies/state-handling.sh"


if [ $# -ne 3 ]; then 
  echo "Specify the customer's subscription id and the managed resource group's name, for example: 

      $0 724467b5-bee4-484b-bf13-d6a5505d2b51 mrg-chgpnexttry
      
  "
  exit 1
fi

export customer_subscription="$1"
export managed_resource_group_name="$2"

value="$( get-value ".customers[\"${customer_subscription}\"][\"${managed_resource_group_name}\"].uamiClientId" )"

if [[ -n "${value}" && "${value}" != "null" ]]; then
   echo "The customer is already onboaded, exiting..." > /dev/tty ; kill -s TERM $TOP_PID; 
fi

uami_name="metering-submission-uami"
idp_aud="api://AzureADTokenExchange"
idp_sub="metering-submission-via-uami from $( get-value-or-fail '.publisher.aadTenantId' )"

uamiDeploymentResult="$( az deployment group create \
  --subscription "${customer_subscription}" \
  --resource-group "${managed_resource_group_name}" \
  --template-file "templates/1-connect-customer-deployments.bicep" \
  --parameters \
      identityName="${uami_name}" \
      sub="${idp_sub}" \
      aud="${idp_aud}" \
      issuerUrl="$( get-value-or-fail '.publisher.idp.issuer' )" \
  --output json 2>/dev/null )"

uamiJson="$( echo "${uamiDeploymentResult}" | jq '.properties.outputs.uami.value' )"

put-value ".customers[\"${customer_subscription}\"][\"${managed_resource_group_name}\"].uamiClientId" "$( echo "${uamiJson}" | jq -r '.client_id' )"
put-value ".customers[\"${customer_subscription}\"][\"${managed_resource_group_name}\"].tenantId"     "$( echo "${uamiJson}" | jq -r '.tenant_id' )"
put-value ".customers[\"${customer_subscription}\"][\"${managed_resource_group_name}\"].subject"      "${idp_sub}"
put-value ".customers[\"${customer_subscription}\"][\"${managed_resource_group_name}\"].audience"     "${idp_aud}"
put-value ".customers[\"${customer_subscription}\"][\"${managed_resource_group_name}\"].uamiName"     "${uami_name}"


# queryByManagedResourceGroup="$( echo 'resources
#   | where type =~ "microsoft.solutions/applications"
#   | where properties.managedResourceGroupId =~ "/subscriptions/$customer_subscription/resourceGroups/$managed_resource_group_name"
#   | extend provisioningState = properties.provisioningState
#   | extend managedResourceGroupId = properties.managedResourceGroupId
#   // extend billing = dynamic({ "resourceUri": id, "resourceId": properties.billingDetails.resourceUsageId }) // does not work
#   | extend billing = parse_json(strcat("{\"resourceUri\": \"", id, "\", \"resourceId\": \"", properties.billingDetails.resourceUsageId, "\"}"))
#   | project managedResourceGroupId, kind, location, provisioningState, plan, billing
#   ' | envsubst '$customer_subscription,$managed_resource_group_name' )"

queryByManagedResourceGroup="$( echo 'resources
  | where type =~ "microsoft.solutions/applications"
  | where properties.managedResourceGroupId =~ "/subscriptions/XXXcustomer_subscription/resourceGroups/XXXmanaged_resource_group_name"
  | extend provisioningState = properties.provisioningState
  | extend managedResourceGroupId = properties.managedResourceGroupId
  // extend billing = dynamic({ "resourceUri": id, "resourceId": properties.billingDetails.resourceUsageId }) // does not work
  | extend billing = parse_json(strcat("{\"resourceUri\": \"", id, "\", \"resourceId\": \"", properties.billingDetails.resourceUsageId, "\"}"))
  | project managedResourceGroupId, kind, location, provisioningState, plan, billing
  ' | sed "s/XXXcustomer_subscription/${customer_subscription}/g" \
    | sed "s/XXXmanaged_resource_group_name/${managed_resource_group_name}/g" \
)"

# List all managed apps of my customers
# az graph query -q "${queryByManagedResourceGroup}" | jq -r '["resourceId","resourceUri"], (.data[].billing | [.resourceId, .resourceUri]) | @tsv'

managedAppDetails="$( az graph query -q "${queryByManagedResourceGroup}" | jq .data[0] )"

put-value \
  ".customers[\"${customer_subscription}\"][\"${managed_resource_group_name}\"].billing.resourceId" \
  "$( echo "${managedAppDetails}" | jq -r '.billing.resourceId' )" 

put-value \
  ".customers[\"${customer_subscription}\"][\"${managed_resource_group_name}\"].billing.resourceUri" \
  "$( echo "${managedAppDetails}" | jq -r '.billing.resourceUri' )" 

put-value \
  ".customers[\"${customer_subscription}\"][\"${managed_resource_group_name}\"].billing.resourceUri" \
  "$( echo "${managedAppDetails}" | jq -r '.billing.resourceUri' )" 

put-value \
  ".customers[\"${customer_subscription}\"][\"${managed_resource_group_name}\"].planName" \
  "$( echo "${managedAppDetails}" | jq -r '.plan.name' )" 

# https://docs.microsoft.com/en-us/azure/active-directory/develop/workload-identity-federation-create-trust
