#!/usr/bin/env bash

# Copyright (c) 2026 Steven Osama (zeroman). All rights reserved.
# Lead Developer: Steven Osama | GitHub: @zeroman-root

list_categories() {
  clear
  echo -e "\n  ${BOLD}${WHITE}Port Categories  ($(port_count) total ports)${RESET}\n"
  divider

  declare -A cat_count
  for key in "${!PORT_DATA[@]}"; do
    IFS='|' read -r port name proto enc cat rest <<< "${PORT_DATA[$key]}"
    cat_count[$cat]=$(( ${cat_count[$cat]:-0} + 1 ))
  done

  local cat_order=(WEB EMAIL FILE REMOTE NETWORK WINDOWS DATABASE SECURITY VPN DEV CONTAINER DISTRIBUTED LOGGING CHAT DIRECTORY HOSTING VIRTUAL PRINT NEWS PROXY IOT VOIP GAMING STREAMING CRYPTO BACKUP MGMT)
  for cat in "${cat_order[@]}"; do
    local count="${cat_count[$cat]:-0}"
    [[ $count -eq 0 ]] && continue
    printf "  ${GREEN}%-18s${RESET} %-38s ${GRAY}%d ports${RESET}\n" \
      "$cat" "$(echo -e "${CATEGORIES[$cat]:-$cat}")" "$count"
  done

  echo ""
  echo -e "  ${GRAY}Usage: ${GREEN}-c <CATEGORY>${RESET}\n"
}

show_category() {
  local cat="${1^^}"

  if [[ -z "${CATEGORIES[$cat]}" ]]; then
    echo -e "\n  ${RED}Unknown category: $cat${RESET}"
    list_categories
    return
  fi

  clear
  echo -e "\n  ${BOLD}Category: ${CATEGORIES[$cat]}${RESET}\n"
  divider

  local found=0
  for key in $(echo "${!PORT_DATA[@]}" | tr ' ' '\n' | sort -n); do
    local entry="${PORT_DATA[$key]}"
    IFS='|' read -r port name proto enc c rest <<< "$entry"
    if [[ "$c" == "$cat" ]]; then
      print_port_row "$entry"
      ((found++))
    fi
  done

  echo ""
  if [[ $found -eq 0 ]]; then
    echo -e "  ${RED}No ports found in category ${cat}.${RESET}"
  else
    echo -e "  ${GREEN}${found} port(s) in category ${cat}.${RESET}"
  fi
  echo ""
}
