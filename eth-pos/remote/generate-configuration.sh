#!/bin/bash
#===============================================================================
# Author: Bastien Faivre
# Project: EPFL, DCL, Performance and Security Evaluation of Layer 2 Blockchain
#          Systems
# Date: July 2023
# Description: Generate configuration
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
'run install-eth-pos.sh first.'
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
    cp ${CONFIG_ROOT}/tmp/keystore/* ${CONFIG_ROOT}/execution/accounts/keystore/
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
  geth init --datadir ${CONFIG_ROOT}/tmp ${CONFIG_ROOT}/execution/genesis.json \
    > /dev/null 2>&1
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
    geth init --datadir ${dir} ${CONFIG_ROOT}/execution/genesis.json \
      > /dev/null 2>&1
    i=$((i+1))
  done
  echo ']' >> ${CONFIG_ROOT}/execution/config.toml
  # Generate consensus layer configuration
  mkdir -p ${CONFIG_ROOT}/consensus
  mkdir -p ${CONFIG_ROOT}/consensus/eth2-config
  local total_validators=$(( ${#nodes_ip_addresses[@]} * VALIDATORS_PER_NODE ))
  # Create the genesis state
  lcli new-testnet \
    --spec mainnet \
    --derived-genesis-state \
    --force \
    --altair-fork-epoch ${ALTAIR_FORK_EPOCH} \
    --bellatrix-fork-epoch ${BELLATRIX_FORK_EPOCH} \
    --capella-fork-epoch ${CAPELLA_FORK_EPOCH} \
    --deposit-contract-address 0x0420420420420420420420420420420420420420 \
    --eth1-block-hash $(cat ${CONFIG_ROOT}/execution/genesis_hash) \
    --eth1-follow-distance 1 \
    --eth1-id ${CHAIN_ID} \
    --genesis-delay ${GENESIS_DELAY} \
    --genesis-fork-version ${GENESIS_FORK_VERSION} \
    --min-genesis-active-validator-count ${MIN_ACTIVE_VALIDATOR_COUNT} \
    --min-genesis-time $(echo $(expr $(date +%s) + ${GENESIS_DELAY})) \
    --mnemonic-phrase "${MNENOMIC_PHRASE}" \
    --proposer-score-boost 40 \
    --seconds-per-eth1-block ${SECONDS_PER_ETH1_BLOCK} \
    --seconds-per-slot ${SECONDS_PER_SLOT} \
    --testnet-dir ${CONFIG_ROOT}/consensus/eth2-config \
    --ttd ${TTD} \
    --validator-count ${total_validators} \
    > /dev/null 2>&1
  # Create validator keys
  lcli mnemonic-validators \
    --spec mainnet \
    --base-dir ${CONFIG_ROOT}/consensus \
    --count ${total_validators} \
    --mnemonic-phrase "${MNENOMIC_PHRASE}" \
    --node-count ${#nodes_ip_addresses[@]} \
    --testnet-dir ${CONFIG_ROOT}/consensus/eth2-config \
    > /dev/null 2>&1
  # Create the bootnode
  lcli generate-bootnode-enr \
    --spec mainnet \
    --genesis-fork-version ${GENESIS_FORK_VERSION} \
    --ip ${nodes_ip_addresses[0]} \
    --output-dir ${DEPLOY_ROOT}/config/consensus/bootnode \
    --testnet-dir ${DEPLOY_ROOT}/config/consensus/eth2-config \
    --tcp-port ${BOOTNODE_PORT} \
    --udp-port ${BOOTNODE_PORT}
  echo "- $(cat ${DEPLOY_ROOT}/config/consensus/bootnode/enr.dat)" \
    > ${CONFIG_ROOT}/consensus/eth2-config/boot_enr.yaml
  tar -czf ${DEPLOY_ROOT}/config.tar.gz -C ${CONFIG_ROOT} .
  rm -rf ${CONFIG_ROOT}
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
  *)
    utils::err "Unknown action ${action}"
    usage
    trap - ERR
    exit 1
    ;;
esac

trap - ERR
