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
# TODO
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   None
# Returns:
#   None
#######################################

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

trap - ERR
