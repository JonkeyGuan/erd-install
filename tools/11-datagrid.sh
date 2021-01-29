#!/bin/bash

my_dir="$(cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P)"
resource="datagrid"
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
    result=$(oc -n ${namespace} get deploy infinispan-operator 2>/dev/null | grep 1/1 | wc -l)
    if [ ${result} -eq 1 ]; then 
        break
    fi
    echo 'Waiting for datagrid-operator is ready.'
    sleep 1
done

install_plan_name=$(oc -n ${namespace} get InstallPlan | grep datagrid | awk '{print $1}')
clusterrole_name=$(oc -n ${namespace} get installplan ${install_plan_name} -o jsonpath='{.status.plan[?(@.resource.kind=="ClusterRole")].resource.name}')
oc patch clusterrole ${clusterrole_name} --type json -p '[{"op":"remove", "path":"/rules/1"}]'

eval "${token_cmd} ${my_dir}/${resource}/connect_secret.yaml" | oc -n ${namespace} apply -f -

eval "${token_cmd} ${my_dir}/${resource}/datagrid_cr.yaml" | oc -n ${namespace} apply -f -
while true 
do
    result=$(oc -n ${namespace} get statefulset ${datagrid_application_name} 2>/dev/null | grep ${number_of_replicas}/${number_of_replicas} | wc -l)
    if [ ${result} -eq 1 ]; then 
        break
    fi
    echo 'Waiting for ${datagrid_application_name} is ready.'
    sleep 1
done

