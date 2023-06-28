#!/bin/bash
#===============================================================================
# Author: Bastien Faivre
# Project: EPFL, DCL, Performance and Security Evaluation of Layer 2 Blockchain
#          Systems
# Date: June 2023
# Description: Export the setup to the remote hosts
#===============================================================================

#===============================================================================
# IMPORTS
#===============================================================================

caller_dir=$(pwd)
cd "$(dirname "${0}")"
. ../utils.sh

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
  echo "Usage: $(basename ${0}) <remote hosts file>"
}

#######################################
# Export the setup to the remote hosts
# Globals:
#   None
# Arguments:
#   $1: remote hosts list
# Outputs:
#   None
# Returns:
#   None
#######################################
export() {
  trap 'exit 1' ERR
  if ! utils::check_args_ge 1 $#; then
    trap - ERR
    exit 1
  fi
  local remote_hosts_list=("${@:1}")
  cd ../..
  for remote_host in "${remote_hosts_list[@]}"; do
    IFS=':' read -r host port <<< "${remote_host}"
    (
      rsync -rav -e "ssh -p ${port}" \
      eth-poa/ \
      --exclude 'local/' \
      ${host}:~/eth-poa
      ssh -p ${port} ${host} 'mkdir -p ~/scripts'
      rsync -rav -e "ssh -p ${port}" \
      scripts/ \
      --exclude 'local/' \
      ${host}:~/scripts
    ) &
  done
  wait
  trap - ERR
}

#===============================================================================
# MAIN
#===============================================================================

if ! utils::check_args_eq 1 $#; then
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

trap 'exit 1' ERR

cmd="export ${remote_hosts_list[@]}"
utils::exec_cmd "${cmd}" 'Export the setup to the remote hosts'

trap - ERR
