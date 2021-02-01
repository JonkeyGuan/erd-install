#!/bin/bash

my_dir="$(cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P)"
resource="kafdrop"
source ${my_dir}/../utils.sh
source ${my_dir}/../env.conf
source ${my_dir}/${resource}/env.conf

token_files="${my_dir}/../*.conf ${my_dir}/${resource}/*.conf"
token_cmd=$(getTokenCmd ${token_files})

if [ $(oc get ns | grep -w ${namespace} | wc -l ) -eq 0 ]; then
    eval "${token_cmd} ${my_dir}/${resource}/project.yaml" | oc apply -f -
fi

eval "${token_cmd} ${my_dir}/${resource}/kafdropservice.yaml" | oc -n ${namespace} apply -f -
