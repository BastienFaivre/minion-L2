#!/bin/bash
#===============================================================================
# Author: Bastien Faivre
# Project: EPFL, DCL, Performance and Security Evaluation of Layer 2 Blockchain
#          Systems
# Date: June 2023
# Description: Define a set of utility functions
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
# Check that a required argument is not empty
# Globals:
#   None
# Arguments:
#   $1: argument name
#   $2: argument value
# Outputs:
#   None
# Returns:
#   None
#######################################
utils::check_required_arg() {
  if ! utils::check_args_eq 2 $#; then
    return 1
  fi
  local arg_name="${1}"
  local arg_value="${2}"
  if [ -z "${arg_value}" ]; then
    utils::err "Missing required argument: ${arg_name}."
    return 1
  fi
}

#######################################
# Check that the number of arguments is equal to the expected number
# Globals:
#   None
# Arguments:
#   $1: expected number of arguments
#   $2: given number of arguments
# Outputs:
#   Writes error to stderr if the number of arguments is wrong
# Returns:
#   1 if the number of arguments is wrong, 0 otherwise
#######################################
utils::check_args_eq() {
  if [[ "$#" -ne 2 ]]; then
    utils::err "function ${FUNCNAME[0]}(): Wrong number of arguments: expected"\
" 2, got $#."
    return 1
  fi
  local expected=${1}
  local given=${2}
  if [ "${expected}" -ne "${given}" ]; then
    if [[ "${FUNCNAME[1]}" == "bash" ]]; then
      utils::err "Wrong number of arguments: expected ${expected}, got "\
"${given}."
    else
      utils::err "function ${FUNCNAME[1]}(): Wrong number of arguments: "\
"expected ${expected}, got ${given}."
    fi
    return 1
  fi
}

#######################################
# Check that the number of arguments is less than the expected number
# Globals:
#   None
# Arguments:
#   $1: expected number of arguments
#   $2: given number of arguments
# Outputs:
#   Writes error to stderr if the number of arguments is wrong
# Returns:
#   1 if the number of arguments is wrong, 0 otherwise
#######################################
utils::check_args_lt() {
  if [[ "$#" -ne 2 ]]; then
    utils::err "function ${FUNCNAME[0]}(): Wrong number of arguments: expected"\
" 2, got $#."
    return 1
  fi
  local expected=${1}
  local given=${2}
  if [[ "${given}" -ge "${expected}" ]]; then
    if [[ "${FUNCNAME[1]}" == "bash" ]]; then
      utils::err "Wrong number of arguments: expected less than ${expected}, "\
"got ${given}."
    else
      utils::err "function ${FUNCNAME[1]}(): Wrong number of arguments: "\
"expected less than ${expected}, got ${given}."
    fi
    return 1
  fi
}

#######################################
# Check that the number of arguments is less than or equal to the expected
# number
# Globals:
#   None
# Arguments:
#   $1: expected number of arguments
#   $2: given number of arguments
# Outputs:
#   Writes error to stderr if the number of arguments is wrong
# Returns:
#   1 if the number of arguments is wrong, 0 otherwise
#######################################
utils::check_args_le() {
  if [[ "$#" -ne 2 ]]; then
    utils::err "function ${FUNCNAME[0]}(): Wrong number of arguments: expected"\
" 2, got $#."
    return 1
  fi
  local expected=${1}
  local given=${2}
  if [[ "${given}" -gt "${expected}" ]]; then
    if [[ "${FUNCNAME[1]}" == "bash" ]]; then
      utils::err "Wrong number of arguments: expected at most ${expected}, got"\
" ${given}."
    else
      utils::err "function ${FUNCNAME[1]}(): Wrong number of arguments: "\
"expected at most ${expected}, got ${given}."
    fi
    return 1
  fi
}

#######################################
# Check that the number of arguments is greater than the expected number
# Globals:
#   None
# Arguments:
#   $1: expected number of arguments
#   $2: given number of arguments
# Outputs:
#   Writes error to stderr if the number of arguments is wrong
# Returns:
#   1 if the number of arguments is wrong, 0 otherwise
#######################################
utils::check_args_gt() {
  if [[ "$#" -ne 2 ]]; then
    utils::err "function ${FUNCNAME[0]}(): Wrong number of arguments: expected"\
" 2, got $#."
    return 1
  fi
  local expected=${1}
  local given=${2}
  if [[ "${given}" -le "${expected}" ]]; then
    if [[ "${FUNCNAME[1]}" == "bash" ]]; then
      utils::err "Wrong number of arguments: expected more than ${expected}, "\
"got ${given}."
    else
      utils::err "function ${FUNCNAME[1]}(): Wrong number of arguments: "\
"expected more than ${expected}, got ${given}."
    fi
    return 1
  fi
}

#######################################
# Check that the number of arguments is greater than or equal to the expected
# number
# Globals:
#   None
# Arguments:
#   $1: expected number of arguments
#   $2: given number of arguments
# Outputs:
#   Writes error to stderr if the number of arguments is wrong
# Returns:
#   1 if the number of arguments is wrong, 0 otherwise
#######################################
utils::check_args_ge() {
  if [[ "$#" -ne 2 ]]; then
    utils::err "function ${FUNCNAME[0]}(): Wrong number of arguments: expected"\
" 2, got $#."
    return 1
  fi
  local expected=${1}
  local given=${2}
  if [[ "${given}" -lt "${expected}" ]]; then
    if [[ "${FUNCNAME[1]}" == "bash" ]]; then
      utils::err "Wrong number of arguments: expected at least ${expected}, "\
"got ${given}."
    else
      utils::err "function ${FUNCNAME[1]}(): Wrong number of arguments: "\
"expected at least ${expected}, got ${given}."
    fi
    return 1
  fi
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
  if ! utils::check_args_eq 0 $#; then
    exit 1
  fi
  sudo -v > /dev/null 2>&1
  if [ "$?" -ne 0 ]; then
    utils::err "function ${FUNCNAME[0]}(): Could not obtain sudo."
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
  if ! utils::check_args_eq 2 $#; then
    exit 1
  fi
  local cmd="${1}"
  local cmd_explanation="${2}"
  ${cmd} > /tmp/log.txt 2>&1 &
  local pid=$!
  local i=1
  local sp='⣾⣽⣻⢿⡿⣟⣯⣷'
  trap 'kill ${pid} 2 > /dev/null 2>&1' EXIT
  while kill -0 ${pid} 2> /dev/null; do
    local c=${sp:i++%${#sp}:1}
    local c1=${sp:$((i + 1))%${#sp}:1}
    local c2=${sp:$((i + 2))%${#sp}:1}
    local c3=${sp:$((i + 3))%${#sp}:1}
    echo -ne "\r${c}${c1}${c2}${c3} ${cmd_explanation}"
    sleep 0.1
  done
  wait ${pid}
  if [ "$?" -ne 0 ]; then
    echo -ne "\r\033[0;31mFAIL\033[0m ${cmd_explanation}\n"
    if [ -f /tmp/log.txt ]; then
      cat /tmp/log.txt
    fi
    rm -rf /tmp/log.txt
    trap - EXIT
    return 1
  else
    echo -ne "\r\033[0;32mDONE\033[0m ${cmd_explanation}\n"
    rm  -rf /tmp/log.txt
    trap - EXIT
    return 0
  fi
}

#######################################
# Create the remote hosts list from a file
# Globals:
#   None
# Arguments:
#   $1: remote hosts file
# Outputs:
#   None
# Returns:
#   The remote hosts list
#######################################
utils::create_remote_hosts_list() {
  if ! utils::check_args_eq 1 $#; then
    exit 1
  fi
  local remote_hosts_file="${1}"
  if [ ! -f "${remote_hosts_file}" ]; then
    utils::err "function ${FUNCNAME[0]}(): File ${remote_hosts_file} does not exist."
    exit 1
  fi
  local remote_hosts_list=()
  while IFS=':' read -r host port; do
    remote_hosts_list+=("${host}:${port}")
  done < "${remote_hosts_file}"
  echo "${remote_hosts_list[@]}"
}

#######################################
# Extract the ip address from a remote host
# Globals:
#   None
# Arguments:
#   $1: remote host
# Outputs:
#   None
# Returns:
#   The ip address
#######################################
utils::extract_ip_address() {
  if ! utils::check_args_eq 1 $#; then
    exit 1
  fi
  local remote_host="${1}" # format: host:port, where host is <user>@<ip>
  local ip_address=$(echo "${remote_host}" | cut -d '@' -f 2 | cut -d ':' -f 1)
  echo "${ip_address}"
}

#######################################
# Execute a command on all remote hosts in parallel while displaying a loader
# Globals:
#   None
# Arguments:
#   $1: command to execute
#   $2: command explanation
#   $3: remote hosts list
# Outputs:
#   Writes loader and command explanation to stdout
# Returns:
#   1 if the command failed, 0 otherwise
#######################################
utils::exec_cmd_on_remote_hosts() {
  if ! utils::check_args_ge 3 $#; then
    exit 1
  fi
  local cmd="${1}"
  local cmd_explanation="${2}"
  local remote_hosts_list=("${@:3}")
  local array_of_pids=()
  local index=0
  for remote_host in "${remote_hosts_list[@]}"
  do
    IFS=':' read -r host port <<< "${remote_host}"
    {
      local res
      res=$(ssh -p ${port} ${host} "${cmd}" > /tmp/log_${host}_${port}.txt 2>&1)
      if [ "$?" -ne 0 ]; then
        exit 1
      fi
    } &
    array_of_pids[${index}]=$!
    index=$((index + 1))
  done
  local i=1
  local sp='⣾⣽⣻⢿⡿⣟⣯⣷'
  trap 'kill ${array_of_pids[@]} 2 > /dev/null 2>&1' EXIT
  for pid in "${array_of_pids[@]}"
  do
    while kill -0 ${pid} 2> /dev/null; do
      local c=${sp:i++%${#sp}:1}
      echo -ne "\r${c}${c}${c}${c} ${cmd_explanation}"
      sleep 0.1
    done
  done
  echo -ne "\r"
  local fail=false
  index=0
  for pid in "${array_of_pids[@]}"
  do
    wait ${pid}
    if [ "$?" -ne 0 ]; then
      IFS=':' read -r host port <<< "${remote_hosts_list[${index}]}"
      echo -e "\033[0;31mFAIL\033[0m ${cmd_explanation} on ${host}:${port}"
      if [ -f "/tmp/log_${host}_${port}.txt" ]; then
        cat /tmp/log_${host}_${port}.txt
      fi
      fail=true
    fi
    index=$((index + 1))
  done
  rm -rf /tmp/log_*.txt
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

utils::skip_cmd() {
  if ! utils::check_args_eq 1 $#; then
    exit 1
  fi
  local cmd_explanation="${1}"
  echo -e "\033[0;33mSKIP\033[0m ${cmd_explanation}"
}
