#!/bin/bash

my_dir="$(cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P)"
resource="erd-monitoring"
source ${my_dir}/../utils.sh
source ${my_dir}/../env.conf
source ${my_dir}/${resource}/env.conf

token_files="${my_dir}/../*.conf ${my_dir}/${resource}/*.conf"
token_cmd=$(getTokenCmd ${token_files})

eval "${token_cmd} ${my_dir}/${resource}/namespace.yaml" | oc apply -f -

eval "${token_cmd} ${my_dir}/${resource}/prometheus-monitoring-role.yaml" | oc -n ${namespace_services} apply -f -
eval "${token_cmd} ${my_dir}/${resource}/prometheus-monitoring-role-binding.yaml" | oc -n ${namespace_services} apply -f -

eval "${token_cmd} ${my_dir}/${resource}/kafka-podmonitor.yaml" | oc -n ${namespace_monitoring} apply -f -

eval "${token_cmd} ${my_dir}/${resource}/emergency-response-application-servicemonitor.yaml" | oc -n ${namespace_monitoring} apply -f -
eval "${token_cmd} ${my_dir}/${resource}/emergency-response-actuator-servicemonitor.yaml" | oc -n ${namespace_monitoring} apply -f -

eval "${token_cmd} ${my_dir}/${resource}/incident-priority-service-prometheus-rules.yaml" | oc -n ${namespace_monitoring} apply -f -

eval "${token_cmd} ${my_dir}/${resource}/emergency-response-grafanadashboard.yaml" | oc -n ${namespace_monitoring} apply -f -

eval "${token_cmd} ${my_dir}/${resource}/dw-postgresql-grafanadatasource.yaml" | oc -n ${namespace_monitoring} apply -f -

eval "${token_cmd} ${my_dir}/${resource}/mission-commander-kpis-grafanadashboard.yaml" | oc -n ${namespace_monitoring} apply -f -

token=$(oc sa get-token grafana-serviceaccount -n ${namespace_monitoring})
token_cmd=$(addTokenCmd "${token_cmd}" "token" "${token}")
eval "${token_cmd} ${my_dir}/${resource}/openshift-monitoring-grafanadatasource.yaml" | oc -n ${namespace_monitoring} apply -f -

eval "${token_cmd} ${my_dir}/${resource}/incident-priority-service-dashboard.yaml" | oc -n ${namespace_monitoring} apply -f -

eval "${token_cmd} ${my_dir}/${resource}/kafka-cluster-dashboard.yaml" | oc -n ${namespace_monitoring} apply -f -

eval "${token_cmd} ${my_dir}/${resource}/kafka-connect-dashboard.yaml" | oc -n ${namespace_monitoring} apply -f -
