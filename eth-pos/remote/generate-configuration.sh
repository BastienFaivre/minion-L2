#!/bin/bash
#===============================================================================
# Author: Bastien Faivre
# Project: EPFL, DCL, Performance and Security Evaluation of Layer 2 Blockchain
#          Systems
# Date: July 2023
# Description: Generate configuration and prepare the host
#===============================================================================

#===============================================================================
# IMPORTS
#===============================================================================

. eth-pos/constants.sh
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
  echo 'Usage: $(basename ${0}) <action> [options...]'
  echo 'Actions:'
  echo '  generate <number of accounts> <nodes ip addresses...>'
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
  if [ ! -d ${INSTALL_ROOT}/go-ethereum ] \
    || [ ! -d ${INSTALL_ROOT}/lighthouse ];
  then
    utils::err "function ${FUNCNAME[0]}(): Installation not completed. Please "\
'run install-optimism.sh first.'
    trap - ERR
    exit 1
  fi
  export PATH=${PATH}:${HOME}/${INSTALL_ROOT}/go-ethereum/build/bin
  if ! command -v geth &> /dev/null
  then
    utils::err "Geth command not found in ${INSTALL_ROOT}/go-ethereum/build/bin"
    trap - ERR
    exit 1
  fi
  if ! command -v bootnode &> /dev/null
  then
    utils::err "Bootnode command not found in "\
"${INSTALL_ROOT}/go-ethereum/build/bin"
    trap - ERR
    exit 1
  fi
  export PATH=${PATH}:${HOME}/.cargo/bin/
  if ! command -v lighthouse &> /dev/null
  then
    utils::err "Lighthouse command not found in ${INSTALL_ROOT}/lighthouse"
    trap - ERR
    exit 1
  fi
  export PATH=/usr/local/go/bin/:$PATH
  if ! command -v go &> /dev/null
  then
    utils::err 'Go command not found in /usr/local/go/bin/'
    trap - ERR
    exit 1
  fi
  trap - ERR
}

generate() {
  trap 'exit 1' ERR
  if ! utils::check_args_ge 2 $#; then
    usage
    exit 1
  fi
  setup_environment
  local num_accounts=${1}; shift
  local nodes_ip_addresses=($@)
  rm -rf ${DEPLOY_ROOT}
  mkdir -p ${DEPLOY_ROOT}
  mkdir -p ${CONFIG_ROOT}
  mkdir -p ${CONFIG_ROOT}/accounts
  mkdir -p ${CONFIG_ROOT}/accounts/keystore
  mkdir -p ${CONFIG_ROOT}/tmp
  # Generate accounts
  local alloc='{'
  for i in $(seq 0 ${num_accounts}); do
    printf "%d\n%d\n" ${i} ${i} | geth --datadir ${CONFIG_ROOT}/tmp \
      account new > /dev/null 2>&1
    cp ${CONFIG_ROOT}/tmp/keystore/* ${CONFIG_ROOT}/accounts/keystore/
    keypath=$(ls ${CONFIG_ROOT}/tmp/keystore/UTC--*)
    address=${keypath##*--}
    private=$(./eth-pos/remote/extract.py ${keypath} ${i})
    if [ ${i} -eq 0 ]; then
      echo ${address}:${private} > ${CONFIG_ROOT}/accounts/account_master
      alloc+='"'${address}'": {"balance": "'${MASTER_BALANCE}'"}'
    else
      echo ${address}:${private} > ${CONFIG_ROOT}/accounts/account_${i}
      alloc+='"'${address}'": {"balance": "'${ACCOUNT_BALANCE}'"}'
    fi
    if [ ${i} -ne ${num_accounts} ]; then
      alloc+=', '
    else
      alloc+='}'
    fi
    rm -rf ${CONFIG_ROOT}/tmp/*
  done
  # Generate genesis
  genesis=$(cat eth-pos/remote/genesis.json)
  jq --argjson alloc "${alloc}" '.alloc += $alloc' <<< ${genesis} \
    > ${CONFIG_ROOT}/genesis.json
  jq ".config.chainId = ${CHAIN_ID}" ${CONFIG_ROOT}/genesis.json \
    > ${CONFIG_ROOT}/genesis.json.tmp && \
    mv ${CONFIG_ROOT}/genesis.json.tmp ${CONFIG_ROOT}/genesis.json
  # Get genesis hash
  geth init --datadir ${CONFIG_ROOT}/tmp ${CONFIG_ROOT}/genesis.json
  geth console --datadir ${CONFIG_ROOT}/tmp \
    --exec 'eth.getBlock(0).hash' > ${CONFIG_ROOT}/genesis_hash 2> /dev/null
  sed -i 's/"//g' ${CONFIG_ROOT}/genesis_hash
  rm -rf ${CONFIG_ROOT}/tmp
  # Generate config file, create each node a key and its associated enode
  cp eth-pos/remote/config.toml ${CONFIG_ROOT}/config.toml
  echo 'StaticNodes = [' >> ${CONFIG_ROOT}/config.toml
  local dir
  i=0
  for ip in ${nodes_ip_addresses[@]}; do
    dir=${CONFIG_ROOT}/n${i}
    mkdir -p ${dir}/geth
    bootnode --genkey ${CONFIG_ROOT}/n${i}/geth/nodekey
    nodekey=$(bootnode --nodekey ${CONFIG_ROOT}/n${i}/geth/nodekey \
      --writeaddress)
    if [ ${i} -eq $((${#nodes_ip_addresses[@]}-1)) ]; then
      echo -e "\t\"enode://${nodekey}@${ip}:${GETH_PORT}\"" \
        >> ${CONFIG_ROOT}/config.toml
    else
      echo -e "\t\"enode://${nodekey}@${ip}:${GETH_PORT}\"," \
        >> ${CONFIG_ROOT}/config.toml
    fi
    i=$((i+1))
  done
  echo ']' >> ${CONFIG_ROOT}/config.toml
  tar -czf ${DEPLOY_ROOT}/config.tar.gz -C ${CONFIG_ROOT} .
  rm -rf ${CONFIG_ROOT}
  trap - ERR
}

setup() {
  trap 'exit 1' ERR
  if ! utils::check_args_eq 0 $#; then
    usage
    exit 1
  fi
  setup_environment
  if [ ! -f ${DEPLOY_ROOT}/config.tar.gz ]; then
    utils::err 'Configuration archive not found. Please run generate first.'
    trap - ERR
    exit 1
  fi
  mkdir -p ${DEPLOY_ROOT}/config
  tar -xzf ${DEPLOY_ROOT}/config.tar.gz -C ${DEPLOY_ROOT}/config
  rm -rf ${DEPLOY_ROOT}/config.tar.gz
  for dir in ${DEPLOY_ROOT}/config/n*; do
    test -d "${dir}" || continue
    test -d "${dir}/geth" || continue
    geth init --datadir ${dir} ${DEPLOY_ROOT}/config/genesis.json
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
action=${1}; shift

trap 'exit 1' ERR

utils::ask_sudo
case ${action} in
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
