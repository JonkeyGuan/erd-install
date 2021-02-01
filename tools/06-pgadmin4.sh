#!/bin/bash

my_dir="$(cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P)"
resource="pgadmin4"
source ${my_dir}/../utils.sh
source ${my_dir}/../env.conf
source ${my_dir}/${resource}/env.conf

token_files="${my_dir}/../*.conf ${my_dir}/${resource}/*.conf"
token_cmd=$(getTokenCmd ${token_files})

if [ $(oc get ns | grep -w ${namespace} | wc -l ) -eq 0 ]; then
    eval "${token_cmd} ${my_dir}/${resource}/project.yaml" | oc apply -f -
fi

result=$(oc -n ${namespace} get secret ${pgadmin4_secret} 2>/dev/null| grep ${pgadmin4_secret} | wc -l)
if [ ${result} -eq 1 ]; then 
    oc -n ${namespace} delete secret ${pgadmin4_secret}
fi
oc -n ${namespace} create secret generic ${pgadmin4_secret} \
                    --from-literal=pgadmin4.username=${pgadmin4_username} \
                    --from-literal=pgadmin4.password=${pgadmin4_password} 

eval "${token_cmd} ${my_dir}/${resource}/pgadmin4.yaml" | oc -n ${namespace} apply -f -
while true 
do
    result=$(oc -n ${namespace} get deploy pgadmin4 2>/dev/null | grep 1/1 | wc -l)
    if [ ${result} -eq 1 ]; then 
        break
    fi
    echo 'Waiting for pgadmin4 is ready.'
    sleep 1
done
