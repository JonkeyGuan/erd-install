#!/bin/bash

my_dir="$(cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P)"
resource="postgresql"
source ${my_dir}/../utils.sh
source ${my_dir}/../env.conf
source ${my_dir}/${resource}/env.conf

token_files="${my_dir}/../*.conf ${my_dir}/${resource}/*.conf"
token_cmd=$(getTokenCmd ${token_files})

if [ $(oc get ns | grep -w ${namespace} | wc -l ) -eq 0 ]; then
    eval "${token_cmd} ${my_dir}/${resource}/project.yaml" | oc apply -f -
fi

eval "${token_cmd} ${my_dir}/${resource}/postgresql-sa.yaml" | oc -n ${namespace} apply -f -

#wget ${postgresql_init_scripts} -O ${my_dir}/${resource}/sql/${postgresql_init_scripts_file}

result=$(oc -n ${namespace} get configmap ${postgresql_init_configmap} 2>/dev/null| grep ${postgresql_init_configmap} | wc -l)
if [ ${result} -eq 1 ]; then 
    oc -n ${namespace} delete configmap ${postgresql_init_configmap}
fi
oc -n ${namespace} create configmap ${postgresql_init_configmap} --from-file=${my_dir}/${resource}/sql/

result=$(oc -n ${namespace} get secret ${postgresql_credentials_secret} 2>/dev/null| grep ${postgresql_credentials_secret} | wc -l)
if [ ${result} -eq 1 ]; then 
    oc -n ${namespace} delete secret ${postgresql_credentials_secret}
fi
oc -n ${namespace} create secret generic ${postgresql_credentials_secret} \
                    --from-literal=database-user=${postgresql_username} \
                    --from-literal=database-password=${postgresql_password} \
                    --from-literal=database-name=${postgresql_database}

eval "${token_cmd} ${my_dir}/${resource}/postgresql.yaml" | oc -n ${namespace} apply -f -
while true 
do
    result=$(oc -n ${namespace} get dc postgresql -o template='{{.status.availableReplicas}}')
    if [ ${result} -eq 1 ]; then 
        break
    fi
    echo 'Waiting for postgresql is ready.'
    sleep 1
done
