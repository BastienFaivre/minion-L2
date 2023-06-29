#!/bin/bash
#===============================================================================
# Author: Bastien Faivre
# Project: EPFL, DCL, Performance and Security Evaluation of Layer 2 Blockchain
#          Systems
# Date: June 2023
# Description: Start/stop/kill Ethereum PoA on remote hosts
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
  echo 'Usage: $(basename ${0}) <remote hosts file> start|stop|kill'
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

trap 'exit 1' ERR

cmd="./eth-poa/remote/eth-poa.sh ${action}"
utils::exec_cmd_on_remote_hosts "${cmd}" "${action} Ethereum PoA on remote "\
'hosts' "${remote_hosts_list[@]}"

trap - ERR
