#!/usr/bin/env bash
set -e
## Run curl queries to verify access to API manager and API.
## Get query and security settings from external file.
## This script is for test purposes and doesn't require much error handling.
## install jq

source ./settings.sh

# This will hold current access token obtained by getAccessToken.
ACCESS_TOKEN=
TERM_ID=

set -x

function getAccessToken() {

    # ask for a token
    AT=$(curl --request POST \
              -s \
              --url ${URL_PREFIX}/aa/oauth2/token \
              --header 'accept: application/json' \
              --header 'content-type: application/x-www-form-urlencoded' \
              --data "grant_type=${GRANT_TYPE}&scope=${1}&client_id=${KEY}&client_secret=${SECRET}");

    # extract and squirrel the token away.
    ACCESS_TOKEN=$(echo ${AT} | jq -r '.access_token');

}

function getTerms {
    #set -x
    GT=$(curl --request GET \
         --url "${URL_PREFIX}/Curriculum/SOC/Terms" \
         --header 'accept: application/json' \
         --header "Authorization: Bearer ${ACCESS_TOKEN}" \
         --header "x-ibm-client-id: ${IBM_CLIENT_ID}");
     TERM_ID=$(echo ${GT} | jq -r '.getSOCTermsResponse.Term.TermCode');
}

function getClassesForGivenTerm {

curl --request GET \
         --url "${URL_PREFIX}/aa/CurriculumAdmin/Terms/${TERM_ID}/ClassesWithLMSURL" \
         --header 'accept: application/json' \
         --header "Authorization: Bearer ${ACCESS_TOKEN}" \
         --header "x-ibm-client-id: ${IBM_CLIENT_ID}"
}
##################################
getAccessToken umscheduleofclasses
getTerms
echo "_______________________________________________________________________________________"
getAccessToken curriculumadmin
getClassesForGivenTerm


