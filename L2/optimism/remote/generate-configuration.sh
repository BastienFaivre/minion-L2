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
  echo '  generate-keys <L1 node url> <L1 master account private key>'
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
  if [ ! -d ${INSTALL_FOLDER} ]; then
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
  *)
    utils::err "Unknown action: ${action}"
    usage
    exit 1
    ;;
esac

trap - ERR
