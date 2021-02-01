#!/bin/bash

my_dir="$(cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P)"
resource="monitoring"
source ${my_dir}/../utils.sh
source ${my_dir}/../env.conf
source ${my_dir}/${resource}/env.conf

token_files="${my_dir}/../*.conf ${my_dir}/${resource}/*.conf"
token_cmd=$(getTokenCmd ${token_files})

if [ $(oc get ns | grep -w ${namespace} | wc -l ) -eq 0 ]; then
    eval "${token_cmd} ${my_dir}/${resource}/project.yaml" | oc apply -f -
fi

eval "${token_cmd} ${my_dir}/${resource}/og.yaml" | oc -n ${namespace} apply -f -

# Prometheus
eval "${token_cmd} ${my_dir}/${resource}/prometheus-subscription.yaml" | oc -n ${namespace} apply -f -
while true 
do
    result=$(oc -n ${namespace} get deploy prometheus-operator 2>/dev/null | grep 1/1 | wc -l)
    if [ ${result} -eq 1 ]; then 
        break
    fi
    echo 'Waiting for prometheus-operator is ready.'
    sleep 1
done

eval "${token_cmd} ${my_dir}/${resource}/prometheus-serviceaccount.yaml" | oc -n ${namespace} apply -f -

result=$(oc -n ${namespace} get secret ${prometheus_oauth_proxy_secret} 2>/dev/null| grep ${prometheus_oauth_proxy_secret} | wc -l)
if [ ${result} -eq 1 ]; then 
    oc -n ${namespace} delete secret ${prometheus_oauth_proxy_secret}
fi
prometheus_oauth_session=$(getRandomAscii 43 | base64)
oc -n ${namespace} create secret generic ${prometheus_oauth_proxy_secret} --from-literal=session_secret=${prometheus_oauth_session}

eval "${token_cmd} ${my_dir}/${resource}/prometheus-service.yaml" | oc -n ${namespace} apply -f -

eval "${token_cmd} ${my_dir}/${resource}/prometheus-route.yaml" | oc -n ${namespace} apply -f -

ocp_domain=$(oc -n openshift-console get route console -o jsonpath='{.spec.host}' | sed "s/console-openshift-console.//g")
token_cmd=$(addTokenCmd "${token_cmd}" "ocp_domain" "${ocp_domain}")
eval "${token_cmd} ${my_dir}/${resource}/prometheus-cr.yaml" | oc -n ${namespace} apply -f -
while true 
do
    result=$(oc -n ${namespace} get statefulset prometheus-${prometheus_cr_name} 2>/dev/null | grep 1/1 | wc -l)
    if [ ${result} -eq 1 ]; then 
        break
    fi
    echo "Waiting for prometheus-${prometheus_cr_name} is ready."
    sleep 1
done

# Grafana
eval "${token_cmd} ${my_dir}/${resource}/grafana-subscription.yaml" | oc -n ${namespace} apply -f -
while true 
do
    result=$(oc -n ${namespace} get deploy grafana-operator 2>/dev/null | grep 1/1 | wc -l)
    if [ ${result} -eq 1 ]; then 
        break
    fi
    echo 'Waiting for grafana-operator is ready.'
    sleep 1
done

result=$(oc -n ${namespace} get secret ${grafana_oauth_proxy_secret} 2>/dev/null| grep ${grafana_oauth_proxy_secret} | wc -l)
if [ ${result} -eq 1 ]; then 
    oc -n ${namespace} delete secret ${grafana_oauth_proxy_secret}
fi
grafana_oauth_session=$(getRandomAscii 43 | base64)
oc -n ${namespace} create secret generic ${grafana_oauth_proxy_secret} --from-literal=session_secret=${grafana_oauth_session}

eval "${token_cmd} ${my_dir}/${resource}/grafana-datasource.yaml" | oc -n ${namespace} apply -f -

eval "${token_cmd} ${my_dir}/${resource}/grafana-cr.yaml" | oc -n ${namespace} apply -f -
while true 
do
    result=$(oc -n ${namespace} get deploy grafana-deployment 2>/dev/null | grep 1/1 | wc -l)
    if [ ${result} -eq 1 ]; then 
        break
    fi
    echo 'Waiting for grafana-deployment is ready.'
    sleep 1
done

# cluster role
eval "${token_cmd} ${my_dir}/${resource}/get-namespaces-cluster-role.yaml" | oc -n ${namespace} apply -f -

eval "${token_cmd} ${my_dir}/${resource}/get-namespaces-cluster-role-binding.yaml" | oc -n ${namespace} apply -f -

eval "${token_cmd} ${my_dir}/${resource}/grafana-cluster-monitoring-view-crb.yaml" | oc -n ${namespace} apply -f -

