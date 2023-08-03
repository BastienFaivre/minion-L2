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
  echo "Usage: $(basename ${0}) <L2> [options...]"
  echo 'L2:'
  echo '  optimism            Optimism (https://www.optimism.io/)'
  echo 'Options:'
  echo '  -h, --help          display this message and exit'
  echo '  -f, --hosts-file    (required) remote hosts file'
  echo '    File format: one host per line, with the following format:'
  echo '      <user>@<ip>:<port>'
  echo '    Example:'
  echo '      root@example.com:1234'
  echo '    Please ALWAYS SPECIFY THE PORT, even if it is the default SSH port'
  echo '  -a, --num-accounts  (required for step 3) number of founded accounts'\
' on L1'
  echo '  -s, --steps         steps to do (default: all)'
  echo '    Format: <step>[,<step>]...'
  echo '    Steps:'
  echo '      1: export scripts to remote hosts'
  echo '      2: install and build L1 and L2 on remote hosts (this may take a '\
'long time)'
  echo '      3: generate the configuration for the L1 network'
  echo '      4: start the L1 network'
  echo '      5: generate the configuration for the L2 network'
  echo '      6: start the L2 network'
  echo '  -k, --kill          kill the networks'
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

l2=${1}
if [[ "${l2}" != 'optimism' ]]; then
  if [[ $# -eq 0 ]]; then
    utils::err 'Missing L2'
  else
    utils::err "Unknown L2: ${l2}"
  fi
  echo ''
  usage
  exit 1
fi
shift

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
      echo ''
      usage
      exit 1
      ;;
  esac
done

if ! utils::check_required_arg 'Remote hosts file' "${remote_hosts_file}"; then
  echo ''
  usage
  exit 1
fi

if [[ "${kill}" == true ]]; then
  cmd="./L2/${l2}/local/${l2}.sh ${remote_hosts_file} kill"
  utils::exec_cmd "${cmd}" "Kill ${l2} network"
  cmd="./eth-pos/local/eth-pos.sh ${remote_hosts_file} kill"
  utils::exec_cmd "${cmd}" "Kill Ethereum PoS network"
  echo ''
  echo 'Task completed successfully!'
  exit 0
fi

if [[ "${steps}" == '' ]]; then
  steps='1,2,3,4,5,6'
fi

if [[ "${steps}" == *'6'* ]]; then
  cmd="./L2/${l2}/local/${l2}.sh ${remote_hosts_file} kill"
  utils::exec_cmd "${cmd}" "Kill ${l2} network"
fi

if [[ "${steps}" == *'4'* ]]; then
  cmd="./eth-pos/local/eth-pos.sh ${remote_hosts_file} kill"
  utils::exec_cmd "${cmd}" "Kill Ethereum PoS network"
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

if [[ "${steps}" == *'1'* ]]; then
  cmd="./scripts/local/export.sh ${remote_hosts_file}"
  utils::exec_cmd "${cmd}" 'Export scripts to remote hosts'
else
  utils::skip_cmd 'Export scripts to remote hosts'
fi

if [[ "${steps}" == *'2'* ]]; then
  cmd="./eth-pos/local/install-eth-pos.sh ${remote_hosts_file}"
  utils::exec_cmd "${cmd}" 'Install Ethereum PoS on remote hosts (this may '\
'take a long time)'
  cmd="./L2/${l2}/local/install-${l2}.sh ${remote_hosts_file}"
  utils::exec_cmd "${cmd}" "Install ${l2} on remote hosts (this may take a "\
'long time)'
else
  utils::skip_cmd 'Install Ethereum PoS on remote hosts (this may take a long '\
'time)'
  utils::skip_cmd "Install ${l2} on remote hosts (this may take a long time)"
fi

if [[ "${steps}" == *'3'* ]]; then
  cmd="./eth-pos/local/generate-configuration.sh ${remote_hosts_file} "\
"${num_accounts}"
  utils::exec_cmd "${cmd}" 'Generate the configuration for the Ethereum PoS '\
'network'
else
  utils::skip_cmd 'Generate the configuration for the Ethereum PoS network'
fi

if [[ "${steps}" == *'4'* ]]; then
  cmd="./eth-pos/local/eth-pos.sh ${remote_hosts_file} start"
  utils::exec_cmd "${cmd}" 'Start Ethereum PoS network'
else
  utils::skip_cmd 'Start Ethereum PoS network'
fi

if [[ "${steps}" == *'5'* ]]; then
  cmd="./L2/${l2}/local/generate-configuration.sh ${remote_hosts_file}"
  utils::exec_cmd "${cmd}" "Generate the configuration for the ${l2} network"
else
  utils::skip_cmd "Generate the configuration for the ${l2} network"
fi

if [[ "${steps}" == *'6'* ]]; then
  cmd="./L2/${l2}/local/${l2}.sh ${remote_hosts_file} start"
  utils::exec_cmd "${cmd}" "Start ${l2} network"
else
  utils::skip_cmd "Start ${l2} network"
fi

echo ''
echo 'Task completed successfully!'

trap - ERR
