#!/bin/bash
#===============================================================================
# Author: Bastien Faivre
# Project: EPFL, DCL, Performance and Security Evaluation of Layer 2 Blockchain
#          Systems
# Date: June 2023
# Description: Deploy an L2 system on an Ethereum PoA network
#===============================================================================

#===============================================================================
# IMPORTS
#===============================================================================

caller_dir=$(pwd)
cd "$(dirname "${0}")"
. ./scripts/utils.sh

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
  echo "Usage: $(basename ${0}) [options...]"
  echo 'Options:'
  echo '  -h, --help          display this message and exit'
  echo '  -n, --num-nodes     number of nodes'
  echo '  -f, --hosts-file    remote hosts file'
  echo '    File format: one host per line, with the following format:'
  echo '      <host>:<port>'
  echo '    Example:'
  echo '      root@example.com:1234'
  echo '    Please ALWAYS SPECIFY THE PORT, even if it is the default SSH port'
  echo '  -s, --start-at      start at the given step, default: 1'
  echo '  -e, --end-at        end at the given step (inclusive), default: 3'
  echo '    Steps:'
  echo '      1: export scripts to remote hosts'
  echo '      2: install Ethereum PoA on remote hosts (this may take few '\
'minutes)'
  echo '      3: generate the configuration for the Ethereum PoA network'
}

#######################################
# Display welcome message
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   Writes the welcome message to stdout
# Returns:
#   None
#######################################
welcome() {
  local terminal_width=$(tput cols)
  readonly MIN_WIDTH=48
  # print '=' for the width

  if ((terminal_width >= MIN_WIDTH)); then
    echo 'Welcome to'
    echo ' __  __ _       _                   _     ____'
    echo '|  \/  (_)_ __ (_) ___  _ __       | |   |___ \'
    echo "| |\/| | | '_ \| |/ _ \| '_ \ _____| |     __) |"
    echo '| |  | | | | | | | (_) | | | |_____| |___ / __/'
    echo '|_|  |_|_|_| |_|_|\___/|_| |_|     |_____|_____|'
    echo ''
  else
    echo 'Welcome to Minion-L2!'
  fi
  echo 'Minion-L2 is a tool to deploy a private Layer 2 system on an Ethereum '\
'PoA network.'
  echo ''
}

#===============================================================================
# MAIN
#===============================================================================

welcome

num_nodes=''
remote_hosts_file=''
start_at=1

while [[ $# -gt 0 ]]; do
  case ${1} in
    -h|--help)
      usage
      exit 0
      ;;
    -n|--num-nodes)
      num_nodes=${2}
      shift 2
      ;;
    -f|--hosts-file)
      remote_hosts_file=${2}
      shift 2
      ;;
    -s|--start-at)
      start_at=${2}
      shift 2
      ;;
    *)
      utils::err "Unknown option: ${1}"
      usage
      exit 1
      ;;
  esac
done    

if ! utils::check_required_arg 'Number of nodes' "${num_nodes}" \
  || ! utils::check_required_arg 'Remote hosts file' "${remote_hosts_file}"; then
  echo ''
  usage
  exit 1
fi

trap 'exit 1' ERR

if ((start_at <= 1)); then
  cmd="./scripts/local/export.sh ${remote_hosts_file}"
  utils::exec_cmd "${cmd}" 'Export scripts to remote hosts'
else
  utils::skip_cmd 'Export scripts to remote hosts'
fi

if ((start_at <= 2)); then
  cmd="./eth-poa/local/install-eth-poa.sh ${remote_hosts_file}"
  utils::exec_cmd "${cmd}" 'Install Ethereum PoA on remote hosts (this may '\
'take few minutes)'
else
  utils::skip_cmd 'Install Ethereum PoA on remote hosts (this may take few '\
'minutes)'
fi

if ((start_at <= 3)); then
  cmd="./eth-poa/local/generate-configuration.sh ${remote_hosts_file} "\
"${num_nodes}"
  utils::exec_cmd "${cmd}" 'Generate the configuration for the Ethereum PoA '\
'network'
else
  utils::skip_cmd 'Generate the configuration for the Ethereum PoA network'
fi

echo ''
echo 'Deployment successful!'

trap - ERR
