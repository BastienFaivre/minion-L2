#!/bin/bash
#===============================================================================
# Author: Bastien Faivre
# Project: EPFL, DCL, Performance and Security Evaluation of Layer 2 Blockchain
#          Systems
# Date: July 2023
# Description: Deploy a L2 system over an Ethereum Proof of Stake network
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
  echo '  -f, --hosts-file    remote hosts file'
  echo '    File format: one host per line, with the following format:'
  echo '      <user>@<ip>:<port>'
  echo '    Example:'
  echo '      root@example.com:1234'
  echo '    Please ALWAYS SPECIFY THE PORT, even if it is the default SSH port'
  echo '  -a, --num-accounts  number of accounts (required for step 3)'
  echo '  -s, --steps         steps to do (default: all)'
  echo '    Format: <step>[,<step>]...'
  echo '    Steps:'
  echo '      1: export scripts to remote hosts'
  echo '      2: install and build Ethereum PoS on remote hosts (this may take\'
' few minutes)'
  echo '      3: generate the configuration for the Ethereum PoS network'
  echo '      4: start Ethereum PoS network'
  echo '  -k, --kill          kill the Ethereum PoS network'
  echo '  -c, --clean         clean the remote hosts'
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
  echo 'Minion-L2 is a tool to deploy a Layer 2 system over an Ethereum Proof '\
'of Stake network.'
  echo ''
}

#===============================================================================
# MAIN
#===============================================================================

welcome

remote_hosts_file=''
steps=''
kill=false
clean=false

while [[ $# -gt 0 ]]; do
  case ${1} in
    -h|--help)
      usage
      exit 0
      ;;
    -f|--hosts-file)
      remote_hosts_file=${2}
      shift 2
      ;;
    -a|--num-accounts)
      num_accounts=${2}
      shift 2
      ;;
    -s|--steps)
      steps=${2}
      shift 2
      ;;
    -k|--kill)
      kill=true
      shift
      ;;
    -c|--clean)
      clean=true
      shift
      ;;
    *)
      utils::err "Unknown option: ${1}"
      usage
      exit 1
      ;;
  esac
done

if [[ -z "${remote_hosts_file}" ]] && [[ -z "${num_accounts}" ]] && \
  [[ "${steps}" == '' ]] && [[ "${kill}" == false ]] && \
  [[ "${clean}" == false ]]; then
  usage
  exit 0
fi

if ! utils::check_required_arg 'Remote hosts file' "${remote_hosts_file}"; then
  echo ''
  usage
  exit 1
fi

if [[ "${kill}" == true ]]; then
  cmd="./eth-pos/local/eth-pos.sh ${remote_hosts_file} kill"
  utils::exec_cmd "${cmd}" 'Kill Ethereum PoS network'
  echo ''
  echo 'Task completed successfully!'
  exit 0
fi

if [[ "${clean}" == true ]]; then
  cmd="./scripts/local/clean.sh ${remote_hosts_file}"
  utils::exec_cmd "${cmd}" 'Clean remote hosts'
  echo ''
  echo 'Task completed successfully!'
  exit 0
fi

if [[ "${steps}" == *'3'* ]] && \
  ! utils::check_required_arg 'Number of accounts' "${num_accounts}"; then
  echo ''
  usage
  exit 1
fi

trap 'exit 1' ERR

if [[ "${steps}" == '' ]] || [[ "${steps}" == *'1'* ]]; then
  cmd="./scripts/local/export.sh ${remote_hosts_file}"
  utils::exec_cmd "${cmd}" 'Export scripts to remote hosts'
else
  utils::skip_cmd 'Export scripts to remote hosts'
fi

if [[ "${steps}" == '' ]] || [[ "${steps}" == *'2'* ]]; then
  cmd="./eth-pos/local/install-eth-pos.sh ${remote_hosts_file}"
  utils::exec_cmd "${cmd}" 'Install Ethereum PoS on remote hosts (this may '\
'take few minutes)'
else
  utils::skip_cmd 'Install Ethereum PoS on remote hosts (this may take few '\
'minutes)'
fi

if [[ "${steps}" == '' ]] || [[ "${steps}" == *'3'* ]]; then
  cmd="./eth-pos/local/generate-configuration.sh ${remote_hosts_file} "\
"${num_accounts}"
  utils::exec_cmd "${cmd}" 'Generate the configuration for the Ethereum PoS '\
'network'
else
  utils::skip_cmd 'Generate the configuration for the Ethereum PoS network'
fi

if [[ "${steps}" == '' ]] || [[ "${steps}" == *'4'* ]]; then
  cmd="./eth-pos/local/eth-pos.sh ${remote_hosts_file} start"
  utils::exec_cmd "${cmd}" 'Start Ethereum PoS network'
else
  utils::skip_cmd 'Start Ethereum PoS network'
fi

echo ''
echo 'Task completed successfully!'

trap - ERR
