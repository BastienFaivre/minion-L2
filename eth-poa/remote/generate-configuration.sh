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
  echo "Usage: $(basename ${0}) <action> [options...]"
  echo 'Actions:'
  echo '  prepare <nodes names...>'
  echo '  generate'
  echo '  setup'
}

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
    utils::err "function ${FUNCNAME[0]}(): Ethereum is not installed. Please \"
'run install-eth-poa.sh first."
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
  trap - ERR
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
  if ! utils::check_args_ge 1 $#; then
    trap - ERR
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
    # \n\n is to skip the password confirmation
    printf "\n\n" | geth account new --datadir ${dir}
    echo ${port} > ${dir}/port
    echo ${wsport} > ${dir}/wsport
    touch ${dir}/password.txt
    port=$((port+1))
    wsport=$((wsport+1))
  done
  trap - ERR
}

#######################################
# Generate the genesis file following this guide:
# https://geth.ethereum.org/docs/fundamentals/private-network
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   None
# Returns:
#   None
#######################################
generate() {
  trap 'exit 1' ERR
  if ! utils::check_args_eq 0 $#; then
    trap - ERR
    exit 1
  fi
  setup_environment
  if [ ! -f ${DEPLOY_ROOT}/network.tar.gz ]; then
    utils::err "function ${FUNCNAME[0]}(): File ${DEPLOY_ROOT}/network.tar.gz "\
'not found.'
    trap - ERR
    exit 1
  fi
  mkdir -p ${NETWORK_ROOT}
  tar -xzf ${DEPLOY_ROOT}/network.tar.gz -C ${NETWORK_ROOT}
  rm -rf ${DEPLOY_ROOT}/network.tar.gz
  local extradata='0x'
  for i in {1..32}; do
    extradata+='00'
  done
  for dir in ${NETWORK_ROOT}/*; do
    test -d ${dir} || continue
    test -d ${dir}/keystore || continue
    address=$(ls ${dir}/keystore/UTC--*)
    test -f ${address} || continue
    address=${address##*--}
    extradata+=${address}
  done
  for i in {1..64}; do
    extradata+='00'
  done
  # TODO pre-fund accounts from keyfile
  local alloc=''
  cat > ${NETWORK_ROOT}/genesis.json <<EOF
{
  "config": {
    "chainId": 10,
    "homesteadBlock": 0,
    "eip150Block": 0,
    "eip155Block": 0,
    "eip158Block": 0,
    "byzantiumBlock": 0,
    "constantinopleBlock": 0,
    "petersburgBlock": 0,
    "istanbulBlock": 0,
    "berlinBlock": 0,
    "clique": {
      "period": 5,
      "epoch": 30000
    }
  },
  "difficulty": "1",
  "gasLimit": "8000000",
  "extradata": "${extradata}",
  "alloc": {
    ${alloc}
  }
}
EOF
  trap - ERR
}

#######################################
# Setup the host with the genesis file
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   None
# Returns:
#   None
#######################################
setup() {
  trap 'exit 1' ERR
  if ! utils::check_args_eq 0 $#; then
    trap - ERR
    exit 1
  fi
  setup_environment
  if [ ! -f ${DEPLOY_ROOT}/genesis.json ]; then
    utils::err "function ${FUNCNAME[0]}(): File ${NETWORK_ROOT}/genesis.json "\
'not found.'
    trap - ERR
    exit 1
  fi
  local port address pid
  for dir in ${DEPLOY_ROOT}/*; do
    test -d ${dir} || continue
    test -d ${dir}/keystore || continue
    port=$(cat ${dir}/port)
    geth --datadir ${dir} init ${DEPLOY_ROOT}/genesis.json
    address=$(ls ${dir}/keystore/UTC--*)
    test -f ${address} || continue
    address=${address##*--}
    geth --datadir ${dir} --nodiscover --allow-insecure-unlock --unlock \
      ${address} --password ${dir}/password.txt &
    pid=$!
    while [ ! -e ${dir}/geth.ipc ]; do
      sleep 0.1
    done
    geth attach --exec admin.nodeInfo.enode ${dir}/geth.ipc \
      | sed -r 's/@.*\?/@0.0.0.0:'${port}'?/' \
      >> ${DEPLOY_ROOT}/static-nodes-$(hostname -I | awk '{print $1}').json
    kill ${pid}
  done
  trap - ERR
}

#===============================================================================
# MAIN
#===============================================================================

if ! utils::check_args_ge 1 $#; then
  usage
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
  'setup')
    cmd="setup $@"
    utils::exec_cmd "${cmd}" 'Setup the host'
    ;;
  *)
    utils::err "Unknown action ${action}"
    usage
    trap - ERR
    exit 1
    ;;
esac

trap - ERR
