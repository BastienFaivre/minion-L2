#!/bin/bash
#===============================================================================
# Author: Bastien Faivre
# Project: EPFL, DCL, Performance and Security Evaluation of Layer 2 Blockchain
#          Systems
# Date: June 2023
# Description: Define a set of utility functions
# Source: https://github.com/BastienFaivre/bash-scripts/blob/main/utils/utils.sh
#===============================================================================

#######################################
# Show an error
# Globals:
#   None
# Arguments:
#   $*: messages to display
# Outputs:
#   Writes error to stderr
# Returns:
#   None
# Sources:
#   https://google.github.io/styleguide/shellguide.html#stdout-vs-stderr
#######################################
utils::err() {
  echo -e "[$(date +'%Y-%m-%d %H:%M:%S')] \033[0;31mERROR:\033[0m $*" >&2
}

#######################################
# Ask for sudo
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   Writes error to stderr if sudo refused
# Returns:
#   None
#######################################
utils::ask_sudo() {
  if [[ "$#" -ne 0 ]]; then
    utils::err 'function ask_sudo(): No argument expected.'
    exit 1
  fi
  sudo -v > /dev/null 2>&1
  if [ "$?" -ne 0 ]; then
    utils::err 'function ask_sudo(): Super user is required.'
    exit 1
  fi
}

#######################################
# Execute a command while displaying a loader
# Globals:
#   None
# Arguments:
#   $1: command to execute
#   $2: command explanation
# Outputs:
#   Writes loader and command explanation to stdout
# Returns:
#   1 if the command failed, 0 otherwise
#######################################
utils::exec_cmd() {
  if [[ "$#" -ne 2 ]]; then
    utils::err 'function exec_cmd(): 2 arguments expected.'
    exit 1
  fi
  local cmd="${1}"
  local cmd_explanation="${2}"
  ${cmd} > /tmp/log.txt 2> /tmp/log.txt &
  local pid=$!
  local i=1
  local sp='⣾⣽⣻⢿⡿⣟⣯⣷'
  trap 'kill ${pid} 2 > /dev/null 2>&1' EXIT
  while kill -0 ${pid} 2> /dev/null; do
    echo -ne "\r${sp:i++%${#sp}:1} ${cmd_explanation}"
    sleep 0.1
  done
  wait ${pid}
  if [ "$?" -ne 0 ]; then
    echo -ne "\r\033[0;31mFAIL\033[0m ${cmd_explanation}\n"
    cat /tmp/log.txt
    rm /tmp/log.txt
    trap - EXIT
    return 1
  else
    echo -ne "\r\033[0;32mDONE\033[0m ${cmd_explanation}\n"
    rm /tmp/log.txt
    trap - EXIT
    return 0
  fi
}

#######################################
# Execute a command on all remote hosts in parallel while displaying a loader
# Globals:
#   None
# Arguments:
#   $1: command to execute
#   $2: command explanation
#   $3: remote hosts list file
# Outputs:
#   Writes loader and command explanation to stdout
# Returns:
#   1 if the command failed, 0 otherwise
#######################################
utils::exec_cmd_on_remote_hosts() {
  if [[ "$#" -ne 3 ]]; then
    utils::err 'function exec_cmd_on_remote_hosts(): 3 arguments expected.'
    exit 1
  fi
  local cmd="${1}"
  local cmd_explanation="${2}"
  local remote_hosts_file="${3}"
  local array_of_pids=()
  local index=0
  while IFS=':' read -r host port; do
    {
      local res
      res=$(ssh -p ${port} ${host} "${cmd}" > /tmp/log_${host}_${port}.txt \
        2> /tmp/log_${host}_${port}.txt)
      if [ "$?" -ne 0 ]; then
        exit 1
      fi
    } &
    array_of_pids[${index}]=$!
    index=$((index + 1))
  done < "${remote_hosts_file}"
  local i=1
  local sp='⣾⣽⣻⢿⡿⣟⣯⣷'
  trap 'kill ${array_of_pids[@]} 2 > /dev/null 2>&1' EXIT
  for pid in "${array_of_pids[@]}"
  do
    while kill -0 ${pid} 2> /dev/null; do
      echo -ne "\r${sp:i++%${#sp}:1} ${cmd_explanation}"
      sleep 0.1
    done
  done
  echo -ne "\r"
  local fail=false
  index=1 # For sed to start at line 1
  for pid in "${array_of_pids[@]}"
  do
    wait ${pid}
    if [ "$?" -ne 0 ]; then
      IFS=':' read -r host port <<< $(sed -n "${index}p" "${remote_hosts_file}")
      echo -e "\033[0;31mFAIL\033[0m ${cmd_explanation} on ${host}:${port}"
      cat /tmp/log_${host}_${port}.txt
      fail=true
    fi
    index=$((index + 1))
  done
  rm /tmp/log_*.txt
  if ${fail}; then
    echo -ne "\r\033[0;31mFAIL\033[0m ${cmd_explanation}\n"
    trap - EXIT
    return 1
  else
    echo -ne "\r\033[0;32mDONE\033[0m ${cmd_explanation}\n"
    trap - EXIT
    return 0
  fi
}
