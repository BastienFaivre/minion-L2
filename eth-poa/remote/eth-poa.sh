#!/bin/bash
#===============================================================================
# Author: Bastien Faivre
# Project: EPFL, DCL, Performance and Security Evaluation of Layer 2 Blockchain
#          Systems
# Date: June 2023
# Description: Start/stop/kill Ethereum PoA nodes on the host
# Source: TODO
#===============================================================================

#===============================================================================
# IMPORTS
#===============================================================================

. eth-poa/constants.sh
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
  if [ ! -d ${INSTALL_ROOT} ]; then
    utils::err "function ${FUNCNAME[0]}(): Ethereum is not installed. Please \"
'run install-eth-poa.sh first."
    trap - ERR
    exit 1
  fi
  export PATH=${PATH}:${HOME}/${INSTALL_ROOT}/build/bin
  if ! command -v geth &> /dev/null
  then
    utils::err "geth command not found in ${INSTALL_ROOT}/build/bin"
    trap - ERR
    exit 1
  fi
  trap - ERR
}

#######################################
# Start the Ethereum PoA nodes
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
  for dir in ${DEPLOY_ROOT}/n*; do
    test -d ${dir} || continue
    test -d ${dir}/keystore || continue
    if [ ! -f ${dir}/config.toml ]; then
      utils::err "function ${FUNCNAME[0]}(): Node ${dir} has not been "\
"configured"
      trap - ERR
      exit 1
    fi
  done
  for dir in ${DEPLOY_ROOT}/n*; do
    test -d ${dir} || continue
    test -d ${dir}/keystore || continue
    local authrpcport=$(cat ${dir}/authrpcport)
    local port=$(cat ${dir}/port)
    local rpcport=$(cat ${dir}/rpcport)
    local wsport=$(cat ${dir}/wsport)
    if [ -z ${authrpcport} ] [ -z ${port} ] || [ -z ${rpcport} ] || \
      [ -z ${wsport} ]; then
      utils::err "function ${FUNCNAME[0]}(): Could not find authrpcport, port,"\
" rpcport or wsport for node ${dir}"
      trap - ERR
      exit 1
    fi
    local address=$(ls ${dir}/keystore/UTC--*)
    if [ -z ${address} ]; then
      utils::err "function ${FUNCNAME[0]}(): Could not find address for node "\
"${dir}"
      trap - ERR
      exit 1
    fi
    address=${address##*--}
    geth --datadir ${dir} \
      --allow-insecure-unlock \
      --unlock ${address} \
      --password ${dir}/password \
      --nodiscover \
      --syncmode full \
      --mine \
      --miner.etherbase ${address} \
      --verbosity 2 \
      --networkid ${CHAIN_ID} \
      --authrpc.addr 0.0.0.0 \
      --authrpc.port ${authrpcport} \
      --ws \
      --ws.addr 0.0.0.0 \
      --ws.port ${wsport} \
      --ws.api admin,eth,debug,miner,net,txpool,web3 \
      --ws.origins '*' \
      --port ${port} \
      --http \
      --http.addr 0.0.0.0 \
      --http.port ${rpcport} \
      --http.corsdomain '*' \
      --http.api admin,eth,debug,miner,net,txpool,web3 \
      --config ${dir}/config.toml \
      > ${dir}/out.log 2> ${dir}/err.log &
    local pid=$!
    echo ${pid} > ${dir}/pid
  done
  # Wait for the nodes to start
  sleep 2
  trap - ERR
}

#######################################
# Stop the Ethereum PoA nodes with a signal
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
    test -f ${dir}/pid || continue
    local pid=$(cat ${dir}/pid)
    kill ${signal} ${pid}
    rm ${dir}/pid
  done
  trap - ERR
}

#######################################
# Stop the Ethereum PoA nodes
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
# Kill the Ethereum PoA nodes
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

utils::ask_sudo
setup_environment
case ${action} in
  start)
    cmd='start'
    utils::exec_cmd "${cmd}" 'Start Ethereum PoA nodes'
    ;;
  stop)
    cmd='stop'
    utils::exec_cmd "${cmd}" 'Stop Ethereum PoA nodes'
    ;;
  kill)
    cmd='nkill'
    utils::exec_cmd "${cmd}" 'Kill Ethereum PoA nodes'
    ;;
  *)
    utils::err "Unknown action ${action}"
    usage
    exit 1
    ;;
esac

trap - ERR
