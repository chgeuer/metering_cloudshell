#!/bin/bash

trap "exit 1" TERM
export TOP_PID=$$
source ./dependencies/state-handling.sh

export customer_subscription="724467b5-bee4-484b-bf13-d6a5505d2b51"
export managed_resource_group_name="mrg-chgpnexttry"
hour_in_the_past='-20 hour'
dimensionName="dimension-payg"
quantity=1

customerJson=$( get-value-or-fail ".customers[\"${customer_subscription}\"][\"${managed_resource_group_name}\"]" )

function create_base64_url {
    local base64text="$1"
    echo -n "${base64text}" | sed -E s%=+$%% | sed s%\+%-%g | sed -E s%/%_%g 
}

function json_to_base64 {
    local jsonText="$1"
    create_base64_url "$( echo -n "${jsonText}" | base64 --wrap=0 )"
}

function date_readable {
  local dateTime="$1"
  dateTime="${dateTime//:/-}"
  dateTime="${dateTime/T/--}"
  dateTime="${dateTime/Z/}"
  echo "${dateTime}"
}

# `jq -c -M` gives a condensed/Monochome(no ANSI codes) representation
header="$( echo "{}"                                                   | \
  jq --arg x "JWT"                                           '.typ=$x' | \
  jq --arg x "RS256"                                         '.alg=$x' | \
  jq --arg x "$( get-value-or-fail '.publisher.idp.keyId' )" '.kid=$x' | \
  jq -c -M "." | iconv --from-code=ascii --to-code=utf-8 )"

token_validity_duration="+60 minute"

payload="$( echo "{}" | \
  jq --arg x "$( get-value-or-fail '.publisher.idp.issuer' )"    '.iss=$x'              | \
  jq --arg x "$( echo "${customerJson}" | jq -r '.audience' )"  '.aud=$x'              | \
  jq --arg x "$( echo "${customerJson}" | jq -r '.subject' )"   '.sub=$x'              | \
  jq --arg x "$( date +%s )"                                     '.iat=($x | fromjson)' | \
  jq --arg x "$( date --date="${token_validity_duration}" +%s )" '.exp=($x | fromjson)' | \
  jq -c -M "." | iconv --from-code=ascii --to-code=utf-8 )"

# echo "$(echo "${header}" | jq . ).$(echo "${payload}" | jq . )"

toBeSigned="$( echo -n "$( json_to_base64 "${header}" ).$( json_to_base64 "${payload}" )" | iconv --to-code=ascii )"

hash="$( echo -n "${toBeSigned}" | openssl dgst -sha256 --binary | base64 --wrap=0 )"    

kvAccessToken="$( az account get-access-token --resource "https://vault.azure.net" | jq -r .accessToken )"

# RSASSA-PKCS1-v1_5 using SHA-256 
signature="$( curl \
  --request POST \
  --silent \
  --url "$( get-value-or-fail '.publisher.idp.keyId' )/sign?api-version=7.3" \
  --header 'Content-Type: application/json' \
  --header "Authorization: Bearer ${kvAccessToken}" \
  --data "$( echo "{}" \
       | jq --arg x "RS256" '.alg=$x' \
       | jq --arg x "${hash}" '.value=$x' 
     )" \
  | jq -r '.value' )"
                      
self_issued_jwt="${toBeSigned}.${signature}"

# echo "${self_issued_jwt}" | jq -R 'split(".") | (.[0], .[1]) | @base64d | fromjson'

isv_metering_access_token="$( curl \
  --silent \
  --request POST \
  --url "https://login.microsoftonline.com/$( echo "${customerJson}" | jq -r '.tenantId' )/oauth2/token" \
  --data-urlencode "resource=20e940b3-4c77-4b0b-9a53-9e16a1b010a7"         \
  --data-urlencode "response_type=token" \
  --data-urlencode "grant_type=client_credentials" \
  --data-urlencode "client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer" \
  --data-urlencode "client_id=$( echo "${customerJson}" | jq -r '.uamiClientId' )" \
  --data-urlencode "client_assertion=${self_issued_jwt}" \
  | jq -r ".access_token" )" 

# echo "${isv_metering_access_token}" | jq -R 'split(".") | (.[0], .[1]) | @base64d | fromjson'

# xxd and envsubst missing in Azure Cloud shell
marketplace_metering_request="$( echo "{}" \
  | jq --arg x "$( echo "${customerJson}" | jq -r '.billing.resourceId' )"          '.resourceId=$x' \
  | jq --arg x "$( echo "${customerJson}" | jq -r '.billing.resourceUri' )"         '.resourceUri=$x' \
  | jq --arg x "$( echo "${customerJson}" | jq -r '.planName' )"                    '.planId=$x' \
  | jq --arg x "$( date --utc --date="${hour_in_the_past}" '+%Y-%m-%dT%H:00:00Z' )" '.effectiveStartTime=$x' \
  | jq --arg x "${dimensionName}"                                                   '.dimension=$x'  \
  | jq --arg x "${quantity}"                                                        '.quantity=($x | fromjson)' \
  )"

marketplace_metering_response="$( curl \
  --include --no-progress-meter \
  --request POST \
  --url "https://marketplaceapi.microsoft.com/api/usageEvent?api-version=2018-08-31" \
  --header "Content-Type: application/json" \
  --header "Authorization: Bearer ${isv_metering_access_token}" \
  --data "${marketplace_metering_request}" )" 

dateTime="$( date_readable "$( echo "${marketplace_metering_request}" | jq -r '.effectiveStartTime' )" )"

if [[ -z $AZURE_HTTP_USER_AGENT ]]; then
   stateDirectory="."
else
   stateDirectory="${HOME}/clouddrive"
fi

echo "Using ${stateDirectory}"



directoryForSubmissionTraces="${stateDirectory}/${customer_subscription}/${managed_resource_group_name}/$( echo "${marketplace_metering_request}" | jq -r '.dimension')"
mkdir --parents "${directoryForSubmissionTraces}"

echo "POST /api/usageEvent?api-version=2018-08-31 HTTP/1.1
Host: marketplaceapi.microsoft.com
Content-Type: application/json
Authorization: Bearer ${isv_metering_access_token}
AuthorizationDecodedJSON: Bearer $( echo "${isv_metering_access_token}" | jq -Rc 'split(".") | .[1] | @base64d | fromjson' )

${marketplace_metering_request}

${marketplace_metering_response}" > "${directoryForSubmissionTraces}/${dateTime}-UTC.json"

echo "-REQUEST--------------------------------"
echo "${marketplace_metering_request}" | jq .
echo "-RESPONSE-------------------------------"
echo "${marketplace_metering_response}" | sed '1,/^\r\{0,1\}$/d' | jq .
echo "-TRACE----------------------------------"
echo "Wrote trace to ${directoryForSubmissionTraces}/${dateTime}-UTC.json"
