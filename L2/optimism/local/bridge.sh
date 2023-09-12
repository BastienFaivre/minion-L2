#!/bin/bash
#===============================================================================
# Author: Bastien Faivre
# Project: EPFL, DCL, Performance and Security Evaluation of Layer 2 Blockchain
#          Systems
# Date: July 2023
# Description: Bridge L1 account's tokens to L2
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
  echo "Usage: $(basename ${0}) <remote hosts file>"
}

#===============================================================================
# MAIN
#===============================================================================

if ! utils::check_args_eq 1 $#; then
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

trap 'exit 1' ERR

# TODO: uncomment
# remote_hosts_ip_list=()
# for remote_host in ${remote_hosts_list[@]}; do
#   remote_hosts_ip_list+=($(utils::extract_ip_address ${remote_host}))
# done
# TODO: remove
remote_hosts_ip_list=('192.168.201.2' '192.168.201.3' '192.168.201.4' \
'192.168.201.5' '192.168.201.6' '192.168.201.7' '192.168.201.8' '192.168.201.9'\
 '192.168.201.10' '192.168.201.11')

first_remote_host=${remote_hosts_list[0]}

cmd='./L2/optimism/remote/bridge.sh'
utils::exec_cmd_on_remote_hosts "${cmd}" 'Bridge L1 account tokens to L2' \
  "${first_remote_host}"

trap - ERR
