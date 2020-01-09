#!/usr/bin/env bash

CLUSTER_VERIFY_NS=cluster-gpu-verify

# Ensure we start in the correct working directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
ROOT_DIR="${SCRIPT_DIR}/.."
cd "${ROOT_DIR}" || exit 1
TESTS_DIR=$ROOT_DIR/tests


job_name=$(cat $TESTS_DIR/cluster-gpu-test-job.yml | grep -A1 metadata | awk '{print $2}')
echo "job_name=$job_name"

name_gpu_node=$(kubectl -n ${CLUSTER_VERIFY_NS} get nodes | grep gpu0 | awk '{print $1}')
echo "number of GPU nodes: $number_gpu_nodes"

total_gpus=$(kubectl -n ${CLUSTER_VERIFY_NS} describe nodes  | grep -A7 Capacity | grep nvidia.com/gpu | awk '{print $2}')
echo "total_gpus=$total_gpus"

echo "Creating sandbox Namespace"
kubectl create ns ${CLUSTER_VERIFY_NS}

echo "updating test yml"
sed -i "s/.*DYNAMIC_PARALLELISM.*/  parallelism: ${total_gpus} # DYNAMIC_PARALLELISM/g" $TESTS_DIR/cluster-gpu-test-job.yml
sed -i "s/.*DYNAMIC_COMPLETIONS.*/  completions: ${total_gpus} # DYNAMIC_COMPLETIONS/g" $TESTS_DIR/cluster-gpu-test-job.yml

echo "executing ..."
kubectl -n ${CLUSTER_VERIFY_NS} create -f $TESTS_DIR/cluster-gpu-test-job.yml > /dev/null
sleep 15

pods_output=$(kubectl -n ${CLUSTER_VERIFY_NS} get pods | awk '$1 ~/nvidia-smi/ && $3 ~/Completed/ {print $1}' )
string_array=($pods_output)
number_pods=${#string_array[@]}

echo "number_pods: ${number_pods}"

if [ $number_pods -lt $total_gpus ]
then
    echo "GPU driver test failed, use 'kubectl -n ${CLUSTER_VERIFY_NS} describe nodes' to check GPU driver status"
    exit 1
fi


# loop through all pod from each node
i=1
while [ $i -le $total_gpus ]; do
    kubectl -n ${CLUSTER_VERIFY_NS} logs -f ${string_array[$k]}
    let i=i+1
done

kubectl delete ns ${CLUSTER_VERIFY_NS}
