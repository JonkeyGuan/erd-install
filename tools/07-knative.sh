#!/bin/bash

my_dir="$(cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P)"
resource="knative"
source ${my_dir}/../utils.sh
source ${my_dir}/../env.conf
source ${my_dir}/${resource}/env.conf

token_files="${my_dir}/../*.conf ${my_dir}/${resource}/*.conf"
token_cmd=$(getTokenCmd ${token_files})

if [ $(oc get ns | grep -w ${knative_eventing_namespace} | wc -l ) -eq 0 ]; then
    eval "${token_cmd} ${my_dir}/${resource}/project-knative-eventing.yaml" | oc apply -f -
fi

if [ $(oc get ns | grep -w ${knative_serving_namespace} | wc -l ) -eq 0 ]; then
    eval "${token_cmd} ${my_dir}/${resource}/project-knative-serving.yaml" | oc apply -f -
fi

# operator
eval "${token_cmd} ${my_dir}/${resource}/subscription.yaml" | oc -n ${knative_operator_namespace} apply -f -
while true 
do
    result=$(oc -n ${knative_operator_namespace} get deploy knative-operator 2>/dev/null | grep 1/1 | wc -l)
    if [ ${result} -eq 1 ]; then 
        break
    fi
    echo 'Waiting for knative-operator is ready.'
    sleep 1
done

while true 
do
    result=$(oc -n ${knative_operator_namespace} get deploy knative-openshift 2>/dev/null | grep 1/1 | wc -l)
    if [ ${result} -eq 1 ]; then 
        break
    fi
    echo 'Waiting for knative-openshift is ready.'
    sleep 1
done

while true 
do
    result=$(oc -n ${knative_operator_namespace} get deploy knative-openshift-ingress 2>/dev/null | grep 1/1 | wc -l)
    if [ ${result} -eq 1 ]; then 
        break
    fi
    echo 'Waiting for knative-openshift-ingress is ready.'
    sleep 1
done

# knative serving
eval "${token_cmd} ${my_dir}/${resource}/knative-serving.yaml" | oc -n ${knative_serving_namespace} apply -f -
while true 
do
    result=$(oc -n ${knative_serving_namespace} get KnativeServing knative-serving -o jsonpath='{.status.conditions[?(@.status=="False")].status}' 2>/dev/null | grep False | wc -l)
    if [ ${result} -eq 0 ]; then 
        break
    fi
    echo 'Waiting for knative-serving is ready.'
    sleep 1
done

# knative eventing
eval "${token_cmd} ${my_dir}/${resource}/knative-eventing.yaml" | oc -n ${knative_eventing_namespace} apply -f -
while true 
do
    result=$(oc -n ${knative_eventing_namespace} get KnativeEventing knative-eventing -o jsonpath='{.status.conditions[?(@.status=="False")].status}' 2>/dev/null | grep False | wc -l)
    if [ ${result} -eq 0 ]; then 
        break
    fi
    echo 'Waiting for knative-eventing is ready.'
    sleep 1
done

# knative kafka
eval "${token_cmd} ${my_dir}/${resource}/knative-kafka.yaml" | oc -n ${knative_eventing_namespace} apply -f -
while true 
do
    result=$(oc -n ${knative_eventing_namespace} get KnativeKafka knative-kafka -o jsonpath='{.status.conditions[?(@.status=="False")].status}' 2>/dev/null | grep False | wc -l)
    if [ ${result} -eq 0 ]; then 
        break
    fi
    echo 'Waiting for knative-kafka is ready.'
    sleep 1
done
