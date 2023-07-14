#!/bin/bash
#===============================================================================
# Author: Bastien Faivre
# Project: EPFL, DCL, Performance and Security Evaluation of Layer 2 Blockchain
#          Systems
# Date: July 2023
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
  echo '  prepare <nodes names>'
  echo '  generate-keys <L1 node url> <L1 master account private key>'
  echo '  configure-network <L1 node url>'
  echo '  deploy-L1-contracts <L1 node url>'
  echo '  generate-L2-configuration <L1 node url>'
  echo '  initialize-nodes'
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
    utils::err 'Cast command not found in /home/user/.foundry/bin/'
    trap - ERR
    exit 1
  fi
  if ! command -v forge &> /dev/null
  then
    utils::err 'Forge command not found in /home/user/.foundry/bin/'
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
  export PATH=${HOME}/${INSTALL_FOLDER}/op-geth/build/bin:$PATH
  if ! command -v geth &> /dev/null
  then
    utils::err 'geth command not found in '\
"${HOME}/${INSTALL_FOLDER}/op-geth/build/bin"
    trap - ERR
    exit 1
  fi
  export PATH=${HOME}/${INSTALL_FOLDER}/optimism/op-node/bin:$PATH
  if ! command -v op-node &> /dev/null
  then
    utils::err 'op-node command not found in '\
"${HOME}/${INSTALL_FOLDER}/optimism/op-node/bin"
    trap - ERR
    exit 1
  fi
  export PATH=${HOME}/${INSTALL_FOLDER}/optimism/op-batcher/bin:$PATH
  if ! command -v op-batcher &> /dev/null
  then
    utils::err 'op-batcher command not found in '\
"${HOME}/${INSTALL_FOLDER}/optimism/op-batcher/bin"
    trap - ERR
    exit 1
  fi
  export PATH=${HOME}/${INSTALL_FOLDER}/optimism/op-proposer/bin:$PATH
  if ! command -v op-proposer &> /dev/null
  then
    utils::err 'op-proposer command not found in '\
"${HOME}/${INSTALL_FOLDER}/optimism/op-proposer/bin"
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
  local ip=$(hostname -I | awk '{print $1}')
  local dir
  for name in "$@"; do
    dir=${DEPLOY_ROOT}/${name}
    mkdir -p ${dir}
    echo ${authrpcport} > ${dir}/authrpcport
    echo ${port} > ${dir}/port
    echo ${rpcport} > ${dir}/rpcport
    echo ${wsport} > ${dir}/wsport
    echo http://${ip}:${port} >> ${DEPLOY_ROOT}/static-nodes-${ip}
    authrpcport=$((authrpcport+1))
    port=$((port+1))
    rpcport=$((rpcport+1))
    wsport=$((wsport+1))
  done
  cd ${INSTALL_FOLDER}/optimism
  git stash
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
  local readonly ACCOUNTS_FOLDER=${DEPLOY_ROOT}/accounts
  mkdir -p ${ACCOUNTS_FOLDER}
  # Admin
  local output=$(cast wallet new)
  local address=$(echo "$output" | grep "Address:" | awk '{print $2}')
  local private_key=$(echo "$output" | grep "Private key:" | awk '{print $3}')
  echo ${address}:${private_key} > ${ACCOUNTS_FOLDER}/account_admin
  ./L2/optimism/remote/send.py ${l1_node_url} ${CHAIN_ID} ${l1_master_sk} ${address} \
    ${ADMIN_BALANCE}
  # Batcher
  output=$(cast wallet new)
  address=$(echo "$output" | grep "Address:" | awk '{print $2}')
  private_key=$(echo "$output" | grep "Private key:" | awk '{print $3}')
  echo ${address}:${private_key} > ${ACCOUNTS_FOLDER}/account_batcher
  ./L2/optimism/remote/send.py ${l1_node_url} ${CHAIN_ID} ${l1_master_sk} ${address} \
    ${BATCHER_BALANCE}
  # Proposer
  output=$(cast wallet new)
  address=$(echo "$output" | grep "Address:" | awk '{print $2}')
  private_key=$(echo "$output" | grep "Private key:" | awk '{print $3}')
  echo ${address}:${private_key} > ${ACCOUNTS_FOLDER}/account_proposer
  ./L2/optimism/remote/send.py ${l1_node_url} ${CHAIN_ID} ${l1_master_sk} ${address} \
    ${PROPOSER_BALANCE}
  # Sequencer
  output=$(cast wallet new)
  address=$(echo "$output" | grep "Address:" | awk '{print $2}')
  private_key=$(echo "$output" | grep "Private key:" | awk '{print $3}')
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
  rm -rf ${DIR}/.envrc
  cp ${DIR}/.envrc.example ${DIR}/.envrc
  sed -i "s|export ETH_RPC_URL=.*|export ETH_RPC_URL=${l1_node_url}|g" \
    ${DIR}/.envrc
  local private_key=$(cat ${DEPLOY_ROOT}/accounts/account_admin \
    | cut -d':' -f2)
  sed -i "s|export PRIVATE_KEY=.*|export PRIVATE_KEY=${private_key}|g" \
    ${DIR}/.envrc
  direnv allow ${DIR}
  local output=$(cast block --rpc-url ${l1_node_url} | grep -E \
    "(timestamp|hash|number)")
  local hash=$(echo "$output" | grep "hash" | awk '{print $2}')
  local timestamp=$(echo "$output" | grep "timestamp" | awk '{print $2}')
  local number=$(echo "$output" | grep "number" | awk '{print $2}')
  local admin_address=$(cat ${DEPLOY_ROOT}/accounts/account_admin \
    | cut -d':' -f1)
  local batcher_address=$(cat ${DEPLOY_ROOT}/accounts/account_batcher \
    | cut -d':' -f1)
  local proposer_address=$(cat ${DEPLOY_ROOT}/accounts/account_proposer \
    | cut -d':' -f1)
  local sequencer_address=$(cat ${DEPLOY_ROOT}/accounts/account_sequencer \
    | cut -d':' -f1)
  sed -i "s/ADMIN/${admin_address}/g; \
    s/BATCHER/${batcher_address}/g; \
    s/PROPOSER/${proposer_address}/g; \
    s/SEQUENCER/${sequencer_address}/g; \
    s/BLOCKHASH/${hash}/g; \
    s/TIMESTAMP/${timestamp}/g; \
    s/\"l1ChainID\": 5,/\"l1ChainID\": ${CHAIN_ID},/g" \
    ${DIR}/deploy-config/getting-started.json

  trap - ERR
}

#######################################
# Deploy the L1 contracts
# Globals:
#   None
# Arguments:
#   $1: L1 node url
# Outputs:
#   None
# Returns:
#   None
#######################################
deploy_L1_contracts() {
  trap 'exit 1' ERR
  if ! utils::check_args_eq 1 $#; then
    trap - ERR
    exit 1
  fi
  setup_environment
  local l1_node_url=${1}
  local private_key=$(cat ${DEPLOY_ROOT}/accounts/account_admin \
    | cut -d':' -f2)
  cd ${INSTALL_FOLDER}/optimism/packages/contracts-bedrock
  rm -rf L2OutputOracleProxy_address
  direnv allow . && eval "$(direnv export bash)"
  rm -rf deployments/getting-started
  mkdir -p deployments/getting-started
  forge script scripts/Deploy.s.sol:Deploy --private-key ${private_key} \
    --broadcast --rpc-url ${l1_node_url}
  forge script scripts/Deploy.s.sol:Deploy --sig 'sync()' --private-key \
    ${private_key} --broadcast --rpc-url ${l1_node_url}
  jq -r '.address' deployments/getting-started/L2OutputOracleProxy.json \
    > L2OutputOracleProxy_address
  trap - ERR
}

#######################################
# Generate the L2 configuration
# Globals:
#   None
# Arguments:
#   $1: L1 node url
# Outputs:
#   None
# Returns:
#   None
#######################################
generate_L2_configuration() {
  trap 'exit 1' ERR
  if ! utils::check_args_eq 1 $#; then
    trap - ERR
    exit 1
  fi
  setup_environment
  local l1_node_url=${1}
  cd ${INSTALL_FOLDER}/optimism/op-node
  rm -rf genesis.json rollup.json
  go run cmd/main.go genesis l2 \
    --deploy-config \
    ../packages/contracts-bedrock/deploy-config/getting-started.json \
    --deployment-dir \
    ../packages/contracts-bedrock/deployments/getting-started/ \
    --outfile.l2 genesis.json \
    --outfile.rollup rollup.json \
    --l1-rpc ${l1_node_url}
  trap - ERR
}

#######################################
# Initialize nodes
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   None
# Returns:
#   None
#######################################
initialize_nodes() {
  trap 'exit 1' ERR
  if ! utils::check_args_eq 0 $#; then
    trap - ERR
    exit 1
  fi
  setup_environment
  local dir
  for dir in ${DEPLOY_ROOT}/n*; do
    if [[ ${dir} == *n0 ]]; then
      echo 'pwd' > ${dir}/password
      cat ${DEPLOY_ROOT}/accounts/account_sequencer | cut -d':' -f2 \
        | sed 's/0x//' > ${dir}/block-signer-key
      geth account import --datadir=${dir} --password=${dir}/password \
        ${dir}/block-signer-key
      openssl rand -hex 32 > ${dir}/jwt.txt
    fi
    geth init --datadir=${dir} ${DEPLOY_ROOT}/genesis.json
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
  'deploy-L1-contracts')
    cmd="deploy_L1_contracts ${@}"
    utils::exec_cmd "${cmd}" 'Deploy L1 contracts'
    ;;
  'generate-L2-configuration')
    cmd="generate_L2_configuration ${@}"
    utils::exec_cmd "${cmd}" 'Generate L2 configuration'
    ;;
  'initialize-nodes')
    cmd="initialize_nodes ${@}"
    utils::exec_cmd "${cmd}" 'Initialize nodes'
    ;;
  *)
    utils::err "Unknown action: ${action}"
    usage
    exit 1
    ;;
esac

trap - ERR
