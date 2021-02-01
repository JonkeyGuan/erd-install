#!/bin/bash

my_dir="$(cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P)"
resource="emergency-console"
source ${my_dir}/../utils.sh
source ${my_dir}/../env.conf
source ${my_dir}/${resource}/env.conf

token_files="${my_dir}/../*.conf ${my_dir}/${resource}/*.conf"
token_cmd=$(getTokenCmd ${token_files})

if [ $(oc get ns | grep -w ${namespace} | wc -l ) -eq 0 ]; then
    eval "${token_cmd} ${my_dir}/${resource}/project.yaml" | oc apply -f -
fi

# service a/c
eval "${token_cmd} ${my_dir}/${resource}/emergency-console-sa.yaml" | oc -n ${namespace} apply -f -

# application config map
result=$(oc -n ${namespace} get configmap | grep "${emergency_console_config_configmap} " | wc -l)
if [ ${result} -eq 1 ]; then
    oc -n ${namespace} delete configmap ${emergency_console_config_configmap}
fi
ocp_domain=$(oc -n openshift-console get route console -o jsonpath='{.spec.host}' | sed "s/console-openshift-console.//g")
token_cmd=$(addTokenCmd "${token_cmd}" "ocp_domain" "${ocp_domain}")
oc -n ${namespace} create configmap ${emergency_console_config_configmap} \
    --from-literal=TOKEN="${emergency_console_config_map_token}" \
    --from-literal=POLLING="${emergency_console_config_polling}" \
    --from-literal=KAFKA_HOST="${kafka_bootstrap_address}" \
    --from-literal=KAFKA_GROUP_ID="${kafka_groupid}" \
    --from-literal=KAFKA_TOPIC="${kafka_topic_mission_event},${kafka_topic_responder_location_update},${kafka_topic_incident_event},${kafka_topic_incident_command},${kafka_topic_responder_event},${kafka_topic_responder_command}" \
    --from-literal=INCIDENT="http://${incident_service_application_name}.${namespace}.svc:8080" \
    --from-literal=RESPONDER="http://${responder_service_application_name}.${namespace}.svc:8080" \
    --from-literal=MISSION="http://${mission_service_application_name}.${namespace}.svc:8080" \
    --from-literal=PROCESS_VIEWER="http://${process_viewer_application_name}.${namespace}.svc:8080" \
    --from-literal=RESPONDER_SIMULATOR="http://${responder_simulator_service_application_name}.${namespace}.svc:8080" \
    --from-literal=DISASTER_SIMULATOR="http://${disaster_simulator_service_application_name}.${namespace}.svc:8080" \
    --from-literal=DISASTER_SIMULATOR_ROUTE="http://${project_admin}-disaster-simulator.${ocp_domain}" \
    --from-literal=PRIORITY="http://${incident_priority_service_application_name}.${namespace}.svc:8080" \
    --from-literal=DISASTER="http://${disaster_service_application_name}.${namespace}.svc:8080"

# deploy from source
github_secret=$(getRandomAscii 32)
token_cmd=$(addTokenCmd "${token_cmd}" "github_secret" "${github_secret}")
generic_secret=$(getRandomAscii 32)
token_cmd=$(addTokenCmd "${token_cmd}" "generic_secret" "${generic_secret}")
eval "${token_cmd} ${my_dir}/${resource}/emergency-console-buildconfig.yaml" | oc -n ${namespace} apply -f -
eval "${token_cmd} ${my_dir}/${resource}/emergency-console-imagestream.yaml" | oc -n ${namespace} apply -f -
eval "${token_cmd} ${my_dir}/${resource}/emergency-console.yaml" | oc -n ${namespace} apply -f -
