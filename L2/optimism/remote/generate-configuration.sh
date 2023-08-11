#!/bin/bash
#===============================================================================
# Author: Bastien Faivre
# Project: EPFL, DCL, Performance and Security Evaluation of Layer 2 Blockchain
#          Systems
# Date: August 2023
# Description: Generate configuration
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
  echo '  generate <L1 master account private key> <nodes ip addresses...>'
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
  if [ ! -d ${INSTALL_ROOT}/optimism ] || [ ! -d ${INSTALL_ROOT}/op-geth ];
  then
    utils::err "function ${FUNCNAME[0]}(): Optimism is not installed. Please "\
'run install-optimism.sh first.'
    trap - ERR
    exit 1
  fi
  export PATH=${PATH}:${HOME}/.foundry/bin/
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
  export PATH=${HOME}/${INSTALL_ROOT}/op-geth/build/bin:$PATH
  if ! command -v geth &> /dev/null
  then
    utils::err 'geth command not found in '\
"${HOME}/${INSTALL_ROOT}/op-geth/build/bin"
    trap - ERR
    exit 1
  fi
  if ! command -v bootnode &> /dev/null
  then
    utils::err 'bootnode command not found in '\
"${HOME}/${INSTALL_ROOT}/op-geth/build/bin"
    trap - ERR
    exit 1
  fi
  export PATH=${HOME}/${INSTALL_ROOT}/optimism/op-node/bin:$PATH
  if ! command -v op-node &> /dev/null
  then
    utils::err 'op-node command not found in '\
"${HOME}/${INSTALL_ROOT}/optimism/op-node/bin"
    trap - ERR
    exit 1
  fi
  export PATH=${HOME}/${INSTALL_ROOT}/optimism/op-batcher/bin:$PATH
  if ! command -v op-batcher &> /dev/null
  then
    utils::err 'op-batcher command not found in '\
"${HOME}/${INSTALL_ROOT}/optimism/op-batcher/bin"
    trap - ERR
    exit 1
  fi
  export PATH=${HOME}/${INSTALL_ROOT}/optimism/op-proposer/bin:$PATH
  if ! command -v op-proposer &> /dev/null
  then
    utils::err 'op-proposer command not found in '\
"${HOME}/${INSTALL_ROOT}/optimism/op-proposer/bin"
    trap - ERR
    exit 1
  fi
  export PATH=${HOME}/L2/optimism/remote/bin:$PATH
  if ! command -v p2p-tool &> /dev/null
  then
    utils::err 'p2p-tool command not found in '\
"${HOME}/L2/optimism/remote/bin"
    trap - ERR
    exit 1
  fi
  trap - ERR
}

#######################################
# Generate the configuration
# Globals:
#   None
# Arguments:
#   $1: L1 master account private key
#   $@: nodes ip addresses
# Outputs:
#   None
# Returns:
#   None
#######################################
generate() {
  trap 'exit 1' ERR
  if ! utils::check_args_ge 2 $#; then
    trap - ERR
    exit 1
  fi
  setup_environment
  local l1_master_sk=$1; shift
  local nodes_ip_addresses=($@)
  local l1_node_url=http://localhost:8545
  rm -rf ${DEPLOY_ROOT}
  mkdir -p ${DEPLOY_ROOT}
  mkdir -p ${CONFIG_ROOT}
  (
    cd ${INSTALL_ROOT}/optimism
    git stash
  )
  # Copy Geth configuration
  cp L2/optimism/remote/config.toml ${CONFIG_ROOT}/config.toml
  # Generate and funds accounts
  local readonly ACCOUNTS_FOLDER=${CONFIG_ROOT}/accounts
  mkdir -p ${ACCOUNTS_FOLDER}
  # Admin
  local output=$(cast wallet new)
  local address=$(echo "${output}" | grep 'Address:' | awk '{print $2}')
  local private_key=$(echo "${output}" | grep 'Private key:' | awk '{print $3}')
  echo ${address}:${private_key} > ${ACCOUNTS_FOLDER}/account_admin
  ./L2/optimism/remote/send.py ${l1_node_url} ${ETH_CHAIN_ID} ${l1_master_sk} \
    ${address} ${ADMIN_BALANCE}
  # Batcher
  output=$(cast wallet new)
  address=$(echo "${output}" | grep 'Address:' | awk '{print $2}')
  private_key=$(echo "${output}" | grep 'Private key:' | awk '{print $3}')
  echo ${address}:${private_key} > ${ACCOUNTS_FOLDER}/account_batcher
  ./L2/optimism/remote/send.py ${l1_node_url} ${ETH_CHAIN_ID} ${l1_master_sk} \
    ${address} ${BATCHER_BALANCE}
  # Proposer
  output=$(cast wallet new)
  address=$(echo "${output}" | grep 'Address:' | awk '{print $2}')
  private_key=$(echo "${output}" | grep 'Private key:' | awk '{print $3}')
  echo ${address}:${private_key} > ${ACCOUNTS_FOLDER}/account_proposer
  ./L2/optimism/remote/send.py ${l1_node_url} ${ETH_CHAIN_ID} ${l1_master_sk} \
    ${address} ${PROPOSER_BALANCE}
  # Sequencer
  output=$(cast wallet new)
  address=$(echo "${output}" | grep 'Address:' | awk '{print $2}')
  private_key=$(echo "${output}" | grep 'Private key:' | awk '{print $3}')
  echo ${address}:${private_key} > ${ACCOUNTS_FOLDER}/account_sequencer
  echo http://${nodes_ip_addresses[0]}:8547 > ${CONFIG_ROOT}/sequencer-url
  # Configure network
  local readonly DIR=${INSTALL_ROOT}/optimism/packages/contracts-bedrock
  rm -rf ${DIR}/.envrc
  cp ${DIR}/.envrc.example ${DIR}/.envrc
  sed -i "s|export ETH_RPC_URL=.*|export ETH_RPC_URL=${l1_node_url}|g" \
    ${DIR}/.envrc
  local private_key=$(cat ${CONFIG_ROOT}/accounts/account_admin \
    | cut -d':' -f2)
  sed -i "s|export PRIVATE_KEY=.*|export PRIVATE_KEY=${private_key}|g" \
    ${DIR}/.envrc
  direnv allow ${DIR}
  local output=$(cast block finalized --rpc-url ${l1_node_url} | grep -E \
    "(timestamp|hash|number)")
  local hash=$(echo "${output}" | grep "hash" | awk '{print $2}')
  local timestamp=$(echo "${output}" | grep "timestamp" | awk '{print $2}')
  local number=$(echo "${output}" | grep "number" | awk '{print $2}')
  local admin_address=$(cat ${CONFIG_ROOT}/accounts/account_admin \
    | cut -d':' -f1)
  local batcher_address=$(cat ${CONFIG_ROOT}/accounts/account_batcher \
    | cut -d':' -f1)
  local proposer_address=$(cat ${CONFIG_ROOT}/accounts/account_proposer \
    | cut -d':' -f1)
  local sequencer_address=$(cat ${CONFIG_ROOT}/accounts/account_sequencer \
    | cut -d':' -f1)
  sed -i "s/ADMIN/${admin_address}/g; \
    s/BATCHER/${batcher_address}/g; \
    s/PROPOSER/${proposer_address}/g; \
    s/SEQUENCER/${sequencer_address}/g; \
    s/BLOCKHASH/${hash}/g; \
    s/TIMESTAMP/${timestamp}/g; \
    s/\"l1ChainID\": 5,/\"l1ChainID\": ${ETH_CHAIN_ID},/g; \
    s/\"l2ChainID\": 42069,/\"l2ChainID\": ${OP_CHAIN_ID},/g" \
    ${DIR}/deploy-config/getting-started.json
  # due to https://github.com/ethereum-optimism/optimism/commit/069f9c22775805c851919a594de817c8843182b6
  jq '. + {"l1BlockTime": 3}' ${DIR}/deploy-config/getting-started.json \
    > ${DIR}/deploy-config/getting-started.json.tmp
  mv ${DIR}/deploy-config/getting-started.json.tmp \
    ${DIR}/deploy-config/getting-started.json
  # Deploy L1 contracts
  (
    private_key=$(cat ${CONFIG_ROOT}/accounts/account_admin \
      | cut -d':' -f2)
    cd ${INSTALL_ROOT}/optimism/packages/contracts-bedrock
    rm -rf L2OutputOracleProxy_address L1StandardBridgeProxy_address
    direnv allow . && eval "$(direnv export bash)"
    rm -rf deployments/getting-started
    mkdir -p deployments/getting-started
    forge script scripts/Deploy.s.sol:Deploy --private-key ${private_key} \
      --broadcast --rpc-url ${l1_node_url} > /dev/null 2>&1
    forge script scripts/Deploy.s.sol:Deploy --sig 'sync()' --private-key \
      ${private_key} --broadcast --rpc-url ${l1_node_url} > /dev/null 2>&1
    FILES=(
      "L2OutputOracleProxy"
      "L1StandardBridgeProxy"
      "AddressManager"
      "L1CrossDomainMessengerProxy"
      "OptimismPortal"
    )
    for FILE in "${FILES[@]}"; do
      jq -r .address deployments/getting-started/${FILE}.json > ${FILE}_address
      cp ${FILE}_address ${HOME}/${CONFIG_ROOT}/${FILE}_address
      cp ${FILE}_address ${HOME}/L2/optimism/remote/bridge/${FILE}_address
    done
  )
  # Generate L2 configuration
  (
    cd ${INSTALL_ROOT}/optimism/op-node
    rm -rf genesis.json rollup.json
    go run cmd/main.go genesis l2 \
      --deploy-config \
      ../packages/contracts-bedrock/deploy-config/getting-started.json \
      --deployment-dir \
      ../packages/contracts-bedrock/deployments/getting-started/ \
      --outfile.l2 genesis.json \
      --outfile.rollup rollup.json \
      --l1-rpc ${l1_node_url} \
      > /dev/null 2>&1
    cp genesis.json ${HOME}/${CONFIG_ROOT}/genesis.json
    cp rollup.json ${HOME}/${CONFIG_ROOT}/rollup.json
  )
  # Create nodes directories with p2p keys
  local dir
  local i=0
  for ip in ${nodes_ip_addresses[@]}; do
    dir=${CONFIG_ROOT}/n${i}
    mkdir -p ${dir}
    p2p-tool --privKeyPath ${dir}/opnode_p2p_priv.txt --peerIDPath \
      ${dir}/opnode_peer_id.txt
    echo /ip4/${ip}/tcp/9222/p2p/$(cat ${dir}/opnode_peer_id.txt) | tr '\n' ','\
      >> ${CONFIG_ROOT}/static-nodes.txt
    if [[ ${dir} == *n0 ]]; then
      echo 'pwd' > ${dir}/password
      cat ${CONFIG_ROOT}/accounts/account_sequencer | cut -d':' -f2 \
        | sed 's/0x//' > ${dir}/block-signer-key
      geth account import --datadir ${dir} --password ${dir}/password \
        ${dir}/block-signer-key
    fi
    openssl rand -hex 32 > ${dir}/jwt.txt
    geth init --datadir ${dir} ${CONFIG_ROOT}/genesis.json > /dev/null 2>&1
    i=$((i+1))
  done
  sed -i 's/.$//' ${CONFIG_ROOT}/static-nodes.txt
  i=0
  for ip in ${nodes_ip_addresses[@]}; do
    dir=${CONFIG_ROOT}/n${i}
    cp ${CONFIG_ROOT}/static-nodes.txt ${dir}/static-nodes.txt
    local peerid=$(cat ${dir}/opnode_peer_id.txt)
    local static_nodes=$(cat ${dir}/static-nodes.txt | \
      sed -e "s,/ip4/${ip}/tcp/${P2P_LISTEN_PORT}/p2p/${peerid}.*$,," \
        -e "s/^,//" \
        -e "s/,$//")
    echo ${static_nodes} > ${dir}/static-nodes.txt
    i=$((i+1))
  done
  # Create archive
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
    cmd="generate ${@}"
    utils::exec_cmd "${cmd}" 'Generate the configuration'
    ;;
  *)
    utils::err "Unknown action: ${action}"
    usage
    exit 1
    ;;
esac

trap - ERR
