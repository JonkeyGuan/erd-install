#!/bin/bash

my_dir="$(cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P)"
resource="process-service"
source ${my_dir}/../utils.sh
source ${my_dir}/../env.conf
source ${my_dir}/${resource}/env.conf

token_files="${my_dir}/../*.conf ${my_dir}/${resource}/*.conf"
token_cmd=$(getTokenCmd ${token_files})

# postgresql for process service
if [ $(oc get ns | grep -w ${process_service_postgresql_namespace} | wc -l ) -eq 0 ]; then
    eval "${token_cmd} ${my_dir}/${resource}/project-postgresql.yaml" | oc apply -f -
fi
eval "${token_cmd} ${my_dir}/${resource}/postgresql-is.yaml" | oc -n ${process_service_postgresql_namespace} apply -f -

result=$(oc -n ${process_service_postgresql_namespace} get configmap | grep "${process_service_postgresql_init_configmap} " | wc -l)
if [ ${result} -eq 1 ]; then
    oc -n ${process_service_postgresql_namespace} delete configmap ${process_service_postgresql_init_configmap}
fi
cp ${my_dir}/${resource}/postgresql/sql/*.sql ${my_dir}/${resource}/postgresql/
oc -n ${process_service_postgresql_namespace} create configmap ${process_service_postgresql_init_configmap} \
    --from-file=${my_dir}/${resource}/postgresql/
rm ${my_dir}/${resource}/postgresql/*.sql

result=$(oc -n ${process_service_postgresql_namespace} get configmap | grep "${process_service_postgresql_configmap} " | wc -l)
if [ ${result} -eq 1 ]; then
    oc -n ${process_service_postgresql_namespace} delete configmap ${process_service_postgresql_configmap}
fi
oc -n ${process_service_postgresql_namespace} create configmap ${process_service_postgresql_configmap} \
    --from-file=${my_dir}/${resource}/postgresql-conf/

database_admin_password=$(getRandomAscii 12)
result=$(oc -n ${process_service_postgresql_namespace} get secret ${process_service_postgresql_credentials_secret} 2>/dev/null| grep ${process_service_postgresql_credentials_secret} | wc -l)
if [ ${result} -eq 1 ]; then
    database_admin_password=$(oc -n ${process_service_postgresql_namespace} get secret ${process_service_postgresql_credentials_secret} -o jsonpath='{.data.database-admin-password}' | base64 -d)
    oc -n ${process_service_postgresql_namespace} delete secret ${process_service_postgresql_credentials_secret}
fi
oc -n ${process_service_postgresql_namespace} create secret generic ${process_service_postgresql_credentials_secret} \
    --from-literal=database-user=${process_service_postgresql_username} \
    --from-literal=database-password=${process_service_postgresql_password} \
    --from-literal=database-name=${process_service_postgresql_database} \
    --from-literal=database-admin-password=${database_admin_password}

eval "${token_cmd} ${my_dir}/${resource}/postgresql.yaml" | oc -n ${process_service_postgresql_namespace} apply -f -
while true 
do
    result=$(oc -n ${process_service_postgresql_namespace} get dc ${process_service_postgresql_service_name} -o template='{{.status.availableReplicas}}')
    if [ ${result} -eq 1 ]; then 
        break
    fi
    echo "Waiting for ${process_service_postgresql_service_name} is ready."
    sleep 1
done

# kafka connector for postgresql
token_cmd=$(addTokenCmd "${token_cmd}" "kafka_connector_db_password" "${database_admin_password}")
eval "${token_cmd} ${my_dir}/${resource}/kafka-connector.yaml" | oc -n ${namespace_kafka_cluster} apply -f -

if [ $(oc get ns | grep -w ${namespace} | wc -l ) -eq 0 ]; then
    eval "${token_cmd} ${my_dir}/${resource}/project.yaml" | oc apply -f -
fi

# service a/c and rolebinding for ns view
eval "${token_cmd} ${my_dir}/${resource}/process-service-sa.yaml" | oc -n ${namespace} apply -f -
eval "${token_cmd} ${my_dir}/${resource}/process-service-role-binding-sa-view.yaml" | oc -n ${namespace} apply -f -

# application config map
eval "${token_cmd} ${my_dir}/${resource}/application.properties" | cat > ${my_dir}/${resource}/application-impl.properties

result=$(oc -n ${namespace} get configmap | grep "${application_configmap} " | wc -l)
if [ ${result} -eq 1 ]; then
    oc -n ${namespace} delete configmap ${application_configmap}
fi
oc -n ${namespace} create configmap ${application_configmap} \
    --from-file=application.properties=${my_dir}/${resource}/application-impl.properties \
    --from-file=jbpm-quartz.properties=${my_dir}/${resource}/jbpm-quartz.properties
rm ${my_dir}/${resource}/application-impl.properties

# logging config map
result=$(oc -n ${namespace} get configmap | grep "${logging_configmap} " | wc -l)
if [ ${result} -eq 1 ]; then
    oc -n ${namespace} delete configmap ${logging_configmap}
fi
oc -n ${namespace} create configmap ${logging_configmap} \
    --from-file=logback.xml=${my_dir}/${resource}/logback-dev.xml

# deploy from source
if [ $(oc get ns | grep -w ${namespace-tools} | wc -l ) -eq 0 ]; then
    eval "${token_cmd} ${my_dir}/${resource}/project-tools.yaml" | oc apply -f -
fi
eval "${token_cmd} ${my_dir}/${resource}/process-service-binary-buildconfig.yaml" | oc -n ${namespace_tools} apply -f -
eval "${token_cmd} ${my_dir}/${resource}/process-service-imagestream.yaml" | oc -n ${namespace_tools} apply -f -
eval "${token_cmd} ${my_dir}/${resource}/process-service-imagestream.yaml" | oc -n ${namespace} apply -f -
eval "${token_cmd} ${my_dir}/${resource}/process-service-role-binding-jenkins-edit.yaml" | oc -n ${namespace} apply -f -

github_secret=$(getRandomAscii 32)
token_cmd=$(addTokenCmd "${token_cmd}" "github_secret" "${github_secret}")
generic_secret=$(getRandomAscii 32)
token_cmd=$(addTokenCmd "${token_cmd}" "generic_secret" "${generic_secret}")
eval "${token_cmd} ${my_dir}/${resource}/process-service-pipeline.yaml" | oc -n ${namespace_tools} apply -f -

eval "${token_cmd} ${my_dir}/${resource}/process-service.yaml" | oc -n ${namespace} apply -f -
