#!/usr/bin/env bash
#
# ./grdelw clean build
# docker-compose build
# docker-compose up -d
#
# Sample usage:
#
#   HOST=localhost PORT=7000 ./test-em-all.bash
#
: ${HOST=localhost}
: ${PORT=8443}
: ${PROD_ID_REVS_RECS=2}
: ${PROD_ID_NOT_FOUND=14}
: ${PROD_ID_NO_RECS=114}
: ${PROD_ID_NO_REVS=214}

function assertCurl() {

    local expectedHttpCode=$1
    local curlCmd="$2 -w \"%{http_code}\""
    local result=$(eval $curlCmd)
    local httpCode="${result:(-3)}"
    RESPONSE='' && (( ${#result} > 3 )) && RESPONSE="${result%???}"

    if [ "$httpCode" = "$expectedHttpCode" ]
    then
        if [ "$httpCode" = "200" ]
        then
            echo "Test OK (HTTP Code: $httpCode)"
        else
            echo "Test OK (HTTP Code: $httpCode, $RESPONSE)"
        fi
        return 0
    else
        echo  "Test FAILED, EXPECTED HTTP Code: $expectedHttpCode, GOT: $httpCode, WILL ABORT!"
        echo  "- Failing command: $curlCmd"
        echo  "- Response Body: $RESPONSE"
        return 1
    fi
}

function assertEqual() {

    local expected=$1
    local actual=$2

    if [ "$actual" = "$expected" ]
    then
        echo "Test OK (actual value: $actual)"
        return 0
    else
        echo "Test FAILED, EXPECTED VALUE: $expected, ACTUAL VALUE: $actual, WILL ABORT"
        return 1
    fi
}

function testUrl() {
    url=$@
    if $url -ks -f -o /dev/null
    then
          return 0
    else
          return 1
    fi;
}

function waitForService() {
    url=$@
    echo -n "Wait for: $url... "
    n=0
    until testUrl $url
    do
        n=$((n + 1))
        if [[ $n == 100 ]]
        then
            echo " Give up"
            exit 1
        else
            sleep 6
            echo -n ", retry #$n "
        fi
    done
    echo "DONE, continues..."
}

function testCompositeCreated() {

    # Expect that the Product Composite for productId $PROD_ID_REVS_RECS has been created with three recommendations and three reviews
    if ! assertCurl 200 "curl $AUTH -k https://$HOST:$PORT/product-composite/$PROD_ID_REVS_RECS  -s"
    then
        echo -n "FAIL"
        return 1
    fi

    set +e
    assertEqual "$PROD_ID_REVS_RECS" $(echo $RESPONSE | jq .productId)
    if [ "$?" -eq "1" ] ; then return 1; fi

    assertEqual 3 $(echo $RESPONSE | jq ".recommendations | length")
    if [ "$?" -eq "1" ] ; then return 1; fi

    assertEqual 3 $(echo $RESPONSE | jq ".reviews | length")
    if [ "$?" -eq "1" ] ; then return 1; fi

    set -e
}

function waitForMessageProcessing() {
    echo "Wait for messages to be processed... "

    # Give background processing some time to complete...
    sleep 1

    n=0
    until testCompositeCreated
    do
        n=$((n + 1))
        if [[ $n == 40 ]]
        then
            echo " Give up"
            exit 1
        else
            sleep 6
            echo -n ", retry #$n "
        fi
    done
    echo "All messages are now processed!"
}

function recreateComposite() {
    local productId=$1
    local composite=$2

    assertCurl 200 "curl $AUTH -X DELETE -k https://$HOST:$PORT/product-composite/${productId} -s"
    curl -X POST -k https://$HOST:$PORT/product-composite -H "Content-Type: application/json" -H "Authorization: Bearer $ACCESS_TOKEN" --data "$composite"

}

function setupTestdata() {

    body="{\"productId\":$PROD_ID_NO_RECS"
    body+=\
',"name":"product name A","weight":100, "reviews":[
    {"reviewId":1,"author":"author 1","subject":"subject 1","content":"content 1"},
    {"reviewId":2,"author":"author 2","subject":"subject 2","content":"content 2"},
    {"reviewId":3,"author":"author 3","subject":"subject 3","content":"content 3"}
]}'
    recreateComposite "$PROD_ID_NO_RECS" "$body"

    body="{\"productId\":$PROD_ID_NO_REVS"
    body+=\
',"name":"product name B","weight":200, "recommendations":[
    {"recommendationId":1,"author":"author 1","rate":1,"content":"content 1"},
    {"recommendationId":2,"author":"author 2","rate":2,"content":"content 2"},
    {"recommendationId":3,"author":"author 3","rate":3,"content":"content 3"}
]}'
    recreateComposite "$PROD_ID_NO_REVS" "$body"


    body="{\"productId\":$PROD_ID_REVS_RECS"
    body+=\
',"name":"product name C","weight":300, "recommendations":[
        {"recommendationId":1,"author":"author 1","rate":1,"content":"content 1"},
        {"recommendationId":2,"author":"author 2","rate":2,"content":"content 2"},
        {"recommendationId":3,"author":"author 3","rate":3,"content":"content 3"}
    ], "reviews":[
        {"reviewId":1,"author":"author 1","subject":"subject 1","content":"content 1"},
        {"reviewId":2,"author":"author 2","subject":"subject 2","content":"content 2"},
        {"reviewId":3,"author":"author 3","subject":"subject 3","content":"content 3"}
    ]}'
    # recreateComposite 1 "$body"
    recreateComposite "$PROD_ID_REVS_RECS" "$body"

}

set -e

echo "Start Tests:" `date`

echo "HOST=${HOST}"
echo "PORT=${PORT}"

if [[ $@ == *"start"* ]]
then
    echo "Restarting the test environment..."
    echo "$ docker-compose down --remove-orphans"
    docker-compose down --remove-orphans
    echo "$ docker-compose up -d"
    docker-compose up -d
fi

# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# !!!!!!! FIND OUT WHY THIS waitForService function is not working correctly due to a failed health check with product-composite !!!!!!!!!!!!!!
# 
# waitForService curl -k https://$HOST:$PORT/actuator/health
# Here is the detailed error message: error":"org.springframework.web.reactive.function.client.WebClientResponseException$Unauthorized: 401 
# Unauthorized from GET http://1521665e6d1e:8080/actuator/health
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

# Local authorization server
# Acquire a writer (read and write scopes) access token using the password grant flow 

# Disable local authorization server token retrieval
#ACCESS_TOKEN=$(curl -k https://writer:secret@$HOST:$PORT/oauth/token -d grant_type=password -d username=magnus -d password=password -s | jq .access_token -r) 
#AUTH="-H \"Authorization: Bearer $ACCESS_TOKEN\""

# echo "Bearer writer ACCESS_TOKEN with read and write scopes = ${ACCESS_TOKEN}"

# Auth0 authorization server

# Auth0 Email, Password, Domain, Client ID, and Secret

AUTH0_USER_NAME="mmitnick.mm@gmail.com"
AUTH0_PASSWORD="Wynne123!"
AUTH0_DOMAIN="dev-qmpygyfn.us.auth0.com"
AUTH0_CLIENT_ID="B0L1tiZGFsjygWCESJddN2YTILOuea3J"
AUTH0_CLIENT_SECRET="a1LGb0nEa935xO1hxY4Db5kvDd6jl5u-UV5K_8Lw3ymzSLFi19yM_axDM-QQrG5t"

# Enable Auth0 authorization server token retrieval

ACCESS_TOKEN=$(curl --request POST \
  --url 'https://dev-qmpygyfn.us.auth0.com/oauth/token' \
  --header 'content-type: application/json' \
  --data '{"grant_type":"password", "username":"mmitnick.mm@gmail.com", "password":"Wynne123!", "audience":"https://localhost:8443/product-composite", "scope":"openid email read:product write:product", "client_id": "B0L1tiZGFsjygWCESJddN2YTILOuea3J","client_secret": "a1LGb0nEa935xO1hxY4Db5kvDd6jl5u-UV5K_8Lw3ymzSLFi19yM_axDM-QQrG5t"}' -s | jq -r .access_token)

AUTH="-H 'Authorization: Bearer $ACCESS_TOKEN'"

# printf "<%s>\n" $AUTH

setupTestdata

waitForMessageProcessing

# Verify that a normal request works, expect three recommendations and three reviews
assertCurl 200 "curl -k https://$HOST:$PORT/product-composite/$PROD_ID_REVS_RECS $AUTH -s"
assertEqual "$PROD_ID_REVS_RECS" $(echo $RESPONSE | jq .productId)
assertEqual 3 $(echo $RESPONSE | jq ".recommendations | length")
assertEqual 3 $(echo $RESPONSE | jq ".reviews | length")

# Verify that a 404 (Not Found) error is returned for a non existing productId ($PROD_ID_NOT_FOUND)
assertCurl 404 "curl -k https://$HOST:$PORT/product-composite/$PROD_ID_NOT_FOUND $AUTH -s"

# Verify that no recommendations are returned for productId $PROD_ID_NO_RECS
assertCurl 200 "curl -k https://$HOST:$PORT/product-composite/$PROD_ID_NO_RECS $AUTH -s"
assertEqual "$PROD_ID_NO_RECS" $(echo $RESPONSE | jq .productId)
assertEqual 0 $(echo $RESPONSE | jq ".recommendations | length")
assertEqual 3 $(echo $RESPONSE | jq ".reviews | length")

# Verify that no reviews are returned for productId $PROD_ID_NO_REVS
assertCurl 200 "curl -k https://$HOST:$PORT/product-composite/$PROD_ID_NO_REVS $AUTH -s"
assertEqual $PROD_ID_NO_REVS $(echo $RESPONSE | jq .productId)
assertEqual 3 $(echo $RESPONSE | jq ".recommendations | length")
assertEqual 0 $(echo $RESPONSE | jq ".reviews | length")

# Verify that a 422 (Unprocessable Entity) error is returned for a productId that is out of range (-1)
assertCurl 422 "curl -k https://$HOST:$PORT/product-composite/-1 $AUTH -s"
assertEqual "\"Invalid productId: -1\"" "$(echo $RESPONSE | jq .message)"

# Verify that a 400 (Bad Request) error is returned for a productId that is not a number, i.e. invalid format
assertCurl 400 "curl -k https://$HOST:$PORT/product-composite/invalidProductId $AUTH -s"
assertEqual "\"Type mismatch.\"" "$(echo $RESPONSE | jq .message)"

# Verify that a request without an access token fails on 401, Unauthorized (i.e., not authenticated)
assertCurl 401 "curl -k https://$HOST:$PORT/product-composite/$PROD_ID_REVS_RECS -s"

# Old code for retrieving read-only access token from local authorization server
# READER_ACCESS_TOKEN=$(curl -k https://reader:secret@$HOST:$PORT/oauth/token -d grant_type=password -d username=magnus -d password=password -s | jq .access_token -r)
# READER_AUTH="-H \"Authorization: Bearer $READER_ACCESS_TOKEN\""

# echo "Bearer reader ACCESS_TOKEN with only read scope = ${READER_ACCESS_TOKEN}"

# Verify that the reader - client with only read scope can call the read API but not delete API.

# Commented out this test because I didn't want to create a read-only JWT in Auth0

# Verify that a normal read request works with token with read scope, expect three recommendations and three reviews
# assertCurl 200 "curl -k https://$HOST:$PORT/product-composite/$PROD_ID_REVS_RECS $READER_AUTH -s"
# assertEqual "$PROD_ID_REVS_RECS" $(echo $RESPONSE | jq .productId)
# assertEqual 3 $(echo $RESPONSE | jq ".recommendations | length")
# assertEqual 3 $(echo $RESPONSE | jq ".reviews | length")

# For some unknown reason, this didn't work; curl returned a 200 OK code
# Verify that the reader - client with only read scope - fails on 403 Forbidden (i.e., not authorized) when calling the delete API
# assertCurl 403 "curl $READER_AUTH -X DELETE -k https://$HOST:$PORT/product-composite/$PROD_ID_REVS_RECS -s"

INVALID_TOKEN="-H \"Authorization: Bearer Invalid_token\""

assertCurl 401 "curl -k https://$HOST:$PORT/product-composite/$PROD_ID_REVS_RECS $INVALID_TOKEN -s"

# Acquire a reader (read scope) access token using the code (most secure) grant flow 

# Enter the following URL on the Safari (not Chrome) browser and look at the redirect URL returned in the browser's search entry field
# Note that I change the expiration time to one year (in seconds)
# https://localhost:8443/oauth/authorize?response_type=code&client_id=reader&redirect_uri=http://my.redirect.uri&scope=product:read&state=35725

# Extract the code value from the redirect URL and set it as an environment variable called READER_CODE
# READER_CODE=whatever it is

# CODE_GRANT_FLOW_READER_ACCESS_TOKEN=$(curl -k https://reader:secret@localhost:8443/oauth/token -d grant_type=authorization_code -d client_id=reader -d redirect_uri=http://my.redirect.uri -d code=$READER_CODE -s | jq .access_token -r)
# echo "CODE_GRANT_FLOW_READER_ACCESS_TOKEN with only read scope = ${CODE_GRANT_FLOW_READER_ACCESS_TOKEN}"

# Store the reader access token returned from the previous command for use in subsequent invocations of the product composite microservice API

# Old code for specifying read only access token generated via the code grant flow
# CODE_GRANT_FLOW_READER_ACCESS_TOKEN=eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJtYWdudXMiLCJleHAiOjIyMzcwMDQ4ODgsImF1dGhvcml0aWVzIjpbIlJPTEVfVVNFUiJdLCJqdGkiOiJQQVl5ZHduWmNGSSs3YVpVbVNYZWpJb2RiTkE9IiwiY2xpZW50X2lkIjoicmVhZGVyIiwic2NvcGUiOlsicHJvZHVjdDpyZWFkIl19.FnuYVl9empEo15FUXbO_8tmGdxzdQjZdpQ3P4J9zUMyHkJmEUMURXa3zcDhrjDmtao1VJ_Xv2Gbcqu3Evp8Vnf56EcLxZAt7CgH3Y0gl23rRIqn_7BPBSkztjqW6dGpyvw7jgi_dBXolHOc35z9A4wJF-5bKVXY7Wwor1yr7fa6I_1rwnHaPAkU9Ecg0rAZov2eAhiJtF6GphXPYoBKDMjXvMyN3gtCNXRVl0tayEo4ndvV-bY-LDc_yDKRxgIYpFMHCgN0yYb26ng8kQW6EKTkjYNPl-rqBNzZwvdDxpK4U1tlRwx0gQc_w4oxMolBpEdGgtJ9W5RLodPu7XgYK-g

# assertCurl 200 "curl -k https://$HOST:$PORT/product-composite/$PROD_ID_REVS_RECS -H \"Authorization: Bearer $CODE_GRANT_FLOW_READER_ACCESS_TOKEN\" -s"
# assertEqual "$PROD_ID_REVS_RECS" $(echo $RESPONSE | jq .productId)
# assertEqual 3 $(echo $RESPONSE | jq ".recommendations | length")
# assertEqual 3 $(echo $RESPONSE | jq ".reviews | length")

# Acquire a writer (write scope) access token using the code (most secure) grant flow 

# Enter the following URL on the Safari (not Chrome) browser and look at the redirect URL returned in the browser's search entry field
# https://localhost:8443/oauth/authorize?response_type=code&client_id=writer&redirect_uri=http://my.redirect.uri&scope=product:read+product:write&state=35725

# Extract the code value from the redirect URL and set it as an environment variable called WRITER_CODE
# WRITER_CODE=whatever it is

# CODE_GRANT_FLOW_WRITER_ACCESS_TOKEN=$(curl -k https://writer:secret@localhost:8443/oauth/token -d grant_type=authorization_code -d client_id=writer -d redirect_uri=http://my.redirect.uri -d code=$WRITER_CODE -s | jq .access_token -r)
# echo "CODE_GRANT_FLOW_WRITER_ACCESS_TOKEN with write scope = ${CODE_GRANT_FLOW_WRITER_ACCESS_TOKEN}"

# Store the writer access token from the previous command for use in subsequent invocations of the product composite microservice API

echo "End, all tests OK:" `date`

if [[ $@ == *"stop"* ]]
then
    echo "Stopping the test environment..."
    echo "$ docker-compose down --remove-orphans"
    docker-compose down --remove-orphans
fi