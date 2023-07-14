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
  echo 'Usage: $(basename ${0}) start|stop|kill <L1 node url>'
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
# Start the Optimism nodes
# Globals:
#   None
# Arguments:
#   $1: L1 node url
# Outputs:
#   None
# Returns:
#   None
#######################################
start() {
  trap 'exit 1' ERR
  if ! utils::check_args_eq 1 $#; then
    trap - ERR
    exit 1
  fi
  local l1_node_url=${1}
  local dir
  for dir in ${DEPLOY_ROOT}/n*; do
    test -d ${dir} || continue
    local authrpcport=$(cat ${dir}/authrpcport)
    local port=$(cat ${dir}/port)
    local rpcport=$(cat ${dir}/rpcport)
    local wsport=$(cat ${dir}/wsport)
    local p2pport=$(cat ${dir}/p2pport)
    if [ -z ${authrpcport} ] || [ -z ${port} ] || [ -z ${rpcport} ] || \
      [ -z ${wsport} ] || [ -z ${p2pport} ]; then
    utils::err "function ${FUNCNAME[0]}(): Could not find authrpcport, port,"\
" rpcport, wsport or p2pport for node ${dir}"
      trap - ERR
      exit 1
    fi
    if [[ ${dir} == *n0 ]]; then
      local sequencer_address=$(cat ${DEPLOY_ROOT}/accounts/account_sequencer \
        | cut -d':' -f1 | sed 's/0x//')
      local sequencer_key=$(cat ${DEPLOY_ROOT}/accounts/account_sequencer \
        | cut -d':' -f2 | sed 's/0x//')
      local batcher_key=$(cat ${DEPLOY_ROOT}/accounts/account_batcher \
        | cut -d':' -f2 | sed 's/0x//')
      local proposer_key=$(cat ${DEPLOY_ROOT}/accounts/account_proposer \
        | cut -d':' -f2 | sed 's/0x//')
      echo $l1_node_url > ${dir}/l1_node_url
      geth \
        --datadir ${dir} \
        --allow-insecure-unlock \
        --nodiscover \
        --syncmode full \
        --gcmode archive \
        --verbosity 2 \
        --networkid 42069 \
        --authrpc.addr 0.0.0.0 \
        --authrpc.port ${authrpcport} \
        --authrpc.jwtsecret ${dir}/jwt.txt \
        --ws \
        --ws.addr 0.0.0.0 \
        --ws.port ${wsport} \
        --ws.api admin,eth,debug,net,txpool,web3,engine \
        --ws.origins '*' \
        --http \
        --http.addr 0.0.0.0 \
        --http.port ${rpcport} \
        --http.corsdomain '*' \
        --http.api admin,eth,debug,net,txpool,web3,engine \
        --rollup.disabletxpoolgossip=true \
        --password ${dir}/password \
        --allow-insecure-unlock \
        --unlock ${sequencer_address} \
        --mine \
        --miner.etherbase ${sequencer_address} \
        --maxpeers 0 \
        > ${dir}/geth.log 2> ${dir}/geth.err &
      echo $! > ${dir}/pid-geth
      sleep 1
      # --p2p.static /ip4/192.168.201.2/tcp/10000 \
      # --p2p.listen.ip 0.0.0.0 \
      # --p2p.listen.tcp ${p2pport} \
      # --p2p.listen.udp ${p2pport} \
      op-node \
        --l2 http://localhost:${authrpcport} \
        --l2.jwt-secret ${dir}/jwt.txt \
        --l1 ${l1_node_url} \
        --sequencer.enabled \
        --sequencer.l1-confs 3 \
        --verifier.l1-confs 3 \
        --rollup.config ${DEPLOY_ROOT}/rollup.json \
        --rpc.addr 0.0.0.0 \
        --rpc.port ${port} \
        --rpc.enable-admin \
        --p2p.disable \
        --p2p.sequencer.key ${sequencer_key} \
        > ${dir}/op-node.log 2> ${dir}/op-node.err &
      echo $! > ${dir}/pid-op-node
      sleep 1
      op-batcher \
        --l2-eth-rpc http://localhost:${rpcport} \
        --rollup-rpc http://localhost:${port} \
        --poll-interval 1s \
        --sub-safety-margin 6 \
        --num-confirmations 1 \
        --safe-abort-nonce-too-low-count 3 \
        --resubmission-timeout 30s \
        --rpc.addr 0.0.0.0 \
        --rpc.port 11000 \
        --rpc.enable-admin \
        --max-channel-duration 1 \
        --l1-eth-rpc ${l1_node_url} \
        --private-key ${batcher_key} \
        > ${dir}/op-batcher.log 2> ${dir}/op-batcher.err &
      echo $! > ${dir}/pid-op-batcher
      sleep 1
      op-proposer \
        --poll-interval 12s \
        --rpc.port 12000 \
        --rollup-rpc http://localhost:${port} \
        --l2oo-address $(cat ${DEPLOY_ROOT}/L2OutputOracleProxy_address) \
        --private-key ${proposer_key} \
        --l1-eth-rpc ${l1_node_url} \
        --allow-non-finalized \
        > ${dir}/op-proposer.log 2> ${dir}/op-proposer.err &
      echo $! > ${dir}/pid-op-proposer
    else
      geth \
        --datadir ${dir} \
        --allow-insecure-unlock \
        --nodiscover \
        --syncmode full \
        --verbosity 2 \
        --networkid 42069 \
        --authrpc.addr 0.0.0.0 \
        --authrpc.port ${authrpcport} \
        --authrpc.jwtsecret ${dir}/jwt.txt \
        --ws \
        --ws.addr 0.0.0.0 \
        --ws.port ${wsport} \
        --ws.api admin,eth,debug,net,txpool,web3,engine \
        --ws.origins '*' \
        --http \
        --http.addr 0.0.0.0 \
        --http.port ${rpcport} \
        --http.corsdomain '*' \
        --http.api admin,eth,debug,net,txpool,web3,engine \
        --rollup.disabletxpoolgossip=true \
        --rollup.sequencerhttp <TODO> \
        --maxpeers 0 \
        > ${dir}/geth.log 2> ${dir}/geth.err &
      echo $! > ${dir}/pid-geth
      sleep 1
      op-node \
        --l2=http://localhost:${authrpcport} \
        --l2.jwt-secret ${dir}/jwt.txt \
        --rpc.addr 0.0.0.0 \
        --rpc.port ${port} \
        --p2p.static $(cat ${dir}/static-node.txt) \
        --p2p.listen.ip 0.0.0.0 \
        --p2p.listen.tcp ${p2pport} \
        --p2p.listen.udp ${p2pport} \
        --l1 ${l1_node_url} \
        > ${dir}/op-node.log 2> ${dir}/op-node.err &
      echo $! > ${dir}/pid-op-node
    fi
  done
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
  for dir in ${DEPLOY_ROOT}/n*; do
    test -d ${dir} || continue
    test -d ${dir}/keystore || continue
    for pid in ${dir}/pid-*; do
      test -f ${pid} || continue
      kill ${signal} $(cat ${pid})
      rm -rf ${pid}
    done
  done
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

if ! utils::check_args_ge 1 $#; then
  usage
  exit 1
fi
action=${1}; shift

trap 'exit 1' ERR

utils::ask_sudo
setup_environment
case ${action} in
  start)
    cmd="start ${@}"
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
