#!/bin/bash
#===============================================================================
# Author: Bastien Faivre
# Project: EPFL, DCL, Performance and Security Evaluation of Layer 2 Blockchain
#          Systems
# Date: June 2023
# Description: Generate configuration files for Ethereum PoA
# Source: https://github.com/Blockchain-Benchmarking/minion/blob/cleanup/script/remote/deploy-poa-worker
#===============================================================================

#===============================================================================
# IMPORTS
#===============================================================================

. eth-poa/remote/remote.env
. scripts/utils.sh

#===============================================================================
# FUNCTIONS
#===============================================================================

#######################################
# Check that the necessary commands are available and export them
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   None
# Returns:
#   None
#######################################
setup_environment() {
  trap 'exit 1' ERR
  if [ ! -d ${INSTALL_ROOT} ]; then
    echo 'function setup_environment(): Ethereum is not installed. Please run \
install-eth-poa.sh first.'
    trap - ERR
    exit 1
  fi
  export PATH=${PATH}:${HOME}/${INSTALL_ROOT}/build/bin
  if ! command -v geth &> /dev/null
  then
    utils::err "Geth command not found in ${INSTALL_ROOT}/build/bin"
    trap - ERR
    exit 1
  fi
  if ! command -v bootnode &> /dev/null
  then
    utils::err "Geth command not found in ${INSTALL_ROOT}/build/bin"
    trap - ERR
    exit 1
  fi
}

#######################################
# Prepare the host for the configuration generation
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   None
# Returns:
#   None
#######################################
prepare() {
  trap 'exit 1' ERR
  if [[ "$#" -lt 1 ]]; then
    utils::err 'function prepare(): Nodes names expected.'
    exit 1
  fi
  setup_environment
  rm -rf ${DEPLOY_ROOT}
  mkdir -p ${DEPLOY_ROOT}
  local port=7000
  local wsport=9000
  local dir
  for name in "$@"; do
    dir=${DEPLOY_ROOT}/${name}
    mkdir -p ${dir}
    printf "\n\n" | geth account new --datadir ${dir}
    echo ${port} > ${dir}/port
    echo ${wsport} > ${dir}/wsport
    touch ${dir}/password.txt
    port=$((port+1))
    wsport=$((wsport+1))
  done
  trap - ERR
}

#===============================================================================
# MAIN
#===============================================================================

if [ $# -eq 0 ]; then
  echo "Usage: $0 <action> [options...]"
  exit 1
fi
action=$1; shift

trap 'exit 1' ERR

utils::ask_sudo
case ${action} in
  'prepare')
    cmd="prepare $@"
    utils::exec_cmd "${cmd}" 'Prepare the host'
    ;;
  'generate')
    cmd="generate $@"
    utils::exec_cmd "${cmd}" 'Generate the configuration'
    ;;
  *)
    echo "Usage: $0 <action> [options...]"
    trap - ERR
    exit 1
    ;;
esac

trap - ERR
