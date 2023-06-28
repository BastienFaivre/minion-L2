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
cd "$(dirname "$0")"
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
#   $1: remote hosts list file
#   $2: number of nodes
# Outputs:
#   None
# Returns:
#   None
#######################################
prepare() {
  trap 'exit 1' ERR
  if ! utils::check_args_eq 2 $#; then
    exit 1
  fi
  local remote_hosts_file=${1}
  if [ ! -f ${remote_hosts_file} ]; then
    utils::err "function prepare(): File ${remote_hosts_file} does not exist."
    exit 1
  fi
  local number_of_nodes=${2}
  local number_of_hosts=$(wc -l < ${remote_hosts_file})
  local nodes_per_host=$((number_of_nodes / number_of_hosts))
  local remainder=$((number_of_nodes % number_of_hosts))
  local index=0
  local node_to_assign node_list
  declare -a host_node_list
  while IFS=: read -r host port; do
    nodes_to_assign=${nodes_per_host}
    if [ ${remainder} -gt 0 ]; then
      nodes_to_assign=$((nodes_to_assign + 1))
      remainder=$((remainder - 1))
    fi
    node_list=''
    for ((i = 0; i < nodes_to_assign; i++)); do
      node_list+="n${index} "
      index=$((index + 1))
    done
    host_node_list+=("${host}:${port}:${node_list}")
  done < ${remote_hosts_file}
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
# Retrieve the accounts from the nodes
# Globals:
#   None
# Arguments:
#   $1: remote hosts list file
# Outputs:
#   None
# Returns:
#   None
#######################################
retrieve_accounts() {
  trap 'exit 1' ERR
  if ! utils::check_args_eq 1 $#; then
    exit 1
  fi
  local remote_hosts_file=${1}
  if [ ! -f ${remote_hosts_file} ]; then
    utils::err "function retrieve_accounts(): File ${remote_hosts_file} does \
not exist."
    exit 1
  fi
  rm -rf ./tmp
  mkdir -p ./tmp
  mkdir -p ./tmp/network
  while IFS=':' read -r host port; do
    echo "Retrieving accounts from ${host}:${port}"
    scp -r -P ${port} ${host}:~/${DEPLOY_ROOT}/n* ./tmp/network
  done < ${remote_hosts_file}
  tar -czf ./tmp/network.tar.gz ./tmp/network
  trap - ERR
}

#######################################
# Send the accounts to one node the generate the genesis file
# Globals:
#   None
# Arguments:
#   $1: remote hosts list file
# Outputs:
#   None
# Returns:
#   None
#######################################
send_accounts() {
  trap 'exit 1' ERR
  if ! utils::check_args_eq 1 $#; then
    exit 1
  fi
  local remote_hosts_file=${1}
  if [ ! -f ${remote_hosts_file} ]; then
    utils::err "function send_accounts(): File ${remote_hosts_file} does not \
exist."
    exit 1
  fi
  read -r first_line < ${remote_hosts_file}
  host=$(echo "${first_line}" | cut -d: -f1)
  port=$(echo "${first_line}" | cut -d: -f2)
  scp -P ${port} ./tmp/network.tar.gz ${host}:~/${DEPLOY_ROOT}
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
number_of_nodes=${2}

trap 'exit 1' ERR

cmd="prepare ${remote_hosts_file} ${number_of_nodes}"
utils::exec_cmd "${cmd}" 'Prepare the hosts'
cmd="retrieve_accounts ${remote_hosts_file}"
utils::exec_cmd "${cmd}" 'Retrieve the accounts'
cmd="send_accounts ${remote_hosts_file}"
utils::exec_cmd "${cmd}" 'Send the accounts to one host'

trap - ERR
