#!/bin/bash
#===============================================================================
# Author: Bastien Faivre
# Project: EPFL, DCL, Performance and Security Evaluation of Layer 2 Blockchain
#          Systems
# Date: June 2023
# Description: Update the host
#===============================================================================

#===============================================================================
# IMPORTS
#===============================================================================

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
# Update the host
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   None
# Returns:
#   None
#######################################
update_host() {
  trap 'exit 1' ERR
  sudo apt-get update
  sudo apt-get --with-new-pkgs upgrade -y
  sudo apt-get clean
  sudo apt-get autoclean
  sudo apt-get autoremove --purge -y
  sudo snap refresh
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
utils::exec_cmd update_host 'Update host'

trap - ERR
