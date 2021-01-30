#!/bin/bash

my_dir="$(cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P)"
resource="incident-priority-service"
source ${my_dir}/../utils.sh
source ${my_dir}/../env.conf
source ${my_dir}/${resource}/env.conf

token_files="${my_dir}/../*.conf ${my_dir}/${resource}/*.conf"
token_cmd=$(getTokenCmd ${token_files})

eval "${token_cmd} ${my_dir}/${resource}/project.yaml" | oc apply -f -

# service a/c and rolebinding for ns view
eval "${token_cmd} ${my_dir}/${resource}/incident-priority-service-sa.yaml" | oc -n ${namespace} apply -f -
eval "${token_cmd} ${my_dir}/${resource}/incident-priority-service-role-binding-sa-view.yaml" | oc -n ${namespace} apply -f -

# application config map
eval "${token_cmd} ${my_dir}/${resource}/application-config.yaml" | cat > ${my_dir}/${resource}/application-config-impl.yaml

result=$(oc -n ${namespace} get configmap ${application_configmap} | grep ${application_configmap} | wc -l)
if [ ${result} -eq 1 ]; then
    oc -n ${namespace} delete configmap ${application_configmap}
fi
oc -n ${namespace} create configmap ${application_configmap} \
    --from-file=application-config.yaml=${my_dir}/${resource}/application-config-impl.yaml
rm ${my_dir}/${resource}/application-config-impl.yaml

# logging config map
result=$(oc -n ${namespace} get configmap ${logging_configmap} | grep ${logging_configmap} | wc -l)
if [ ${result} -eq 1 ]; then
    oc -n ${namespace} delete configmap ${logging_configmap}
fi
oc -n ${namespace} create configmap ${logging_configmap} \
    --from-file=logback.xml=${my_dir}/${resource}/logback-dev.xml

# deploy from source
eval "${token_cmd} ${my_dir}/${resource}/project-tools.yaml" | oc apply -f -
eval "${token_cmd} ${my_dir}/${resource}/incident-priority-service-binary-buildconfig.yaml" | oc -n ${namespace_tools} apply -f -
eval "${token_cmd} ${my_dir}/${resource}/incident-priority-service-imagestream.yaml" | oc -n ${namespace_tools} apply -f -
eval "${token_cmd} ${my_dir}/${resource}/incident-priority-service-imagestream.yaml" | oc -n ${namespace} apply -f -
eval "${token_cmd} ${my_dir}/${resource}/incident-priority-service-role-binding-jenkins-edit.yaml" | oc -n ${namespace} apply -f -

github_secret=$(getRandomAscii 32)
token_cmd=$(addTokenCmd "${token_cmd}" "github_secret" "${github_secret}")
generic_secret=$(getRandomAscii 32)
token_cmd=$(addTokenCmd "${token_cmd}" "generic_secret" "${generic_secret}")
eval "${token_cmd} ${my_dir}/${resource}/incident-priority-service-pipeline.yaml" | oc -n ${namespace_tools} apply -f -

eval "${token_cmd} ${my_dir}/${resource}/incident-priority-service.yaml" | oc -n ${namespace} apply -f -
