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
cd "$(dirname "$0")"
. ../utils.sh

#===============================================================================
# FUNCTIONS
#===============================================================================

#######################################
# Export the setup to the remote hosts
# Globals:
#   None
# Arguments:
#   $1: remote hosts list file
# Outputs:
#   None
# Returns:
#   None
#######################################
export() {
  trap 'exit 1' ERR
  if [[ "$#" -ne 1 ]]; then
    utils::err 'function export(): One argument expected.'
    exit 1
  fi
  local remote_hosts_file="${1}"
  if [ ! -f "${remote_hosts_file}" ]; then
    utils::err "function export(): File ${remote_hosts_file} does not exist."
    exit 1
  fi
  cd ../..
  while IFS=':' read -r host port; do
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
  done < "${remote_hosts_file}"
  wait
  trap - ERR
}

#===============================================================================
# MAIN
#===============================================================================

if [[ "$#" -ne 1 ]]; then
  utils::err 'One argument expected.'
  exit 1
fi
remote_hosts_file="$caller_dir/${1}"
if [ ! -f "${remote_hosts_file}" ]; then
  utils::err "function main(): File ${remote_hosts_file} does not exist."
  exit 1
fi
remote_hosts_file="$(cd "$(dirname "${remote_hosts_file}")"; pwd)/\
$(basename "${remote_hosts_file}")"

trap 'exit 1' ERR

cmd="export ${remote_hosts_file}"
utils::exec_cmd "${cmd}" 'Export the setup to the remote hosts'

trap - ERR
