#!/bin/bash
#===============================================================================
# Author: Bastien Faivre
# Project: EPFL, DCL, Performance and Security Evaluation of Layer 2 Blockchain
#          Systems
# Date: June 2023
# Description: Install Geth on the remote hosts
#===============================================================================

#===============================================================================
# IMPORTS
#===============================================================================

caller_dir=$(pwd)
cd "$(dirname "$0")"
. ../../scripts/utils.sh

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

cmd='./eth-poa/remote/install-eth-poa.sh'
utils::exec_cmd_on_remote_hosts "${cmd}" 'Install Geth on remote hosts' \
  "${remote_hosts_file}"
