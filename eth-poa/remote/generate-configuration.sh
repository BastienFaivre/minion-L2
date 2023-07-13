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
  echo '  generate <number of accounts>'
  echo '  setup'
  echo '  finalize'
}

#######################################
# Check that the necessary commands are available and export them
# Globals:number
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
    utils::err "geth command not found in ${INSTALL_ROOT}/build/bin"
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
#   $@: nodes names
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
  local authrpcport=6000
  local port=7000
  local rpcport=8000
  local wsport=9000
  local dir
  for name in "$@"; do
    dir=${DEPLOY_ROOT}/${name}
    mkdir -p ${dir}
    # \n\n is to skip the password confirmation
    printf "\n\n" | geth account new --datadir ${dir}
    echo ${authrpcport} > ${dir}/authrpcport
    echo ${port} > ${dir}/port
    echo ${rpcport} > ${dir}/rpcport
    echo ${wsport} > ${dir}/wsport
    touch ${dir}/password
    authrpcport=$((authrpcport+1))
    port=$((port+1))
    rpcport=$((rpcport+1))
    wsport=$((wsport+1))
  done
  trap - ERR
}

#######################################
# Generate the genesis file following this guide:
# https://geth.ethereum.org/docs/fundamentals/private-network
# TODO modify the configuration to run a post-merge network (Eth 2.0)
# https://dev.to/q9/how-to-merge-an-ethereum-network-right-from-the-genesis-block-3454
# Globals:
#   None
# Arguments:
#   $1: number of accounts
# Outputs:
#   None
# Returns:
#   None
#######################################
generate() {
  trap 'exit 1' ERR
  if ! utils::check_args_eq 1 $#; then
    trap - ERR
    exit 1
  fi
  setup_environment
  local num_accounts=${1}
  if [ ! -f ${DEPLOY_ROOT}/network.tar.gz ]; then
    utils::err "function ${FUNCNAME[0]}(): File ${DEPLOY_ROOT}/network.tar.gz "\
'not found.'
    trap - ERRp_no
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
  mkdir -p ${NETWORK_ROOT}/accounts
  mkdir -p ${NETWORK_ROOT}/accounts/keystore
  mkdir -p ${NETWORK_ROOT}/tmp
  local alloc=''
  for i in $(seq 0 ${num_accounts}); do
    printf "%d\n%d\n" ${i} ${i} | geth --datadir ${NETWORK_ROOT}/tmp \
      account new > /dev/null 2>&1
    cp ${NETWORK_ROOT}/tmp/keystore/* ${NETWORK_ROOT}/accounts/keystore/
    keypath=$(ls ${NETWORK_ROOT}/tmp/keystore/UTC--*)
    address=${keypath##*--}
    private=$(./eth-poa/remote/extract.py ${keypath} ${i})
    if [ ${i} -eq 0 ]; then
      echo ${address}:${private} > ${NETWORK_ROOT}/accounts/account_master
      alloc+='"'${address}'": {"balance": "'${MASTER_BALANCE}'"}'
    else
      echo ${address}:${private} > ${NETWORK_ROOT}/accounts/account_${i}
      alloc+='"'${address}'": {"balance": "'${ACCOUNT_BALANCE}'"}'
    fi
    if [ ${i} -ne ${num_accounts} ]; then
      alloc+=', '
    fi
    rm -rf ${NETWORK_ROOT}/tmp/*
  done
  cat > ${NETWORK_ROOT}/genesis.json <<EOF
{
  "config": {
    "chainId": ${CHAIN_ID},
    "homesteadBlock": 0,
    "eip150Block": 0,
    "eip155Block": 0,
    "eip158Block": 0,
    "byzantiumBlock": 0,
    "constantinopleBlock": 0,
    "petersburgBlock": 0,
    "istanbulBlock": 0,
    "berlinBlock": 0,
    "londonBlock": 0,
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
    utils::err "function ${FUNCNAME[0]}(): File ${DEPLOY_ROOT}/genesis.json "\
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
      ${address} --password ${dir}/password &
    pid=$!
    while [ ! -e ${dir}/geth.ipc ]; do
      sleep 0.1
    done
    geth attach --exec admin.nodeInfo.enode ${dir}/geth.ipc \
      | sed -r 's/@.*\?/@0.0.0.0:'${port}'?/' \
      >> ${DEPLOY_ROOT}/static-nodes-$(hostname -I | awk '{print $1}')
    kill ${pid}
  done
  rm -rf ${DEPLOY_ROOT}/genesis.json
  trap - ERR
}

#######################################
# Copy the static nodes file in all nodes directories
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   None
# Returns:
#   None
#######################################
finalize() {
  trap 'exit 1' ERR
  if ! utils::check_args_eq 0 $#; then
    trap - ERR
    exit 1
  fi
  setup_environment
  if [ ! -f ${DEPLOY_ROOT}/config.toml ]; then
    utils::err "function ${FUNCNAME[0]}(): File ${DEPLOY_ROOT}/"\
'config.toml not found.'
    trap - ERR
    exit 1
  fi
  for dir in ${DEPLOY_ROOT}/*; do
    test -d ${dir} || continue
    test -d ${dir}/keystore || continue
    cp ${DEPLOY_ROOT}/config.toml ${dir}/
  done
  rm -rf ${DEPLOY_ROOT}/static-nodes-*.json ${DEPLOY_ROOT}/config.toml
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
  'finalize')
    cmd="finalize $@"
    utils::exec_cmd "${cmd}" 'Finalize the host'
    ;;
  *)
    utils::err "Unknown action ${action}"
    usage
    trap - ERR
    exit 1
    ;;
esac

trap - ERR
