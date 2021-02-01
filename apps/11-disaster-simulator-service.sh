#!/bin/bash

my_dir="$(cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P)"
resource="disaster-simulator-service"
source ${my_dir}/../utils.sh
source ${my_dir}/../env.conf
source ${my_dir}/${resource}/env.conf

token_files="${my_dir}/../*.conf ${my_dir}/${resource}/*.conf"
token_cmd=$(getTokenCmd ${token_files})

if [ $(oc get ns | grep -w ${namespace} | wc -l ) -eq 0 ]; then
    eval "${token_cmd} ${my_dir}/${resource}/project.yaml" | oc apply -f -
fi

# service a/c and rolebinding for ns view
eval "${token_cmd} ${my_dir}/${resource}/disaster-simulator-service-sa.yaml" | oc -n ${namespace} apply -f -
eval "${token_cmd} ${my_dir}/${resource}/disaster-simulator-service-role-binding-sa-view.yaml" | oc -n ${namespace} apply -f -

# application config map
eval "${token_cmd} ${my_dir}/${resource}/app-config.properties" | cat > ${my_dir}/${resource}/app-config-impl.properties

result=$(oc -n ${namespace} get configmap | grep "${application_configmap} " | wc -l)
if [ ${result} -eq 1 ]; then
    oc -n ${namespace} delete configmap ${application_configmap}
fi
oc -n ${namespace} create configmap ${application_configmap} \
    --from-file=app-config.properties=${my_dir}/${resource}/app-config-impl.properties \
    --from-file=LNames.txt=${my_dir}/${resource}/LNames.txt \
    --from-file=FNames.txt=${my_dir}/${resource}/FNames.txt
rm ${my_dir}/${resource}/app-config-impl.properties

# deploy from source
if [ $(oc get ns | grep -w ${namespace-tools} | wc -l ) -eq 0 ]; then
    eval "${token_cmd} ${my_dir}/${resource}/project-tools.yaml" | oc apply -f -
fi
eval "${token_cmd} ${my_dir}/${resource}/disaster-simulator-service-binary-buildconfig.yaml" | oc -n ${namespace_tools} apply -f -
eval "${token_cmd} ${my_dir}/${resource}/disaster-simulator-service-imagestream.yaml" | oc -n ${namespace_tools} apply -f -
eval "${token_cmd} ${my_dir}/${resource}/disaster-simulator-service-imagestream.yaml" | oc -n ${namespace} apply -f -
eval "${token_cmd} ${my_dir}/${resource}/disaster-simulator-service-role-binding-jenkins-edit.yaml" | oc -n ${namespace} apply -f -

github_secret=$(getRandomAscii 32)
token_cmd=$(addTokenCmd "${token_cmd}" "github_secret" "${github_secret}")
generic_secret=$(getRandomAscii 32)
token_cmd=$(addTokenCmd "${token_cmd}" "generic_secret" "${generic_secret}")
eval "${token_cmd} ${my_dir}/${resource}/disaster-simulator-service-pipeline.yaml" | oc -n ${namespace_tools} apply -f -

ocp_domain=$(oc -n openshift-console get route console -o jsonpath='{.spec.host}' | sed "s/console-openshift-console.//g")
token_cmd=$(addTokenCmd "${token_cmd}" "ocp_domain" "${ocp_domain}")
eval "${token_cmd} ${my_dir}/${resource}/disaster-simulator-service.yaml" | oc -n ${namespace} apply -f -
