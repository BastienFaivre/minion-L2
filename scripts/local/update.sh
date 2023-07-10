#!/bin/bash
#===============================================================================
# Author: Bastien Faivre
# Project: EPFL, DCL, Performance and Security Evaluation of Layer 2 Blockchain
#          Systems
# Date: July 2023
# Description: Update the remote hosts
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

cmd='./scripts/remote/update.sh'
utils::exec_cmd_on_remote_hosts "${cmd}" 'Update remote hosts' \
  "${remote_hosts_list[@]}"

trap - ERR
