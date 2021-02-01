#!/bin/bash

my_dir="$(cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P)"
resource="kafka-connect"
source ${my_dir}/../utils.sh
source ${my_dir}/../env.conf
source ${my_dir}/${resource}/env.conf

token_files="${my_dir}/../*.conf ${my_dir}/${resource}/*.conf"
token_cmd=$(getTokenCmd ${token_files})

if [ $(oc get ns | grep -w ${namespace} | wc -l ) -eq 0 ]; then
    eval "${token_cmd} ${my_dir}/${resource}/project.yaml" | oc apply -f -
fi

eval "${token_cmd} ${my_dir}/${resource}/kafka-connect.yaml" | oc -n ${namespace} apply -f -
while true 
do
    result=$(oc -n ${namespace} get deploy ${kafka_connect}-connect 2>/dev/null | grep ${kafka_connect_replicas}/${kafka_connect_replicas} | wc -l)
    if [ ${result} -eq 1 ]; then 
        break
    fi
    echo "Waiting for ${kafka_connect}-connect is ready."
    sleep 1
done
