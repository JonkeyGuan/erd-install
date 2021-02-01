#!/bin/bash

my_dir="$(cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P)"
resource="nexus"
source ${my_dir}/../utils.sh
source ${my_dir}/../env.conf
source ${my_dir}/${resource}/env.conf

token_files="${my_dir}/../*.conf ${my_dir}/${resource}/*.conf"
token_cmd=$(getTokenCmd ${token_files})

if [ $(oc get ns | grep -w ${namespace} | wc -l ) -eq 0 ]; then
    eval "${token_cmd} ${my_dir}/${resource}/project.yaml" | oc apply -f -
fi

nexus_template=${my_dir}/${resource}/nexus2-persistent-template.yaml
oc process -f ${nexus_template} \
    -p NEXUS_VERSION=${nexus_version} \
    -p VOLUME_CAPACITY=${nexus_pv_capacity} \
    -p MAX_CPU=${nexus_max_cpu} \
    -p MAX_MEMORY=${nexus_max_memory} \
    -p REQUESTED_MEMORY=${nexus_requested_memory} \
    -p REQUESTED_CPU=${nexus_requested_cpu} \
    | oc -n ${namespace} apply -f - 

while true 
do
    result=$(oc -n ${namespace} get dc nexus -o template='{{.status.availableReplicas}}')
    if [ ${result} -eq 1 ]; then 
        break
    fi
    echo 'Waiting for nexus is ready.'
    sleep 1
done

source ${my_dir}/${resource}/nexus2-functions.sh
ocp_domain=$(oc -n openshift-console get route console -o jsonpath='{.spec.host}' | sed "s/console-openshift-console.//g")
nexus_url=http://nexus-${namespace}.${ocp_domain}
add_nexus2_redhat_repos ${nexus_admin_user} ${nexus_admin_password} ${nexus_url}
set_nexus2_repo_write_policy releases ALLOW_WRITE_ONCE ALLOW_WRITE ${nexus_admin_user} ${nexus_admin_password} ${nexus_url}
