#!/bin/bash

my_dir="$(cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P)"
resource="amq-streams"
source ${my_dir}/../utils.sh
source ${my_dir}/../env.conf
source ${my_dir}/${resource}/env.conf

token_files="${my_dir}/../*.conf ${my_dir}/${resource}/*.conf"
token_cmd=$(getTokenCmd ${token_files})

eval "${token_cmd} ${my_dir}/${resource}/project.yaml" | oc apply -f -

eval "${token_cmd} ${my_dir}/${resource}/og.yaml" | oc -n ${namespace_amq_streams_operator} apply -f -

eval "${token_cmd} ${my_dir}/${resource}/subscription.yaml" | oc -n ${namespace_amq_streams_operator} apply -f -
while true 
do
    result=$(oc -n ${namespace_amq_streams_operator} get deploy | grep amq-streams 2>/dev/null | grep 1/1 | wc -l)
    if [ ${result} -eq 1 ]; then 
        break
    fi
    echo 'Waiting for amq-streams-operator is ready.'
    sleep 1
done

# Kafka cluster
eval "${token_cmd} ${my_dir}/${resource}/kafka.yaml" | oc -n ${namespace_kafka_cluster} apply -f -
while true 
do
    result=$(oc -n ${namespace_kafka_cluster} get deploy | grep kafka-cluster-entity-operator 2>/dev/null | grep 1/1 | wc -l)
    if [ ${result} -eq 1 ]; then 
        break
    fi
    echo 'Waiting for kafka-cluster-entity-operator is ready.'
    sleep 1
done

while true 
do
    result=$(oc -n ${namespace_kafka_cluster} get deploy | grep kafka-cluster-kafka-exporter 2>/dev/null | grep 1/1 | wc -l)
    if [ ${result} -eq 1 ]; then 
        break
    fi
    echo 'Waiting for kafka-cluster-kafka-exporter is ready.'
    sleep 1
done

# Kafka topic
topicFiles=${my_dir}/${resource}/topics/*.yaml
for topicFile in $topicFiles
do
    eval "${token_cmd} ${topicFile}" | oc -n ${namespace_kafka_cluster} apply -f -
done
