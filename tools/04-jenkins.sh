#!/bin/bash

my_dir="$(cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P)"
resource="jenkins"
source ${my_dir}/../utils.sh
source ${my_dir}/../env.conf
source ${my_dir}/${resource}/env.conf

token_files="${my_dir}/../*.conf ${my_dir}/${resource}/*.conf"
token_cmd=$(getTokenCmd ${token_files})

if [ $(oc get ns | grep -w ${namespace} | wc -l ) -eq 0 ]; then
    eval "${token_cmd} ${my_dir}/${resource}/project.yaml" | oc apply -f -
fi

# ConfigMap
eval "${token_cmd} ${my_dir}/${resource}/jenkins-maven-slave-configmap.yaml" | oc apply -n ${namespace} -f -

# pvc
eval "${token_cmd} ${my_dir}/${resource}/jenkins-maven-slave-pvc.yaml" | oc -n ${namespace} apply -f -

# dc
eval "${token_cmd} ${my_dir}/${resource}/jenkins-persistent.yaml" | oc -n ${namespace} apply -f -

while true 
do
    result=$(oc -n ${namespace} get dc jenkins -o template='{{.status.availableReplicas}}')
    if [ ${result} -eq 1 ]; then 
        break
    fi
    echo 'Waiting for jenkins is ready.'
    sleep 1
done
