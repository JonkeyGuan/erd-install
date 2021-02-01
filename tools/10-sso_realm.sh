#!/bin/bash

my_dir="$(cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P)"
resource="sso_realm"
source ${my_dir}/../utils.sh
source ${my_dir}/../env.conf
source ${my_dir}/${resource}/env.conf

token_files="${my_dir}/../*.conf ${my_dir}/${resource}/*.conf"
token_cmd=$(getTokenCmd ${token_files})

if [ $(oc get ns | grep -w ${namespace} | wc -l ) -eq 0 ]; then
    eval "${token_cmd} ${my_dir}/${resource}/project.yaml" | oc apply -f -
fi

incident_commander_role_id=$(getRandomAscii 32)
token_cmd=$(addTokenCmd "${token_cmd}" "incident_commander_role_id" "${incident_commander_role_id}")

ocp_domain=$(oc -n openshift-console get route console -o jsonpath='{.spec.host}' | sed "s/console-openshift-console.//g")
token_cmd=$(addTokenCmd "${token_cmd}" "ocp_domain" "${ocp_domain}")

# get token
sso_route_cmd=$(oc get route sso -o jsonpath='{.spec.host}' -n ${namespace_sso})
sso_url="https://${sso_route_cmd}"
sso_admin_user=$(oc -n ${namespace_sso} get secret ${sso_admin_credentials_secret} -o jsonpath='{$.data.ADMIN_USERNAME}' | base64 -d)
sso_admin_password=$(oc -n ${namespace_sso} get secret ${sso_admin_credentials_secret} -o jsonpath='{$.data.ADMIN_PASSWORD}' | base64 -d)
admin_token=$(curl -X POST -H "application/x-www-form-urlencoded" \
    -d "username=${sso_admin_user}&password=${sso_admin_password}&grant_type=password&client_id=admin-cli" \
    ${sso_url}/auth/realms/master/protocol/openid-connect/token -k | jq -r '.access_token') 

# create realm
result=$(curl -X GET -H "Authorization: Bearer ${admin_token}" ${sso_url}/auth/admin/realms/${sso_realm_id} -k \
    | grep error | wc -l)
if [ ${result} -eq 0 ]; then
   curl -X DELETE -H "Authorization: Bearer ${admin_token}" ${sso_url}/auth/admin/realms/${sso_realm_id} -k
fi

eval "${token_cmd} ${my_dir}/${resource}/realm.json" | cat > ${my_dir}/${resource}/${sso_realm_id}.json
curl -X POST -H "Content-Type: application/json" -H "Authorization: Bearer ${admin_token}" \
    -d @${my_dir}/${resource}/${sso_realm_id}.json ${sso_url}/auth/admin/realms -k
rm ${my_dir}/${resource}/${sso_realm_id}.json

# create user
eval "${token_cmd} ${my_dir}/${resource}/incident-commander-user.json" | cat > ${my_dir}/${resource}/incident-commander-user-impl.json
incident_commander_user_id=$(curl -X POST -H "Content-Type: application/json" -H "Authorization: Bearer ${admin_token}" \
    -d @${my_dir}/${resource}/incident-commander-user-impl.json ${sso_url}/auth/admin/realms/${sso_realm_id}/users -k -v 2>&1 | \
    grep Location | sed -e "s/^.*users\///g" | sed -e 's/[^[:print:]]//')
rm ${my_dir}/${resource}/incident-commander-user-impl.json

# add role to user
eval "${token_cmd} ${my_dir}/${resource}/add-role-to-incident-commander.json" | \
    cat > ${my_dir}/${resource}/add-role-to-incident-commander-impl.json
curl -X POST -H "Content-Type: application/json" -H "Authorization: Bearer ${admin_token}" \
    -d @${my_dir}/${resource}/add-role-to-incident-commander-impl.json \
    ${sso_url}/auth/admin/realms/${sso_realm_id}/users/${incident_commander_user_id}/role-mappings/realm -k
rm ${my_dir}/${resource}/add-role-to-incident-commander-impl.json

# create client configmap
sso_realm_certs=$(curl -X GET ${sso_url}/auth/realms/${sso_realm_id}/protocol/openid-connect/certs -k)
sso_realm_certs_modulus=$(echo ${sso_realm_certs}  | jq -r '[.keys[] | select(.kty == "RSA")][0].n' | sed s/-/+/g | sed s/_/\\//g)
sso_realm_certs_exponent=$(echo ${sso_realm_certs}  | jq -r '[.keys[] | select(.kty == "RSA")][0].e')

work_dir=${my_dir}/${resource}
echo ${sso_realm_certs_exponent} | base64 -d > ${work_dir}/exponent.bin
echo '02 03' | xxd -r -p > ${work_dir}/mid-header.bin
echo 'MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA' | base64 -d > ${work_dir}/header.bin
_m=${sso_realm_certs_modulus}
_l=$((${#_m} % 4))
if [ $_l -eq 2 ]; then _s="$_m"'=='
elif [ $_l -eq 3 ]; then _s="$_m"'='
else _s="$_m" ; fi
echo $_s | base64 -d > ${work_dir}/modulus.bin
cat ${work_dir}/header.bin ${work_dir}/modulus.bin ${work_dir}/mid-header.bin ${work_dir}/exponent.bin > ${work_dir}/key.der
openssl pkey -inform der -outform pem -pubin -in ${work_dir}/key.der -out ${work_dir}/key.pem
public_key=$(cat ${work_dir}/key.pem | tr -d "\n" | sed 's/-----BEGIN PUBLIC KEY-----//' | sed 's/-----END PUBLIC KEY-----//' )
rm ${work_dir}/*.bin ${work_dir}/*.der ${work_dir}/*.pem

result=$(oc -n ${namespace} get configmap | grep "${sso_config_configmap} " | wc -l)
if [ ${result} -eq 1 ]; then
    oc -n ${namespace} delete configmap ${sso_config_configmap}
fi
oc -n ${namespace} create configmap ${sso_config_configmap} \
    --from-literal=AUTH_URL=${sso_url}/auth \
    --from-literal=KEYCLOAK=true \
    --from-literal=PUBLIC_KEY=${public_key} \
    --from-literal=REALM=${sso_realm_id} \
    --from-literal=CLIENTID=${sso_js_clientId} \
    --from-literal=VERTX_CLIENTID=${sso_vertx_clientId} \
    --from-literal=VERTX_CLIENT_SECRET=${sso_vertx_client_secret} 
