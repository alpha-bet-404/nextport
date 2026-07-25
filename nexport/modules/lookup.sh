#!/usr/bin/env bash

# Copyright (c) 2026 Steven Osama (zeroman). All rights reserved.
# Lead Developer: Steven Osama | GitHub: @zeroman-root

lookup_port() {
  local query="${1,,}"
  local raw="$1"

  if [[ "${PORT_DATA[$raw]+_}" ]]; then
    print_port_info "${PORT_DATA[$raw]}"
    return
  fi

  for key in "${!PORT_DATA[@]}"; do
    IFS='|' read -r port name proto enc cat desc detail risk cves exploits <<< "${PORT_DATA[$key]}"
    if [[ "${name,,}" == "$query" ]]; then
      print_port_info "${PORT_DATA[$key]}"
      return
    fi
  done

  local matches=()
  for key in "${!PORT_DATA[@]}"; do
    local entry="${PORT_DATA[$key]}"
    IFS='|' read -r port name proto enc cat desc detail risk cves exploits <<< "$entry"
    if [[ "${name,,}" == *"$query"* || "${desc,,}" == *"$query"* || "${cat,,}" == *"$query"* ]]; then
      matches+=("$entry")
    fi
  done

  if [[ ${#matches[@]} -eq 1 ]]; then
    print_port_info "${matches[0]}"
    return
  elif [[ ${#matches[@]} -gt 1 ]]; then
    echo -e "\n  ${YELLOW}Multiple matches for '${raw}':${RESET}\n"
    divider
    for entry in "${matches[@]}"; do
      IFS='|' read -r port name proto enc cat desc detail risk cves exploits <<< "$entry"
      printf "  ${WHITE}%-7s${RESET} ${CYAN}%-24s${RESET} ${GRAY}%s${RESET}\n" "$port" "$name" "$desc"
    done
    echo ""
    echo -e "  ${GRAY}Use ${GREEN}-h <port number>${GRAY} for exact details.${RESET}\n"
    return
  fi

  echo -e "\n  ${RED}Port/protocol '${raw}' not found in database.${RESET}"
  echo -e "  ${YELLOW}Try: ${GREEN}-s ${raw}${YELLOW} for a broader keyword search.${RESET}\n"
}

show_all() {
  clear
  section_header "ALL KNOWN PORTS  ($(port_count) total)"

  declare -A cat_ports
  for key in "${!PORT_DATA[@]}"; do
    IFS='|' read -r port name proto enc cat rest <<< "${PORT_DATA[$key]}"
    cat_ports[$cat]+="$port "
  done

  local cat_order=(WEB EMAIL FILE REMOTE NETWORK WINDOWS DATABASE SECURITY VPN DEV CONTAINER DISTRIBUTED LOGGING CHAT DIRECTORY HOSTING VIRTUAL PRINT NEWS PROXY IOT VOIP GAMING STREAMING CRYPTO BACKUP MGMT)

  for cat in "${cat_order[@]}"; do
    [[ -z "${cat_ports[$cat]}" ]] && continue
    echo -e "  ${BOLD}${CATEGORIES[$cat]:-$cat}${RESET}"
    divider
    for port in $(echo "${cat_ports[$cat]}" | tr ' ' '\n' | sort -n); do
      local entry="${PORT_DATA[$port]}"
      [[ -z "$entry" ]] && continue
      print_port_row "$entry"
    done
    echo ""
  done
}
