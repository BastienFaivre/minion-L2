#!/bin/bash
#===============================================================================
# Author: Bastien Faivre
# Project: EPFL, DCL, Performance and Security Evaluation of Layer 2 Blockchain
#          Systems
# Date: June 2023
# Description: Prepare the hosts and generate the configuration
#===============================================================================

#===============================================================================
# IMPORTS
#===============================================================================

caller_dir=$(pwd)
cd "$(dirname "${0}")"
. ../constants.sh
. ../../scripts/utils.sh

#===============================================================================
# FUNCTIONS
#===============================================================================

#######################################
# Get the usage of the script
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   Writes the usage to stdout
# Returns:
#   None
#######################################
usage() {
  echo 'Usage: $(basename ${0}) <remote hosts file> <number of nodes>'
}

#######################################
# Prepare the hosts for the configuration generation
# Globals:
#   None
# Arguments:
#   $1: number of nodes
#   $2: remote hosts list
# Outputs:
#   None
# Returns:
#   None
#######################################
prepare() {
  trap 'exit 1' ERR
  if ! utils::check_args_ge 2 $#; then
    trap - ERR
    exit 1
  fi
  local number_of_nodes=${1}
  local remote_hosts_list=("${@:2}")
  local number_of_hosts=${#remote_hosts_list[@]}
  local nodes_per_host=$((number_of_nodes / number_of_hosts))
  local remainder=$((number_of_nodes % number_of_hosts))
  local index=0
  local node_to_assign node_list
  declare -a host_node_list
  for remote_host in "${remote_hosts_list[@]}"; do
    IFS=':' read -r host port <<< "${remote_host}"
    nodes_to_assign=${nodes_per_host}
    if [ ${remainder} -gt 0 ]; then
      nodes_to_assign=$((nodes_to_assign + 1))
      remainder=$((remainder - 1))
    fi
    local node_list=''
    for ((i = 0; i < nodes_to_assign; i++)); do
      node_list+="n${index} "
      index=$((index + 1))
    done
    host_node_list+=("${host}:${port}:${node_list}")
  done
  local host port node_list
  for host_node in "${host_node_list[@]}"; do
    host=$(echo "${host_node}" | cut -d: -f1)
    port=$(echo "${host_node}" | cut -d: -f2)
    node_list=$(echo "${host_node}" | cut -d: -f3)
    cmd="./eth-poa/remote/generate-configuration.sh prepare ${node_list}"
    ssh -p ${port} ${host} "${cmd}" &
  done
  wait
  trap - ERR
}

#######################################
# Retrieve the accounts from the hosts
# Globals:
#   None
# Arguments:
#   $1: remote hosts list
# Outputs:
#   None
# Returns:
#   None
#######################################
retrieve_accounts() {
  trap 'exit 1' ERR
  if ! utils::check_args_ge 1 $#; then
    trap - ERR
    exit 1
  fi
  local remote_hosts_list=("${@:1}")
  rm -rf ./tmp
  mkdir -p ./tmp
  mkdir -p ./tmp/network
  for remote_host in "${remote_hosts_list[@]}"; do
    IFS=':' read -r host port <<< "${remote_host}"
    scp -r -P ${port} ${host}:~/${DEPLOY_ROOT}/n* ./tmp/network
  done
  tar -czf ./tmp/network.tar.gz -C ./tmp/network .
  trap - ERR
}

#######################################
# Send the accounts to one host the generate the genesis file
# Globals:
#   None
# Arguments:
#   $1: remote host
# Outputs:
#   None
# Returns:
#   None
#######################################
send_accounts() {
  trap 'exit 1' ERR
  if ! utils::check_args_eq 1 $#; then
    trap - ERR
    exit 1
  fi
  local remote_host=${1}
  local host=$(echo "${remote_host}" | cut -d: -f1)
  local port=$(echo "${remote_host}" | cut -d: -f2)
  scp -P ${port} ./tmp/network.tar.gz ${host}:~/${DEPLOY_ROOT}
  trap - ERR
}

#######################################
# Retrieve the genesis file from the host
# Globals:
#   None
# Arguments:
#   $1: remote host
# Outputs:
#   None
# Returns:
#   None
#######################################
retrieve_configuration() {
  trap 'exit 1' ERR
  if ! utils::check_args_eq 1 $#; then
    trap - ERR
    exit 1
  fi
  local remote_host=${1}
  local host=$(echo "${remote_host}" | cut -d: -f1)
  local port=$(echo "${remote_host}" | cut -d: -f2)
  scp -P ${port} ${host}:~/${NETWORK_ROOT}/genesis.json ./tmp
  ssh -p ${port} ${host} "rm -rf ~/${NETWORK_ROOT}"
  trap - ERR
}

#######################################
# Send the genesis file to the hosts
# Globals:
#   None
# Arguments:
#   $1: remote hosts list
# Outputs:
#   None
# Returns:
#   None
#######################################
send_configuration() {
  trap 'exit 1' ERR
  if ! utils::check_args_ge 1 $#; then
    trap - ERR
    exit 1
  fi
  local remote_hosts_list=("${@:1}")
  for remote_host in "${remote_hosts_list[@]}"; do
    IFS=':' read -r host port <<< "${remote_host}"
    scp -P ${port} ./tmp/genesis.json ${host}:~/${DEPLOY_ROOT} &
  done
  wait
  trap - ERR
}

#######################################
# Retrieve the static nodes file from the hosts
# Globals:
#   None
# Arguments:
#   $1: remote hosts list
# Outputs:
#   None
# Returns:
#   None
#######################################
retrieve_static_nodes() {
  trap 'exit 1' ERR
  if ! utils::check_args_ge 1 $#; then
    trap - ERR
    exit 1
  fi
  local remote_hosts_list=("${@:1}")
  mkdir -p ./tmp/static-nodes
  for remote_host in "${remote_hosts_list[@]}"; do
    IFS=':' read -r host port <<< "${remote_host}"
    scp -P ${port} ${host}:~/${DEPLOY_ROOT}/static-nodes-*.json \
      ./tmp/static-nodes/ &
  done
  wait
  trap - ERR
}

#######################################
# Aggregate the static nodes files
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   None
# Returns:
#   None
#######################################
aggregate_static_nodes() {
  trap 'exit 1' ERR
  echo '[' > ./tmp/static-nodes.json
  local first_entry=true
  local host_ip
  for file in ./tmp/static-nodes/static-nodes-*.json; do
    host_ip=$(echo ${file} | sed 's/.*static-nodes-\(.*\).json/\1/')
    while read -r enode; do
      if [ ${first_entry} = true ]; then
        first_entry=false
      else
        sed -i '$ s/$/,/' ./tmp/static-nodes.json
      fi
      echo -e "\t${enode}" | sed "s/0\.0\.0\.0/${host_ip}/g" \
        >> ./tmp/static-nodes.json
    done < ${file}
  done
  echo ']' >> ./tmp/static-nodes.json
  trap - ERR
}

#######################################
# Send the static nodes file to the hosts
# Globals:
#   None
# Arguments:
#   $1: remote hosts list
# Outputs:
#   None
# Returns:
#   None
#######################################
send_static_nodes() {
  trap 'exit 1' ERR
  if ! utils::check_args_ge 1 $#; then
    trap - ERR
    exit 1
  fi
  local remote_hosts_list=("${@:1}")
  for remote_host in "${remote_hosts_list[@]}"; do
    IFS=':' read -r host port <<< "${remote_host}"
    scp -P ${port} ./tmp/static-nodes.json ${host}:~/${DEPLOY_ROOT} &
  done
}

#===============================================================================
# MAIN
#===============================================================================

if ! utils::check_args_eq 2 $#; then
  usage
  exit 1
fi
remote_hosts_file=$caller_dir/${1}
if [ ! -f ${remote_hosts_file} ]; then
  utils::err "function main(): File ${remote_hosts_file} does not exist."
  exit 1
fi
remote_hosts_file="$(cd "$(dirname ${remote_hosts_file})"; pwd)/\
$(basename "${remote_hosts_file}")"
remote_hosts_list=($(utils::create_remote_hosts_list ${remote_hosts_file}))
number_of_nodes=${2}

trap 'exit 1' ERR

cmd="prepare ${number_of_nodes} ${remote_hosts_list[@]}"
utils::exec_cmd "${cmd}" 'Prepare the hosts'

cmd="retrieve_accounts ${remote_hosts_list[@]}"
utils::exec_cmd "${cmd}" 'Retrieve the accounts'

first_remote_host=${remote_hosts_list[0]}

cmd="send_accounts ${first_remote_host}"
utils::exec_cmd "${cmd}" 'Send the accounts to one host'

cmd='./eth-poa/remote/generate-configuration.sh generate'
utils::exec_cmd_on_remote_hosts "${cmd}" 'Generate the configuration' \
  "${first_remote_host}"

cmd="retrieve_configuration ${first_remote_host}"
utils::exec_cmd "${cmd}" 'Retrieve the configuration'

cmd="send_configuration ${remote_hosts_list[@]}"
utils::exec_cmd "${cmd}" 'Send the configuration to the hosts'

cmd='./eth-poa/remote/generate-configuration.sh setup'
utils::exec_cmd_on_remote_hosts "${cmd}" 'Setup the hosts' \
  "${remote_hosts_list[@]}"

cmd="retrieve_static_nodes ${remote_hosts_list[@]}"
utils::exec_cmd "${cmd}" 'Retrieve the static nodes'

cmd='aggregate_static_nodes'
utils::exec_cmd "${cmd}" 'Aggregate the static nodes'

cmd="send_static_nodes ${remote_hosts_list[@]}"
utils::exec_cmd "${cmd}" 'Send the static nodes to the hosts'

cmd='./eth-poa/remote/generate-configuration.sh finalize'
utils::exec_cmd_on_remote_hosts "${cmd}" 'Finalize the hosts' \
  "${remote_hosts_list[@]}"

trap - ERR
