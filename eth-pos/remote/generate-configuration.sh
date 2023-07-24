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
    utils::err "Lighthouse command not found in ${HOME}/.cargo/bin/"
    trap - ERR
    exit 1
  fi
  if ! command -v lcli &> /dev/null
  then
    utils::err "Lcli command not found in ${HOME}/.cargo/bin/"
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

#######################################
# Generate the configuration for execution and consensus layers
# Globals:
#   None
# Arguments:
#   $1: number of accounts
#   $@: nodes ip addresses
# Outputs:
#   None
# Returns:
#   None
#######################################
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
  mkdir -p ${CONFIG_ROOT}/execution/accounts
  mkdir -p ${CONFIG_ROOT}/execution/accounts/keystore
  mkdir -p ${CONFIG_ROOT}/execution/tmp
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
      echo ${address}:${private} \
        > ${CONFIG_ROOT}/execution/accounts/account_master
      alloc+='"'${address}'": {"balance": "'${MASTER_BALANCE}'"}'
    else
      echo ${address}:${private} \
        > ${CONFIG_ROOT}/execution/accounts/account_${i}
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
    > ${CONFIG_ROOT}/execution/genesis.json
  jq ".config.chainId = ${CHAIN_ID}" ${CONFIG_ROOT}/execution/genesis.json \
    > ${CONFIG_ROOT}/execution/genesis.json.tmp && \
    mv ${CONFIG_ROOT}/execution/genesis.json.tmp \
      ${CONFIG_ROOT}/execution/genesis.json
  # Get genesis hash
  geth init --datadir ${CONFIG_ROOT}/tmp ${CONFIG_ROOT}/execution/genesis.json
  geth console --datadir ${CONFIG_ROOT}/tmp \
    --exec 'eth.getBlock(0).hash' > ${CONFIG_ROOT}/execution/genesis_hash 2> \
    /dev/null
  sed -i 's/"//g' ${CONFIG_ROOT}/execution/genesis_hash
  rm -rf ${CONFIG_ROOT}/tmp
  # Generate config file, create each node a key and its associated enode
  cp eth-pos/remote/config.toml ${CONFIG_ROOT}/execution/config.toml
  echo 'StaticNodes = [' >> ${CONFIG_ROOT}/execution/config.toml
  local dir
  i=0
  for ip in ${nodes_ip_addresses[@]}; do
    dir=${CONFIG_ROOT}/execution/n${i}
    mkdir -p ${dir}/geth
    bootnode --genkey ${dir}/geth/nodekey
    nodekey=$(bootnode --nodekey ${dir}/geth/nodekey --writeaddress)
    if [ ${i} -eq $((${#nodes_ip_addresses[@]}-1)) ]; then
      echo -e "\t\"enode://${nodekey}@${ip}:${GETH_PORT}\"" \
        >> ${CONFIG_ROOT}/execution/config.toml
    else
      echo -e "\t\"enode://${nodekey}@${ip}:${GETH_PORT}\"," \
        >> ${CONFIG_ROOT}/execution/config.toml
    fi
    openssl rand -hex 32 > ${dir}/jwt.txt
    i=$((i+1))
  done
  echo ']' >> ${CONFIG_ROOT}/execution/config.toml
  # Generate consensus layer configuration
  mkdir -p ${CONFIG_ROOT}/consensus

  mkdir -p ${CONFIG_ROOT}/consensus/eth2-config
  lcli new-testnet \
    --spec mainnet \
    --deposit-contract-address 0x0420420420420420420420420420420420420420 \
    --testnet-dir ${CONFIG_ROOT}/consensus/eth2-config \
    --min-genesis-active-validator-count ${VALIDATOR_COUNT} \
    --min-genesis-time $(echo $(expr $(date +%s) + ${GENESIS_DELAY})) \
    --genesis-delay ${GENESIS_DELAY} \
    --genesis-fork-version ${GENESIS_FORK_VERSION} \
    --altair-fork-epoch ${ALTAIR_FORK_EPOCH} \
    --bellatrix-fork-epoch ${BELLATRIX_FORK_EPOCH} \
    --capella-fork-epoch ${CAPELLA_FORK_EPOCH} \
    --ttd ${TTD} \
    --eth1-block-hash $(cat ${CONFIG_ROOT}/genesis_hash) \
    --eth1-id ${CHAIN_ID} \
    --eth1-follow-distance 1 \
    --seconds-per-slot ${SECONDS_PER_SLOT} \
    --seconds-per-eth1-block ${SECONDS_PER_ETH1_BLOCK} \
    --proposer-score-boost 40 \
    --validator-count ${VALIDATOR_COUNT} \
    --interop-genesis-state \
    --force
  lcli mnemonic-validators \
    --base-dir ${CONFIG_ROOT}/consensus/ \
    --count ${VALIDATOR_COUNT} \
    --mnemonic-phrase "${MNENOMIC_PHRASE}" \
    --testnet-dir ${CONFIG_ROOT}/consensus/eth2-config
  local genesis_time=$(lcli pretty-ssz state_merge \
    ${CONFIG_ROOT}/consensus/genesis.ssz | jq | \
    grep -Po 'genesis_time": "\K.*\d')
  local capella_time=$((genesis_time + (CAPELLA_FORK_EPOCH * 32 * SECONDS_PER_SLOT)))
  sed -i 's/"shanghaiTime".*$/"shanghaiTime": '"${capella_time}"',/g' \
    ${CONFIG_ROOT}/genesis.json
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