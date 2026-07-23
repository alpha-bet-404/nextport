#!/usr/bin/env bash

# Copyright (c) 2026 Steven Osama (zeroman). All rights reserved.
# Lead Developer: Steven Osama | GitHub: @zeroman-root

show_top_ports() {
  clear
  echo -e "\n  ${BOLD}${RED}TOP 30 MOST TARGETED PORTS${RESET}"
  echo -e "  ${GRAY}Ranked by attack frequency, threat intelligence data, and Shodan exposure${RESET}\n"
  divider

  local top=(
    "22"
    "3389"
    "445"
    "80"
    "443"
    "23"
    "21"
    "3306"
    "6379"
    "27017"
    "9200"
    "2375"
    "5900"
    "8080"
    "1433"
    "25"
    "110"
    "139"
    "4444"
    "8888"
    "9090"
    "5432"
    "8443"
    "1080"
    "161"
    "5060"
    "554"
    "11211"
    "6443"
    "50000"
  )

  local rank=1
  for port in "${top[@]}"; do
    local entry="${PORT_DATA[$port]}"
    if [[ -z "$entry" ]]; then
      ((rank++))
      continue
    fi
    IFS='|' read -r p name proto enc cat desc detail risk cves exploits <<< "$entry"

    local e_badge r_text r_icon
    e_badge=$(enc_badge "$enc")
    r_text=$(risk_color "$risk")
    r_icon=$(risk_icon "$risk")

    printf "  ${GOLD}#%-3s${RESET}  ${WHITE}%-7s${RESET} ${CYAN}%-22s${RESET} %s  %s  %s\n" \
      "$rank" "$p" "$name" "$(echo -e "$e_badge")" "$(echo -e "$r_icon")" "$(echo -e "$r_text")"
    printf "       ${GRAY}%s${RESET}\n" "$desc"
    [[ -n "$cves" && "$cves" != "-" ]] && \
      printf "       ${DIM}CVEs: ${RED}%s${RESET}\n" "$cves"
    echo ""
    ((rank++))
  done
}
