#!/bin/bash
#===============================================================================
# Author: Bastien Faivre
# Project: EPFL, DCL, Performance and Security Evaluation of Layer 2 Blockchain
#          Systems
# Date: June 2023
# Description: Generate configuration files for Optimism
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
  echo "Usage: $(basename ${0}) <action> [options...]"
  echo 'Actions:'
  echo '  prepare'
  echo '  generate-keys <L1 node url> <L1 master account private key>'
  echo '  configure-network <L1 node url>'
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
  if [ ! -d ${INSTALL_FOLDER}/optimism ] || [ ! -d ${INSTALL_FOLDER}/op-geth ];
  then
    utils::err "function ${FUNCNAME[0]}(): Optimism is not installed. Please "\
'run install-optimism.sh first.'
    trap - ERR
    exit 1
  fi
  export PATH=/home/user/.foundry/bin/:$PATH
  if ! command -v cast &> /dev/null
  then
    utils::err "Cast command not found in PATH"
    trap - ERR
    exit 1
  fi
  trap - ERR
}

#######################################
# Prepare the hosts for the configuration generation
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
  if ! utils::check_args_eq 0 $#; then
    trap - ERR
    exit 1
  fi
  setup_environment
  rm -rf ${DEPLOY_ROOT}
  mkdir -p ${DEPLOY_ROOT}
  mkdir -p ${NETWORK_ROOT}
  trap - ERR
}

#######################################
# Generate and funds admin, batcher, proposer and sequencer accounts
# Globals:
#   None
# Arguments:
#   $1: L1 node url
#   $2: L1 master account private key
# Outputs:
#   None
# Returns:
#   None
#######################################
generate_and_funds_accounts() {
  trap 'exit 1' ERR
  if ! utils::check_args_eq 2 $#; then
    trap - ERRs
    exit 1
  fi
  setup_environment
  local l1_node_url=${1}
  local l1_master_sk=${2}
  local readonly ACCOUNTS_FOLDER=${NETWORK_ROOT}/accounts
  mkdir -p ${ACCOUNTS_FOLDER}
  # Admin
  local output=$(cast wallet new)
  local address=$(echo "$output" | grep "Address:" | awk '{print $2}' | \
    sed 's/^0x//')
  local private_key=$(echo "$output" | grep "Private key:" | awk '{print $3}' \
    | sed 's/^0x//')
  echo ${address}:${private_key} > ${ACCOUNTS_FOLDER}/account_admin
  ./L2/optimism/remote/send.py ${l1_node_url} ${CHAIN_ID} ${l1_master_sk} ${address} \
    ${ADMIN_BALANCE}
  # Batcher
  output=$(cast wallet new)
  address=$(echo "$output" | grep "Address:" | awk '{print $2}' | \
    sed 's/^0x//')
  private_key=$(echo "$output" | grep "Private key:" | awk '{print $3}' \
    | sed 's/^0x//')
  echo ${address}:${private_key} > ${ACCOUNTS_FOLDER}/account_batcher
  ./L2/optimism/remote/send.py ${l1_node_url} ${CHAIN_ID} ${l1_master_sk} ${address} \
    ${BATCHER_BALANCE}
  # Proposer
  output=$(cast wallet new)
  address=$(echo "$output" | grep "Address:" | awk '{print $2}' | \
    sed 's/^0x//')
  private_key=$(echo "$output" | grep "Private key:" | awk '{print $3}' \
    | sed 's/^0x//')
  echo ${address}:${private_key} > ${ACCOUNTS_FOLDER}/account_proposer
  ./L2/optimism/remote/send.py ${l1_node_url} ${CHAIN_ID} ${l1_master_sk} ${address} \
    ${PROPOSER_BALANCE}
  # Sequencer
  output=$(cast wallet new)
  address=$(echo "$output" | grep "Address:" | awk '{print $2}' | \
    sed 's/^0x//')
  private_key=$(echo "$output" | grep "Private key:" | awk '{print $3}' \
    | sed 's/^0x//')
  echo ${address}:${private_key} > ${ACCOUNTS_FOLDER}/account_sequencer
  trap - ERR
}

#######################################
# Configure the network
# Globals:
#   None
# Arguments:
#   $1: L1 node url
# Outputs:
#   None
# Returns:
#   None
#######################################
configure_network() {
  trap 'exit 1' ERR
  if ! utils::check_args_eq 1 $#; then
    trap - ERR
    exit 1
  fi
  setup_environment
  local l1_node_url=${1}
  local readonly DIR=${INSTALL_FOLDER}/optimism/packages/contracts-bedrock
  cp ${DIR}/.envrc.example ${DIR}/.envrc
  sed -i "s|export ETH_RPC_URL=.*|export ETH_RPC_URL=${l1_node_url}|g" \
    ${DIR}/.envrc
  local private_key=$(cat ${NETWORK_ROOT}/accounts/account_admin \
    | cut -d':' -f2)
  sed -i "s|export PRIVATE_KEY=.*|export PRIVATE_KEY=${private_key}|g" \
    ${DIR}/.envrc
  direnv allow ${DIR}
  local output=$(cast block --rpc-url ${l1_node_url} | grep -E \
    "(timestamp|hash|number)")
  local hash=$(echo "$output" | grep "hash" | awk '{print $2}')
  local timestamp=$(echo "$output" | grep "timestamp" | awk '{print $2}')
  local number=$(echo "$output" | grep "number" | awk '{print $2}')
  local admin_address=$(cat ${NETWORK_ROOT}/accounts/account_admin \
    | cut -d':' -f1)
  local batcher_address=$(cat ${NETWORK_ROOT}/accounts/account_batcher \
    | cut -d':' -f1)
  local proposer_address=$(cat ${NETWORK_ROOT}/accounts/account_proposer \
    | cut -d':' -f1)
  local sequencer_address=$(cat ${NETWORK_ROOT}/accounts/account_sequencer \
    | cut -d':' -f1)
  sed -i "s/ADMIN/${admin_address}/g; \
    s/BATCHER/${batcher_address}/g; \
    s/PROPOSER/${proposer_address}/g; \
    s/SEQUENCER/${sequencer_address}/g; \
    s/BLOCKHASH/${hash}/g; \
    s/TIMESTAMP/${timestamp}/g" \
    ${DIR}/deploy-config/getting-started.json
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
  'prepare')
    cmd="prepare ${@}"
    utils::exec_cmd "${cmd}" 'Prepare hosts'
    ;;
  'generate-keys')
    cmd="generate_and_funds_accounts ${@}"
    utils::exec_cmd "${cmd}" 'Generate and funds accounts'
    ;;
  'configure-network')
    cmd="configure_network ${@}"
    utils::exec_cmd "${cmd}" 'Configure network'
    ;;
  *)
    utils::err "Unknown action: ${action}"
    usage
    exit 1
    ;;
esac

trap - ERR
