#!/bin/bash
#===============================================================================
# Author: Bastien Faivre
# Project: EPFL, DCL, Performance and Security Evaluation of Layer 2 Blockchain
#          Systems
# Date: August 2023
# Description: Bridge L1 account's tokens to L2
#===============================================================================

#===============================================================================
# IMPORTS
#===============================================================================

. L2/optimism/constants.sh
. scripts/utils.sh

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
  echo "Usage: $(basename ${0})"
}

#######################################
# Bridge L1 account's tokens to L2
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   None
# Returns:
#   None
#######################################
bridge_l1_to_l2() {
  trap 'exit 1' ERR
  local i=0
  for account in ./deploy/eth-pos/config/execution/accounts/*; do
    private_key=$(cat ${account} | cut -d: -f2)
    # bridge
    node ./L2/optimism/remote/bridge/index.js ${private_key} ${BRIDGE_BALANCE} &
    if [ $((i % (4 * $(nproc)))) -eq 0 ]; then
      wait
    fi
    i=$((i+1))
  done
  wait
  trap - ERR
}

#===============================================================================
# MAIN
#===============================================================================

if ! utils::check_args_eq 0 $#; then
  usage
  exit 1
fi

trap 'exit 1' ERR

utils::ask_sudo

# utils::exec_cmd 'bridge_l1_to_l2' 'Bridge L1 account tokens to L2'
bridge_l1_to_l2

trap - ERR
