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
  echo 'Usage: $(basename ${0}) <remote hosts file> <number of nodes>' \
'<L1 node url> <L1 master account file>'
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
  rm -rf ./tmp
  mkdir -p ./tmp
  mkdir -p ./tmp/accounts
  scp -P ${port} ${host}:${NETWORK_ROOT}/accounts/* ./tmp/accounts
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
    scp -P ${port} ./tmp/genesis.json ./tmp/rollup.json \
      ${host}:${INSTALL_FOLDER}/optimism/op-node &
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
number_of_nodes=${2}
l1_node_url=${3}
l1_master_account_file=$caller_dir/${4}
l1_master_account_private_key=$(cat ${l1_master_account_file} | cut -d':' -f2) 

trap 'exit 1' ERR

cmd='./L2/optimism/remote/generate-configuration.sh prepare'
utils::exec_cmd_on_remote_hosts "${cmd}" 'Prepare remote hosts' \
  "${remote_hosts_list[@]}"

first_remote_host=${remote_hosts_list[0]}

cmd='./L2/optimism/remote/generate-configuration.sh generate-keys '\
"${l1_node_url} ${l1_master_account_private_key}"
utils::exec_cmd_on_remote_hosts "${cmd}" 'Generate and fund accounts' \
  "${first_remote_host}"

cmd="retrieve_accounts ${first_remote_host}"
utils::exec_cmd "${cmd}" 'Retrieve accounts'

cmd='./L2/optimism/remote/generate-configuration.sh configure-network '\
"${l1_node_url}"
utils::exec_cmd_on_remote_hosts "${cmd}" 'Configure network' \
  "${first_remote_host}"

cmd='./L2/optimism/remote/generate-configuration.sh deploy-L1-contracts '\
"${l1_node_url}"
utils::exec_cmd_on_remote_hosts "${cmd}" 'Deploy L1 contracts' \
  "${first_remote_host}"

cmd='./L2/optimism/remote/generate-configuration.sh generate-L2-configuration '\
"${l1_node_url}"
utils::exec_cmd_on_remote_hosts "${cmd}" 'Generate L2 configuration' \
  "${first_remote_host}"

cmd="retrieve_configuration ${first_remote_host}"
utils::exec_cmd "${cmd}" 'Retrieve configuration'

cmd="send_configuration ${remote_hosts_list[@]}"
utils::exec_cmd "${cmd}" 'Send configuration'

cmd='./L2/optimism/remote/generate-configuration.sh initialize-op-geth'
utils::exec_cmd_on_remote_hosts "${cmd}" 'Initialize op-geth' \
  "${remote_hosts_list[@]}"

trap - ERR
