#!/bin/bash
#===============================================================================
# Author: Bastien Faivre
# Project: EPFL, DCL, Performance and Security Evaluation of Layer 2 Blockchain
#          Systems
# Date: August 2023
# Description: Generate configuration
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
# Retrieve the configuration from the remote host
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
  local remote_host=${1} # <user>@<ip>:<port>
  local host=$(echo "${remote_host}" | cut -d: -f1) # <user>@<ip>
  local port=$(echo "${remote_host}" | cut -d: -f2) # <port>
  rm -rf ./tmp
  mkdir -p ./tmp
  mkdir -p ./tmp/config
  scp -P ${port} ${host}:${DEPLOY_ROOT}/config.tar.gz  ./tmp/config.tar.gz
  ssh -p ${port} ${host} "rm -rf ${DEPLOY_ROOT}/config.tar.gz"
  tar -xzf ./tmp/config.tar.gz -C ./tmp/config
  trap - ERR
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

cmd="retrieve_configuration ${first_remote_host}"
utils::exec_cmd "${cmd}" 'Retrieve the configuration'

# TODO send configuration

trap - ERR
