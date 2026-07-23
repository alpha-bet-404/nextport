#!/usr/bin/env bash

# Copyright (c) 2026 Steven Osama (zeroman). All rights reserved.
# Lead Developer: Steven Osama | GitHub: @zeroman-root

search_ports() {
  local keyword="${1,,}"
  local found=0

  clear
  echo -e "\n  ${BOLD}${CYAN}Search results for: \"${1}\"${RESET}\n"
  divider

  for key in $(echo "${!PORT_DATA[@]}" | tr ' ' '\n' | sort -n); do
    local entry="${PORT_DATA[$key]}"
    if echo "${entry,,}" | grep -q "$keyword"; then
      print_port_row "$entry"
      ((found++))
    fi
  done

  echo ""
  if [[ $found -eq 0 ]]; then
    echo -e "  ${RED}No results found for \"${1}\"${RESET}"
    echo -e "  ${GRAY}Try a different keyword or use ${GREEN}-a${GRAY} to browse all ports.${RESET}"
  else
    echo -e "  ${GREEN}Found ${found} result(s) matching \"${1}\"${RESET}"
  fi
  echo ""
}

filter_by_protocol() {
  local proto="${1^^}"
  local found=0

  case "$proto" in
    BOTH|T/U|TCP/UDP) proto="TCP/UDP" ;;
    TCP|UDP) : ;;
    *) echo -e "\n  ${RED}Unknown protocol: ${1}${RESET}\n  ${YELLOW}Usage: -p <tcp|udp|both>${RESET}\n"; return ;;
  esac

  clear
  echo -e "\n  ${BOLD}${CYAN}Ports using protocol: ${proto}${RESET}\n"
  divider

  for key in $(echo "${!PORT_DATA[@]}" | tr ' ' '\n' | sort -n); do
    local entry="${PORT_DATA[$key]}"
    IFS='|' read -r port name p enc cat desc detail risk cves exploits <<< "$entry"
    if [[ "${p^^}" == "$proto" || ( "$proto" == "TCP/UDP" && "${p^^}" =~ "/" ) ]]; then
      print_port_row "$entry"
      ((found++))
    fi
  done

  echo -e "\n  ${GREEN}Found ${found} port(s) using ${proto}${RESET}\n"
}

filter_by_encryption() {
  local enc="${1^^}"
  local found=0
  local label

  case "$enc" in
    YES|ENCRYPTED|ENC)       enc="YES";     label="${GREEN}Encrypted${RESET}" ;;
    NO|CLEAR|UNENCRYPTED)    enc="NO";      label="${RED}Unencrypted (Cleartext)${RESET}" ;;
    PARTIAL|PARTIAL-ENC)     enc="PARTIAL"; label="${YELLOW}Partially Encrypted${RESET}" ;;
    *) echo -e "\n  ${RED}Unknown value: ${1}${RESET}\n  ${YELLOW}Usage: -e <yes|no|partial>${RESET}\n"; return ;;
  esac

  clear
  echo -e "\n  ${BOLD}${CYAN}Ports with encryption status: $(echo -e "$label")${RESET}\n"
  divider

  for key in $(echo "${!PORT_DATA[@]}" | tr ' ' '\n' | sort -n); do
    local entry="${PORT_DATA[$key]}"
    IFS='|' read -r port name proto e cat desc detail risk cves exploits <<< "$entry"
    if [[ "${e^^}" == "$enc" ]]; then
      print_port_row "$entry"
      ((found++))
    fi
  done

  echo -e "\n  ${GREEN}Found ${found} port(s)${RESET}\n"
}

filter_by_risk() {
  local risk="${1^^}"
  local found=0

  case "$risk" in
    CRITICAL|HIGH|MEDIUM|LOW|INFO) : ;;
    *) echo -e "\n  ${RED}Unknown risk: ${1}${RESET}\n  ${YELLOW}Usage: -r <critical|high|medium|low>${RESET}\n"; return ;;
  esac

  clear
  echo -e "\n  ${BOLD}${CYAN}Ports with risk level: $(risk_color "$risk")${RESET}\n"
  divider

  for key in $(echo "${!PORT_DATA[@]}" | tr ' ' '\n' | sort -n); do
    local entry="${PORT_DATA[$key]}"
    IFS='|' read -r port name proto enc cat desc detail r cves exploits <<< "$entry"
    if [[ "${r^^}" == "$risk" ]]; then
      print_port_row "$entry"
      ((found++))
    fi
  done

  echo -e "\n  ${GREEN}Found ${found} port(s) at ${risk} risk level${RESET}\n"
}

search_cves() {
  local cve_id="${1^^}"
  local found=0

  clear
  echo -e "\n  ${BOLD}${RED}Ports associated with: ${cve_id}${RESET}\n"
  divider

  for key in $(echo "${!PORT_DATA[@]}" | tr ' ' '\n' | sort -n); do
    local entry="${PORT_DATA[$key]}"
    IFS='|' read -r port name proto enc cat desc detail risk cves exploits <<< "$entry"
    if echo "${cves^^}" | grep -q "$cve_id"; then
      print_port_row "$entry"
      echo -e "  ${DIM}CVEs: ${RED}${cves}${RESET}\n"
      ((found++))
    fi
  done

  echo ""
  if [[ $found -eq 0 ]]; then
    echo -e "  ${YELLOW}No ports in database reference ${cve_id}${RESET}"
  else
    echo -e "  ${RED}Found ${found} port(s) associated with ${cve_id}${RESET}"
  fi
  echo ""
}
