#!/bin/bash
#===============================================================================
# Author: Bastien Faivre
# Project: EPFL, DCL, Performance and Security Evaluation of Layer 2 Blockchain
#          Systems
# Date: July 2023
# Description: Start/stop/kill Ethereum PoS nodes on the host
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
  echo 'Usage: $(basename ${0}) start|stop|kill'
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
# Get the current finalized block
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   Writes the curl response to stdout
# Returns:
#   None
#######################################
curlFinalizedBlock() {
  curl -X POST -H "Content-Type: application/json" --data \
    '{"jsonrpc":"2.0","method":"eth_getBlockByNumber","params":["finalized", false],"id":1}' \
    http://localhost:8545
}

#######################################
# Start the Ethereum PoS nodes
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   None
# Returns:
#   None
#######################################
start() {
  trap 'exit 1' ERR
  if [ ! -d ${CONFIG_ROOT} ]; then
    utils::err "function ${FUNCNAME[0]}(): No configuration found. Please run "\
'generate-configuration.sh first.'
    trap - ERR
    exit 1
  fi
  # Start execution layer
  geth \
    --datadir ${CONFIG_ROOT}/execution/n* \
    --config ${CONFIG_ROOT}/execution/config.toml \
    --networkid ${CHAIN_ID} \
    --authrpc.jwtsecret ${CONFIG_ROOT}/jwt.txt \
    > ${CONFIG_ROOT}/execution/out.log 2>&1 &
  echo $! > ${DEPLOY_ROOT}/pids
  # Start consensus layer bootnode (only on a single host)
  if [ -d ${CONFIG_ROOT}/consensus/n0 ]; then
    lighthouse boot_node \
      --disable-packet-filter \
      --listen-address 0.0.0.0 \
      --network-dir ${CONFIG_ROOT}/consensus/bootnode \
      --port ${BOOTNODE_PORT} \
      --testnet-dir ${CONFIG_ROOT}/consensus/eth2-config \
      > ${CONFIG_ROOT}/consensus/bootnode/out.log 2>&1 &
    echo $! >> ${DEPLOY_ROOT}/pids
  fi
  # Wait for the nodes to start
  sleep 5
  # Start beacon node
  lighthouse bn \
    --disable-packet-filter \
    --enable-private-discovery \
    --http \
    --staking \
    --datadir ${CONFIG_ROOT}/consensus/n* \
    --debug-level info \
    --enr-address $(cat ${CONFIG_ROOT}/ip) \
    --enr-tcp-port ${BEACON_NODE_ENR_PORT} \
    --enr-udp-port ${BEACON_NODE_ENR_PORT} \
    --execution-endpoints http://localhost:8551 \
    --execution-jwt ${CONFIG_ROOT}/jwt.txt \
    --testnet-dir ${CONFIG_ROOT}/consensus/eth2-config \
    > ${CONFIG_ROOT}/consensus/bn_out.log 2>&1 &
  echo $! >> ${DEPLOY_ROOT}/pids
  # Wait for the node to start
  sleep 5
  # Start validator client
  lighthouse vc \
    --init-slashing-protection \
    --beacon-nodes http://localhost:5052 \
    --datadir ${CONFIG_ROOT}/consensus/n* \
    --debug-level info \
    --suggested-fee-recipient 0x0000000000000000000000000000000000000000 \
    --testnet-dir ${CONFIG_ROOT}/consensus/eth2-config \
    > ${CONFIG_ROOT}/consensus/vc_out.log 2>&1 &
  echo $! >> ${DEPLOY_ROOT}/pids
  # Wait for the node to start
  sleep 5
  # Wait for the first finalized block
  local response=$(curlFinalizedBlock)
  while echo ${response} | grep -i 'error'; do
    sleep 5
    response=$(curlFinalizedBlock)
  done
  trap - ERR
}

#######################################
# Stop the Ethereum PoS nodes with a signal
# Globals:
#   None
# Arguments:
#   $1: the signal to send to the nodes
# Outputs:
#   None
# Returns:
#   None
#######################################
_kill() {
  trap 'exit 1' ERR
  if ! utils::check_args_eq 1 $#; then
    trap - ERR
    exit 1
  fi
  local signal=${1}
  if [ ! -f ${DEPLOY_ROOT}/pids ]; then
    trap - ERR
    exit 0
  fi
  for pid in $(cat ${DEPLOY_ROOT}/pids); do
    if ! kill -0 ${pid} &> /dev/null; then
      continue
    fi
    kill ${signal} ${pid}
  done
  rm -rf ${DEPLOY_ROOT}/pids
  trap - ERR
}

#######################################
# Stop the Ethereum PoS nodes
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   None
# Returns:
#   None
#######################################
stop() {
  trap 'exit 1' ERR
  _kill -SIGINT
  trap - ERR
}

#######################################
# Kill the Ethereum PoS nodes
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   None
# Returns:
#   None
#######################################
nkill() {
  trap 'exit 1' ERR
  _kill -SIGKILL
  trap - ERR
}

#===============================================================================
# MAIN
#===============================================================================

if ! utils::check_args_eq 1 $#; then
  usage
  exit 1
fi
action=${1}

trap 'exit 1' ERR

#utils::ask_sudo
setup_environment
case ${action} in
  start)
    cmd='start'
    utils::exec_cmd "${cmd}" 'Start Ethereum PoS nodes'
    ;;
  stop)
    cmd='stop'
    utils::exec_cmd "${cmd}" 'Stop Ethereum PoS nodes'
    ;;
  kill)
    cmd='nkill'
    utils::exec_cmd "${cmd}" 'Kill Ethereum PoS nodes'
    ;;
  *)
    utils::err "Unknown action ${action}"
    usage
    exit 1
    ;;
esac

trap - ERR
