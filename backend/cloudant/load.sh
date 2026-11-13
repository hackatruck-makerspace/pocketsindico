#!/bin/bash
# Usage: CLOUDANT_URL=https://xxx.cloudantnosqldb.appdomain.cloud CLOUDANT_API_KEY=... ./cloudant/load.sh
set -e
DB=${CLOUDANT_DATABASE:-condominio_db}
TOKEN=$(curl -s -X POST https://iam.cloud.ibm.com/identity/token -H 'Content-Type: application/x-www-form-urlencoded' \
  -d "grant_type=urn:ibm:params:oauth:grant-type:apikey&apikey=$CLOUDANT_API_KEY" | python3 -c "import sys,json;print(json.load(sys.stdin)['access_token'])")
H=(-H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json")
curl -s -X PUT "${H[@]}" "$CLOUDANT_URL/$DB"; echo
curl -s -X POST "${H[@]}" "$CLOUDANT_URL/$DB/_bulk_docs" -d @cloudant/seeds/_bulk_docs.json; echo
for f in cloudant/indexes/*.json; do curl -s -X POST "${H[@]}" "$CLOUDANT_URL/$DB/_index" -d @$f; echo; done
