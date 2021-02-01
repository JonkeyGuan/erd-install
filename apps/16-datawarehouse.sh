#!/bin/bash

my_dir="$(cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P)"
resource="datawarehouse"
source ${my_dir}/../utils.sh
source ${my_dir}/../env.conf
source ${my_dir}/${resource}/env.conf

token_files="${my_dir}/../*.conf ${my_dir}/${resource}/*.conf"
token_cmd=$(getTokenCmd ${token_files})

if [ $(oc get ns | grep -w ${namespace} | wc -l ) -eq 0 ]; then
    eval "${token_cmd} ${my_dir}/${resource}/project.yaml" | oc apply -f -
fi

# postgres
eval "${token_cmd} ${my_dir}/${resource}/postgresql-sa.yaml" | oc -n ${namespace} apply -f -

#wget ${postgresql_init_scripts} -O ${my_dir}/${resource}/sql/${postgresql_init_scripts_file}

result=$(oc -n ${namespace} get configmap | grep "${postgresql_init_configmap} " | wc -l)
if [ ${result} -eq 1 ]; then 
    oc -n ${namespace} delete configmap ${postgresql_init_configmap}
fi
oc -n ${namespace} create configmap ${postgresql_init_configmap} --from-file=${my_dir}/${resource}/sql/

result=$(oc -n ${namespace} get secret | grep "${dw_postgresql_credentials_secret} " | wc -l)
if [ ${result} -eq 1 ]; then 
    oc -n ${namespace} delete secret ${dw_postgresql_credentials_secret}
fi
oc -n ${namespace} create secret generic ${dw_postgresql_credentials_secret} \
                    --from-literal=database-user=${dw_postgresql_username} \
                    --from-literal=database-password=${dw_postgresql_password} \
                    --from-literal=database-name=${dw_postgresql_database}

eval "${token_cmd} ${my_dir}/${resource}/postgresql.yaml" | oc -n ${namespace} apply -f -
while true 
do
    result=$(oc -n ${namespace} get dc ${dw_postgresql_application_name} -o template='{{.status.availableReplicas}}')
    if [ ${result} -eq 1 ]; then 
        break
    fi
    echo 'Waiting for ${dw_postgresql_application_name} is ready.'
    sleep 1
done

# Data Grid Caches
eval "${token_cmd} ${my_dir}/${resource}/dw_incident_mapping_cache.yaml" | oc -n ${namespace} apply -f -
eval "${token_cmd} ${my_dir}/${resource}/dw_responder_cache.yaml" | oc -n ${namespace} apply -f -

# KNative Eventing Datawarehouse Warehouse Service
eval "${token_cmd} ${my_dir}/${resource}/datawarehouse-sa.yaml" | oc -n ${namespace} apply -f -
eval "${token_cmd} ${my_dir}/${resource}/datawarehouse-role-binding-sa-view.yaml" | oc -n ${namespace} apply -f -

eval "${token_cmd} ${my_dir}/${resource}/application.properties" | cat > ${my_dir}/${resource}/application-impl.properties

result=$(oc -n ${namespace} get configmap | grep "${cm_name} " | wc -l)
if [ ${result} -eq 1 ]; then
    oc -n ${namespace} delete configmap ${cm_name}
fi
oc -n ${namespace} create configmap ${cm_name} \
    --from-file=application.properties=${my_dir}/${resource}/application-impl.properties
rm ${my_dir}/${resource}/application-impl.properties

eval "${token_cmd} ${my_dir}/${resource}/datawarehouse-binary-buildconfig.yaml" | oc -n ${namespace_tools} apply -f -
eval "${token_cmd} ${my_dir}/${resource}/datawarehouse-source-imagestream.yaml" | oc -n ${namespace_tools} apply -f -
eval "${token_cmd} ${my_dir}/${resource}/datawarehouse-source-imagestream.yaml" | oc -n ${namespace} apply -f -
eval "${token_cmd} ${my_dir}/${resource}/datawarehouse-role-binding-jenkins-edit.yaml" | oc -n ${namespace} apply -f -

github_secret=$(getRandomAscii 32)
token_cmd=$(addTokenCmd "${token_cmd}" "github_secret" "${github_secret}")
generic_secret=$(getRandomAscii 32)
token_cmd=$(addTokenCmd "${token_cmd}" "generic_secret" "${generic_secret}")
eval "${token_cmd} ${my_dir}/${resource}/datawarehouse-pipeline.yaml" | oc -n ${namespace_tools} apply -f -

eval "${token_cmd} ${my_dir}/${resource}/datawarehouse-service.yaml" | oc -n ${namespace} apply -f -
eval "${token_cmd} ${my_dir}/${resource}/kservice.yaml" | oc -n ${namespace} apply -f -
eval "${token_cmd} ${my_dir}/${resource}/ksource.yaml" | oc -n ${namespace} apply -f -
