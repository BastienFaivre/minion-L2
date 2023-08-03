#!/bin/bash
#===============================================================================
# Author: Bastien Faivre
# Project: EPFL, DCL, Performance and Security Evaluation of Layer 2 Blockchain
#          Systems
# Date: July 2023
# Description: Generate configuration
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
  echo 'Usage: $(basename ${0}) <remote hosts file> <number of accounts>'
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

#######################################
# Send the configuration to the remote hosts
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
  local remote_hosts_list=("${@}")
  local i=0
  for remote_host in "${remote_hosts_list[@]}"; do
    (
      IFS=':' read -r host port <<< "${remote_host}"
      ssh -p ${port} ${host} "rm -rf ${DEPLOY_ROOT}; mkdir -p ${DEPLOY_ROOT}/\
config"
      mkdir -p ./tmp/config-n${i}
      mkdir -p ./tmp/config-n${i}/execution
      cp ./tmp/config/execution/config.toml \
        ./tmp/config-n${i}/execution/config.toml
      cp -r ./tmp/config/execution/n${i} ./tmp/config-n${i}/execution/n${i}
      mv ./tmp/config-n${i}/execution/n${i}/jwt.txt ./tmp/config-n${i}/jwt.txt
      mkdir -p ./tmp/config-n${i}/consensus
      cp -r ./tmp/config/consensus/eth2-config \
        ./tmp/config-n${i}/consensus/eth2-config
      cp -r ./tmp/config/consensus/node_$((${i} + 1)) \
        ./tmp/config-n${i}/consensus/n${i}
      if [ ${i} -eq 0 ]; then
        cp -r ./tmp/config/consensus/bootnode \
          ./tmp/config-n${i}/consensus/bootnode
      fi
      tar -czf ./tmp/config-n${i}.tar.gz -C ./tmp/config-n${i} .
      scp -P ${port} ./tmp/config-n${i}.tar.gz \
        ${host}:${DEPLOY_ROOT}/config.tar.gz
      rm -rf ./tmp/config-n${i} ./tmp/config-n${i}.tar.gz
      local cmd="tar -xzf ${DEPLOY_ROOT}/config.tar.gz -C \
${DEPLOY_ROOT}/config; rm -rf ${DEPLOY_ROOT}/config.tar.gz"
      ssh -p ${port} ${host} "${cmd}"
    ) &
    i=$((i + 1))
  done
  wait
  trap - ERR
}

#===============================================================================
# MAIN
#===============================================================================

if ! utils::check_args_eq 2 $#; then
  usage
  exit 1
fi
remote_hosts_file="$caller_dir/${1}"
if [ ! -f "${remote_hosts_file}" ]; then
  utils::err "function main(): File ${remote_hosts_file} does not exist."
  usage
  exit 1
fi
remote_hosts_file="$(cd "$(dirname "${remote_hosts_file}")"; pwd)/\
$(basename "${remote_hosts_file}")"
remote_hosts_list=($(utils::create_remote_hosts_list ${remote_hosts_file}))
number_of_accounts=${2}

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

cmd="./eth-pos/remote/generate-configuration.sh generate ${number_of_accounts}"\
" ${remote_hosts_ip_list[@]}"
utils::exec_cmd_on_remote_hosts "${cmd}" 'Generate the configuration' \
  "${first_remote_host}"

cmd="retrieve_configuration ${first_remote_host}"
utils::exec_cmd "${cmd}" 'Retrieve the configuration'

cmd="send_configuration ${remote_hosts_list[@]}"
utils::exec_cmd "${cmd}" 'Send the configuration'

trap - ERR
