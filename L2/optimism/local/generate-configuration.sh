#!/bin/bash
#===============================================================================
# Author: Bastien Faivre
# Project: EPFL, DCL, Performance and Security Evaluation of Layer 2 Blockchain
#          Systems
# Date: August 2023
# Description: Generate configuration and setup the hosts
#===============================================================================

#===============================================================================
# IMPORTS
#===============================================================================

caller_dir=$(pwd)
cd "$(dirname "${0}")"
. ../constants.sh
. ../../../scripts/utils.sh

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
  echo 'Usage: $(basename ${0}) <remote hosts file> <L1 master account file>'
  echo 'Note: all provided remote hosts should have a local L1 node running '\
'and accessible via http://localhost:8545'
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
    cmd="./L2/optimism/remote/generate-configuration.sh prepare ${node_list}"
    ssh -p ${port} ${host} "${cmd}" &
  done
  wait
  trap - ERR
}

#######################################
# Retrieve the static nodes from the hosts
# Globals:
#   None
# Arguments:
#   $@: remote hosts list
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
  rm -rf ./tmp
  mkdir -p ./tmp
  mkdir -p ./tmp/static-nodes
  for remote_host in "${remote_hosts_list[@]}"; do
    IFS=':' read -r host port <<< "${remote_host}"
    scp -P ${port} ${host}:${DEPLOY_ROOT}/static-nodes-local.txt \
      ./tmp/static-nodes/static-nodes-${host}-${port}.txt
    cat ./tmp/static-nodes/static-nodes-${host}-${port}.txt | tr '\n' ',' \
      >> ./tmp/static-nodes.txt
  done
  sed -i 's/.$//' ./tmp/static-nodes.txt
  local first_remote_host=${remote_hosts_list[0]}
  host=$(echo ${first_remote_host} | cut -d':' -f1)
  port=$(echo ${first_remote_host} | cut -d':' -f2)
  scp -P ${port} ${host}:${DEPLOY_ROOT}/sequencer-url ./tmp/sequencer-url
  trap - ERR
}

#######################################
# Send the static nodes to the hosts
# Globals:
#   None
# Arguments:
#   $@: remote hosts list
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
    scp -P ${port} ./tmp/static-nodes.txt ./tmp/sequencer-url \
      ${host}:${DEPLOY_ROOT} &
  done
  wait
  trap - ERR
}

#######################################
# Retrieve the accounts from the host
# Globals:
#   None
# Arguments:
#   $1: remote host
# Outputs:
#   None
# Returns:
#   None
#######################################
retrieve_accounts() {
  trap 'exit 1' ERRd
  if ! utils::check_args_eq 1 $#; then
    trap - ERR
    exit 1
  fi
  local remote_host=${1}
  local host=$(echo ${remote_host} | cut -d':' -f1)
  local port=$(echo ${remote_host} | cut -d':' -f2)
  mkdir -p ./tmp/accounts
  scp -P ${port} ${host}:${DEPLOY_ROOT}/accounts/* ./tmp/accounts
  trap - ERR
}

#######################################
# Retrieve the configuration from the host
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
  local host=$(echo ${remote_host} | cut -d':' -f1)
  local port=$(echo ${remote_host} | cut -d':' -f2)
  scp -P ${port} ${host}:${INSTALL_FOLDER}/optimism/packages/contracts-bedrock/\
L2OutputOracleProxy_address ./tmp/L2OutputOracleProxy_address
  scp -P ${port} ${host}:${INSTALL_FOLDER}/optimism/packages/contracts-bedrock/\
L1StandardBridgeProxy_address ./tmp/L1StandardBridgeProxy_address
  scp -P ${port} ${host}:${INSTALL_FOLDER}/optimism/op-node/genesis.json \
    ./tmp/genesis.json
  scp -P ${port} ${host}:${INSTALL_FOLDER}/optimism/op-node/rollup.json \
    ./tmp/rollup.json
  trap - ERR
}

#######################################
# Send the configuration to the hosts
# Globals:
#   None
# Arguments:
#   $@: remote hosts list
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
    scp -P ${port} ./tmp/genesis.json ./tmp/rollup.json \
      ./tmp/L2OutputOracleProxy_address ${host}:${DEPLOY_ROOT} &
  done
  wait
  trap - ERR
}

#===============================================================================
# MAIN
#===============================================================================

if ! utils::check_args_eq 4 $#; then
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
l1_master_account_file=$caller_dir/${2}
l1_master_account_private_key=$(cat ${l1_master_account_file} | cut -d':' -f2)

trap 'exit 1' ERR

# TODO: uncomment
# remote_hosts_ip_list=()
# for remote_host in ${remote_hosts_list[@]}; do
#   remote_hosts_ip_list+=($(utils::extract_ip_address ${remote_host}))
# done
# TODO: remove
remote_hosts_ip_list=('192.168.201.7' '192.168.201.8' '192.168.201.9' \
'192.168.201.10' '192.168.201.11')

first_remote_host=${remote_hosts_list[0]}

cmd="./L2/optimism/remote/generate-configuration.sh generate "\
"${l1_master_account_private_key} ${remote_hosts_ip_list[@]}"
utils::exec_cmd_on_remote_hosts "${cmd}" 'Generate the configuration' \
  "${first_remote_host}"

# cmd="prepare ${number_of_nodes} ${remote_hosts_list[@]}"
# utils::exec_cmd "${cmd}" 'Prepare the hosts'

# cmd="retrieve_static_nodes ${remote_hosts_list[@]}"
# utils::exec_cmd "${cmd}" 'Retrieve static nodes'

# cmd="send_static_nodes ${remote_hosts_list[@]}"
# utils::exec_cmd "${cmd}" 'Send static nodes'

# first_remote_host=${remote_hosts_list[0]}

# cmd='./L2/optimism/remote/generate-configuration.sh generate-keys '\
# "${l1_node_url} ${l1_master_account_private_key}"
# utils::exec_cmd_on_remote_hosts "${cmd}" 'Generate and fund accounts' \
#   "${first_remote_host}"

# cmd="retrieve_accounts ${first_remote_host}"
# utils::exec_cmd "${cmd}" 'Retrieve accounts'

# cmd='./L2/optimism/remote/generate-configuration.sh configure-network '\
# "${l1_node_url}"
# utils::exec_cmd_on_remote_hosts "${cmd}" 'Configure network' \
#   "${first_remote_host}"

# cmd='./L2/optimism/remote/generate-configuration.sh deploy-L1-contracts '\
# "${l1_node_url}"
# utils::exec_cmd_on_remote_hosts "${cmd}" 'Deploy L1 contracts' \
#   "${first_remote_host}"

# cmd='./L2/optimism/remote/generate-configuration.sh generate-L2-configuration '\
# "${l1_node_url}"
# utils::exec_cmd_on_remote_hosts "${cmd}" 'Generate L2 configuration' \
#   "${first_remote_host}"

# cmd="retrieve_configuration ${first_remote_host}"
# utils::exec_cmd "${cmd}" 'Retrieve configuration'

# cmd="send_configuration ${remote_hosts_list[@]}"
# utils::exec_cmd "${cmd}" 'Send configuration'

# cmd='./L2/optimism/remote/generate-configuration.sh initialize-nodes'
# utils::exec_cmd_on_remote_hosts "${cmd}" 'Initialize nodes' \
#   "${remote_hosts_list[@]}"

trap - ERR
