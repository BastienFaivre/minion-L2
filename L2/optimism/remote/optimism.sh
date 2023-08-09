#!/bin/bash
#===============================================================================
# Author: Bastien Faivre
# Project: EPFL, DCL, Performance and Security Evaluation of Layer 2 Blockchain
#          Systems
# Date: July 2023
# Description: Start/stop/kill Optimism nodes on the host
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
# Start the Optimism nodes
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
  local l1_node_url=http://localhost:8545
  local dir=$(ls ${CONFIG_ROOT}/n* -d)
  if [[ ${dir} == *n0 ]]; then
    local sequencer_address=$(cat ${CONFIG_ROOT}/accounts/account_sequencer \
      | cut -d':' -f1 | sed 's/0x//')
    local sequencer_key=$(cat ${CONFIG_ROOT}/accounts/account_sequencer \
      | cut -d':' -f2 | sed 's/0x//')
    local batcher_key=$(cat ${CONFIG_ROOT}/accounts/account_batcher \
      | cut -d':' -f2 | sed 's/0x//')
    local proposer_key=$(cat ${CONFIG_ROOT}/accounts/account_proposer \
      | cut -d':' -f2 | sed 's/0x//')
    # Start execution engine
    geth \
      --password ${dir}/password \
      --unlock ${sequencer_address} \
      --authrpc.jwtsecret ${dir}/jwt.txt \
      --config ${CONFIG_ROOT}/config.toml \
      --datadir ${dir} \
      --gcmode archive \
      --rollup.disabletxpoolgossip=true \
      > ${CONFIG_ROOT}/geth.out 2>&1 &
    echo $! > ${DEPLOY_ROOT}/pids
    sleep 5
    # Start rollup node
    op-node \
      --l1 ${l1_node_url} \
      --l2 http://localhost:8552 \
      --l2.jwt-secret ${dir}/jwt.txt \
      --p2p.discovery.path ${dir}/opnode_discovery_db \
      --p2p.listen.ip 0.0.0.0 \
      --p2p.listen.tcp ${P2P_LISTEN_PORT} \
      --p2p.listen.udp ${P2P_LISTEN_PORT} \
      --p2p.peerstore.path ${dir}/opnode_peerstore_db \
      --p2p.priv.path ${dir}/opnode_p2p_priv.txt \
      --p2p.sequencer.key ${sequencer_key} \
      --p2p.static "$(cat ${dir}/static-nodes.txt)" \
      --rollup.config ${CONFIG_ROOT}/rollup.json \
      --rpc.addr 0.0.0.0 \
      --rpc.enable-admin \
      --rpc.port 9545 \
      --sequencer.enabled \
      --sequencer.l1-confs 3 \
      --verifier.l1-confs 3 \
      > ${CONFIG_ROOT}/op-node.out 2>&1 &
    echo $! >> ${DEPLOY_ROOT}/pids
    sleep 1
    # Start batcher
    op-batcher \
      --l1-eth-rpc ${l1_node_url} \
      --l2-eth-rpc http://localhost:8547 \
      --max-channel-duration 1 \
      --num-confirmations 1 \
      --poll-interval 1s \
      --private-key ${batcher_key} \
      --resubmission-timeout 30s \
      --rollup-rpc http://localhost:9545 \
      --rpc.addr 0.0.0.0 \
      --rpc.enable-admin \
      --rpc.port 8549 \
      --sub-safety-margin 6 \
      > ${CONFIG_ROOT}/op-batcher.out 2>&1 &
    echo $! >> ${DEPLOY_ROOT}/pids
    sleep 1
    # Start proposer
    op-proposer \
      --l1-eth-rpc ${l1_node_url} \
      --l2oo-address $(cat ${CONFIG_ROOT}/L2OutputOracleProxy_address) \
      --poll-interval 12s \
      --private-key ${proposer_key} \
      --rollup-rpc http://localhost:9545 \
      --rpc.port 8550 \
      > ${CONFIG_ROOT}/op-proposer.out 2>&1 &
    echo $! >> ${DEPLOY_ROOT}/pids
  else
    # Start execution engine
    geth \
      --authrpc.jwtsecret ${dir}/jwt.txt \
      --config ${CONFIG_ROOT}/config.toml \
      --datadir ${dir} \
      --gcmode archive \
      --rollup.disabletxpoolgossip=true \
      --rollup.sequencerhttp $(cat ${CONFIG_ROOT}/sequencer-url) \
      > ${CONFIG_ROOT}/geth.out 2>&1 &
    echo $! > ${DEPLOY_ROOT}/pids
    sleep 5
    # Start rollup node
    op-node \
      --l1 ${l1_node_url} \
      --l2 http://localhost:8552 \
      --l2.jwt-secret ${dir}/jwt.txt \
      --p2p.discovery.path ${dir}/opnode_discovery_db \
      --p2p.listen.ip 0.0.0.0 \
      --p2p.listen.tcp ${P2P_LISTEN_PORT} \
      --p2p.listen.udp ${P2P_LISTEN_PORT} \
      --p2p.peerstore.path ${dir}/opnode_peerstore_db \
      --p2p.priv.path ${dir}/opnode_p2p_priv.txt \
      --p2p.static "$(cat ${dir}/static-nodes.txt)" \
      --rollup.config ${CONFIG_ROOT}/rollup.json \
      --rpc.addr 0.0.0.0 \
      --rpc.port 9545 \
      > ${CONFIG_ROOT}/op-node.out 2>&1 &
    echo $! >> ${DEPLOY_ROOT}/pids
  fi
  # Wait for the nodes to start
  sleep 2
  trap - ERR
}

#######################################
# Stop the Optimism nodes with a signal
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
# Stop the Optimism nodes
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
# Kill the Optimism nodes
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
action=${1}; shift

trap 'exit 1' ERR

utils::ask_sudo
setup_environment
case ${action} in
  start)
    cmd="start"
    utils::exec_cmd "${cmd}" 'Start Optimism nodes'
    ;;
  stop)
    cmd='stop'
    utils::exec_cmd "${cmd}" 'Stop Optimism nodes'
    ;;
  kill)
    cmd='nkill'
    utils::exec_cmd "${cmd}" 'Kill Optimism nodes'
    ;;
  *)
    utils::err "Unknown action ${action}"
    usage
    exit 1
    ;;
esac

trap - ERR
