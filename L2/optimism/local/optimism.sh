#!/bin/bash
#===============================================================================
# Author: Bastien Faivre
# Project: EPFL, DCL, Performance and Security Evaluation of Layer 2 Blockchain
#          Systems
# Date: July 2023
# Description: Start/stop/kill Optimism on remote hosts
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
  echo "Usage: $(basename ${0}) <remote hosts file> start|stop|kill"
}

#######################################
# Execute the command with a delay for each host
# This is to avoid problems with static nodes
# Globals:
#   None
# Arguments:
#   $1: command
#   $@: remote hosts list
# Outputs:
#   None
# Returns:
#   None
#######################################
execute_with_delay() {
  if ! utils::check_args_ge 2 $#; then
    exit 1
  fi
  local cmd=$(echo "${1}" | tr '|' ' ')
  local remote_hosts_list=("${@:2}")
  local array_of_pids=()
  for remote_host in "${remote_hosts_list[@]}"; do
    IFS=':' read -r host port <<< "${remote_host}"
    (
      ssh -p ${port} ${host} "${cmd}"
      if [ "$?" -ne 0 ]; then
        exit 1
      fi
    ) &
    array_of_pids+=($!)
    sleep 1
  done
  for pid in "${array_of_pids[@]}"; do
    wait ${pid}
    if [ "$?" -ne 0 ]; then
      exit 1
    fi
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
  usage
  exit 1
fi
remote_hosts_file="$(cd "$(dirname "${remote_hosts_file}")"; pwd)/\
$(basename "${remote_hosts_file}")"
remote_hosts_list=($(utils::create_remote_hosts_list ${remote_hosts_file}))
action=${2}
if [ "${action}" != 'start' ] && [ "${action}" != 'stop' ] && \
  [ "${action}" != 'kill' ]; then
  utils::err "Unknown action ${action}"
  usage
  exit 1
fi
shift 2

trap 'exit 1' ERR

host_cmd="./L2/optimism/remote/optimism.sh|${action}"
cmd="execute_with_delay ${host_cmd} ${remote_hosts_list[@]}"
utils::exec_cmd "${cmd}" "${action} Optimism on remote hosts"

trap - ERR
