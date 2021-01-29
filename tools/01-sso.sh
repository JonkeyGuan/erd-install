#!/bin/bash

my_dir="$(cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P)"
resource="sso"
source ${my_dir}/../utils.sh
source ${my_dir}/../env.conf
source ${my_dir}/${resource}/env.conf

token_files="${my_dir}/../*.conf ${my_dir}/${resource}/*.conf"
token_cmd=$(getTokenCmd ${token_files})

eval "${token_cmd} ${my_dir}/${resource}/project.yaml" | oc apply -f -

eval "${token_cmd} ${my_dir}/${resource}/og.yaml" | oc -n ${namespace} apply -f -

eval "${token_cmd} ${my_dir}/${resource}/subscription.yaml" | oc -n ${namespace} apply -f -
while true 
do
    result=$(oc -n ${namespace} get deploy keycloak-operator 2>/dev/null | grep 1/1 | wc -l)
    if [ ${result} -eq 1 ]; then 
        break
    fi
    echo 'Waiting for keycloak-operator is ready.'
    sleep 1
done

eval "${token_cmd} ${my_dir}/${resource}/cr.yaml" | oc -n ${namespace} apply -f -
while true 
do
    result=$(oc -n ${namespace} get statefulset keycloak 2>/dev/null | grep 1/1 | wc -l)
    if [ ${result} -eq 1 ]; then 
        break
    fi
    echo 'Waiting for keycloak is ready.'
    sleep 1
done

eval "${token_cmd} ${my_dir}/${resource}/route.yaml" | oc -n ${namespace} apply -f -
