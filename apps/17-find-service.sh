#!/bin/bash

my_dir="$(cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P)"
resource="find-service"
source ${my_dir}/../utils.sh
source ${my_dir}/../env.conf
source ${my_dir}/${resource}/env.conf

token_files="${my_dir}/../*.conf ${my_dir}/${resource}/*.conf"
token_cmd=$(getTokenCmd ${token_files})

if [ $(oc get ns | grep -w ${namespace} | wc -l ) -eq 0 ]; then
    eval "${token_cmd} ${my_dir}/${resource}/project.yaml" | oc apply -f -
fi

# service a/c and rolebinding for ns view
eval "${token_cmd} ${my_dir}/${resource}/sa.yaml" | oc -n ${namespace} apply -f -
eval "${token_cmd} ${my_dir}/${resource}/role-binding-sa-view.yaml" | oc -n ${namespace} apply -f -

# application config map
eval "${token_cmd} ${my_dir}/${resource}/application.properties" | cat > ${my_dir}/${resource}/application-impl.properties

result=$(oc -n ${namespace} get configmap | grep "${cm_name} " | wc -l)
if [ ${result} -eq 1 ]; then
    oc -n ${namespace} delete configmap ${cm_name}
fi
oc -n ${namespace} create configmap ${cm_name} \
    --from-file=application.properties=${my_dir}/${resource}/application-impl.properties
rm ${my_dir}/${resource}/application-impl.properties

# deploy from source
if [ $(oc get ns | grep -w ${namespace-tools} | wc -l ) -eq 0 ]; then
    eval "${token_cmd} ${my_dir}/${resource}/project-tools.yaml" | oc apply -f -
fi
eval "${token_cmd} ${my_dir}/${resource}/binary-buildconfig.yaml" | oc -n ${namespace_tools} apply -f -
eval "${token_cmd} ${my_dir}/${resource}/source-imagestream.yaml" | oc -n ${namespace_tools} apply -f -
eval "${token_cmd} ${my_dir}/${resource}/source-imagestream.yaml" | oc -n ${namespace} apply -f -
eval "${token_cmd} ${my_dir}/${resource}/role-binding-jenkins-edit.yaml" | oc -n ${namespace} apply -f -

github_secret=$(getRandomAscii 32)
token_cmd=$(addTokenCmd "${token_cmd}" "github_secret" "${github_secret}")
generic_secret=$(getRandomAscii 32)
token_cmd=$(addTokenCmd "${token_cmd}" "generic_secret" "${generic_secret}")
eval "${token_cmd} ${my_dir}/${resource}/pipeline.yaml" | oc -n ${namespace_tools} apply -f -

#eval "${token_cmd} ${my_dir}/${resource}/service.yaml" | oc -n ${namespace} apply -f -
eval "${token_cmd} ${my_dir}/${resource}/kservice.yaml" | oc -n ${namespace} apply -f -
