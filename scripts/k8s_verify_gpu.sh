#!/bin/bash

# job_name is defined in cluster-gpu-test-job.yml file
# Ensure we start in the correct working directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
ROOT_DIR="${SCRIPT_DIR}/.."
cd "${ROOT_DIR}" || exit 1


file_path=$ROOT_DIR/tests
if [ -f $file_path/cluster-gpu-test-job.yml ]; then 
	job_name=$(cat $file_path/cluster-gpu-test-job.yml | grep -A1 metadata | awk '{print $2}')
else
	job_name="cluster-gpu-test-job.yml"
fi

echo "job_name=$job_name"

name_gpu_node=$(kubectl get nodes | grep gpu0 | awk '{print $1}')
number_gpu_nodes=$(kubectl get nodes | grep gpu0 | wc | awk '{print $1}')
echo "number of GPU nodes: $number_gpu_nodes"

i=1
total_gpus=0
while [ $i -le $number_gpu_nodes ];
do
	gpu_in_node=$(kubectl describe nodes gpu0$i | grep -A7 Capacity | grep nvidia.com/gpu | awk '{print $2}')
	printf "Number of GPUs installed in node$i: $gpu_in_node\n"
	let total_gpus=total_gpus+$gpu_in_node
	let i=i+1
done
echo "total_gpus=$total_gpus"
echo "gpu_in_node=$gpu_in_node"

echo ""

kubectl get jobs | grep $job_name &> /dev/null
if [ $? == 0 ]; then
        kubectl delete jobs $job_name > /dev/null
fi

echo "executing ..."
#yaml_file=$file_path/$job_name
#echo "yaml=$yaml_file"
#file_name=$yaml_file.yml
#echo "file_name=$file_name"
#kubectl create -f $file_name > /dev/null
#kubectl create -f ($file_path/$job_name) > /dev/null
kubectl create -f $file_path/cluster-gpu-test-job.yml > /dev/null
sleep 15
#kubectl get pods  > podstatus

pods_output=$(kubectl get pods | awk '$1 ~/nvidia-smi/ && $3 ~/Completed/ {print $1}' )
string_array=($pods_output)
number_pods=${#string_array[@]}

#if [ $number_pods -lt $number_gpu_nodes ]
if [ $number_pods -lt $total_gpus ]
then
  echo "GPU driver test failed, use 'kubectl describe nodes' to check GPU driver status"
  exit 1
fi


# loop through all pod from each node

i=1
while [ $i -le $number_gpu_nodes ]; do
	j=1
	while [ $j -le $gpu_in_node ]; do
		let k=i-1
		#pod$i=${string_array[$k]}
		echo ""
		echo "Node gpu0$i driver is successfully installed:"
		echo "----------------------------------------"
		echo ""
		#kubectl logs -f $pod1
		kubectl logs -f ${string_array[$k]}
#		pod$i=${string_array[$j]}
#		echo "$pod$i"
		let j=j+1
	done
	let i=i+1
done

#pod1=${string_array[0]}
#pod2=${string_array[1]}

## loop through pods

#i=1
#while [ $i -le $number_gpu_nodes ];
#do
#	a=$(kubectl describe nodes gpu0$i | grep -A7 Capacity | grep nvidia.com/gpu | awk '{print $2}')
#	printf "Number of GPUs installed in GPU node$i: $a\n"
#	let i=i+1
#done

#a=$(kubectl describe nodes gpu01 | grep -A7 Capacity | grep nvidia.com/gpu | awk '{print $2}')
#printf "Number of GPUs installed in node1: $a\n"
#b=$(kubectl describe nodes gpu02 | grep -A7 Capacity | grep nvidia.com/gpu | awk '{print $2}')
#printf "Number of GPUs installed in node2: $b\n\n"


#echo "Node gpu01 driver is successfully installed:"
#echo "------------------------"
#echo ""
#kubectl logs -f $pod1
#echo ""
#echo "Node gpu02 driver is successfully installed:"
#echo "------------------------"
#echo "pod2=$pod2"
#kubectl logs -f $pod2

#kubectl delete jobs $job_name > /dev/null

