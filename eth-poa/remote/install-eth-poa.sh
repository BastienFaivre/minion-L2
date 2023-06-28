#!/bin/bash
#===============================================================================
# Author: Bastien Faivre
# Project: EPFL, DCL, Performance and Security Evaluation of Layer 2 Blockchain
#          Systems
# Date: June 2023
# Description: Export the setup to the remote hosts
# Source: https://github.com/Blockchain-Benchmarking/minion/blob/cleanup/script/remote/linux/apt/install-poa
#===============================================================================

#===============================================================================
# IMPORTS
#===============================================================================

. eth-poa/constants.sh
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
# Install the necessary packages
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   None
# Returns:
#   None
#######################################
install_necessary_packages() {
  trap 'exit 1' ERR
  sudo apt-get update
  sudo apt-get install -y git make build-essential
  trap - ERR
}

#######################################
# Install Golang
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   None
# Returns:
#   None
#######################################
install_go() {
  trap 'exit 1' ERR
  wget ${GO_URL} > /dev/null 2>&1
  sudo rm -rf /usr/local/go
  sudo tar -C /usr/local -xzf ${GO_URL##*/}
  rm ${GO_URL##*/}
  if ! grep ~/.profile -e ${GO_PATH} &> /dev/null
  then
    echo "export PATH=\$PATH:${GO_PATH}" >> ~/.profile
  fi
  source ~/.profile
  if ! command -v go &> /dev/null
  then
    utils::err 'function install_go(): Go command not found after installation'
    trap - ERR
    exit 1
  fi
  trap - ERR
}

#######################################
# Initialize directories
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   None
# Returns:
#   None
#######################################
initialize_directories() {
  trap 'exit 1' ERR
  mkdir -p ${INSTALL_FOLDER}
  rm -rf ${INSTALL_ROOT}
  trap - ERR
}

#######################################
# Clone and build Geth
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   None
# Returns:
#   None
#######################################
clone_and_build_geth() {
  trap 'exit 1' ERR
  git clone ${GETH_URL} ${INSTALL_ROOT}
  cd ${INSTALL_ROOT}
  git checkout ${GETH_BRANCH}
  make all
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

utils::exec_cmd 'install_necessary_packages' 'Install necessary packages'

if ! command -v go &> /dev/null
then
  utils::exec_cmd 'install_go' 'Install Go'
  source ~/.profile
  if ! command -v go &> /dev/null
  then
    utils::err 'function main(): Go command not found after installation'
    trap - ERR
    exit 1
  fi
fi

utils::exec_cmd 'initialize_directories' 'Initialize directories'

utils::exec_cmd 'clone_and_build_geth' 'Clone and build Geth'

trap - ERR
