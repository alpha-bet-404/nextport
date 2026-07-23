#!/usr/bin/env bash

# Copyright (c) 2026 Steven Osama (zeroman). All rights reserved.
# Lead Developer: Steven Osama | GitHub: @zeroman-root

show_banner() {
  clear
  echo -e "${CYAN}"
  cat << 'BANNER'

  ███╗   ██╗███████╗██╗  ██╗██████╗  ██████╗ ██████╗ ████████╗
  ████╗  ██║██╔════╝╚██╗██╔╝██╔══██╗██╔═══██╗██╔══██╗╚══██╔══╝
  ██╔██╗ ██║█████╗   ╚███╔╝ ██████╔╝██║   ██║██████╔╝   ██║
  ██║╚██╗██║██╔══╝   ██╔██╗ ██╔═══╝ ██║   ██║██╔══██╗   ██║
  ██║ ╚████║███████╗██╔╝ ██╗██║     ╚██████╔╝██║  ██║   ██║
  ╚═╝  ╚═══╝╚══════╝╚═╝  ╚═╝╚═╝      ╚═════╝ ╚═╝  ╚═╝   ╚═╝

BANNER
  echo -e "${RESET}"
  echo -e "  ${DIM}╔════════════════════════════════════════════════════════════════════╗${RESET}"
  echo -e "  ${DIM}║${RESET}  ${BOLD}${CYAN}v3.0${RESET}  ${GRAY}│${RESET}  ${WHITE}Professional Network Port Intelligence Tool${RESET}           ${DIM}║${RESET}"
  echo -e "  ${DIM}║${RESET}  ${GRAY}500+ ports · CVE Database · Nmap Scan Engine · Export Suite${RESET}    ${DIM}║${RESET}"
  echo -e "  ${DIM}║${RESET}  ${GRAY}Modular Architecture · Quiz Mode${RESET}                               ${DIM}║${RESET}"
  echo -e "  ${DIM}╚════════════════════════════════════════════════════════════════════╝${RESET}"
  echo ""
  echo -e "  ${YELLOW}[*]${RESET} ${GREEN}-h <port|name>${RESET} deep lookup    ${GRAY}│${RESET}  ${GREEN}-a${RESET} list all ports"
  echo -e "  ${YELLOW}[*]${RESET} ${GREEN}scan <target>${RESET} run nmap      ${GRAY}│${RESET}  ${GREEN}paste${RESET} summarize results"
  echo -e "  ${YELLOW}[*]${RESET} ${GREEN}-s <keyword>${RESET} keyword search  ${GRAY}│${RESET}  ${GREEN}--help${RESET} full command list"
  echo ""
}

divider() {
  echo -e "  ${DIM}────────────────────────────────────────────────────────────────────${RESET}"
}

thick_divider() {
  echo -e "  ${CYAN}════════════════════════════════════════════════════════════════════${RESET}"
}

section_header() {
  echo ""
  echo -e "  ${BOLD}${CYAN}══ ${1} ══${RESET}"
  echo ""
}

print_port_info() {
  local entry="$1"
  IFS='|' read -r port name proto enc cat desc detail risk cves exploits <<< "$entry"

  local e_badge p_badge cat_label r_text r_icon
  e_badge=$(enc_badge "$enc")
  p_badge=$(proto_badge "$proto")
  cat_label="${CATEGORIES[$cat]:-${GRAY}$cat${RESET}}"
  r_text=$(risk_color "$risk")
  r_icon=$(risk_icon "$risk")

  echo ""
  echo -e "  ${CYAN}╔════════════════════════════════════════════════════════════════════╗${RESET}"
  echo -e "  ${CYAN}║${RESET}  ${BOLD}${WHITE}PORT ${port}${RESET}  ${GRAY}│${RESET}  ${BOLD}${CYAN}${name}${RESET}  ${p_badge} ${e_badge}  ${r_icon}"
  echo -e "  ${CYAN}╠════════════════════════════════════════════════════════════════════╣${RESET}"
  echo -e "  ${CYAN}║${RESET}  ${YELLOW}Description :${RESET}  ${desc}"
  echo -e "  ${CYAN}║${RESET}  ${YELLOW}Protocol    :${RESET}  ${proto}"
  echo -e "  ${CYAN}║${RESET}  ${YELLOW}Encryption  :${RESET}  ${e_badge}"
  echo -e "  ${CYAN}║${RESET}  ${YELLOW}Category    :${RESET}  ${cat_label}"
  echo -e "  ${CYAN}║${RESET}  ${YELLOW}Risk Level  :${RESET}  ${r_text}"
  echo -e "  ${CYAN}╠════════════════════════════════════════════════════════════════════╣${RESET}"
  echo -e "  ${CYAN}║${RESET}  ${WHITE}Details:${RESET}"
  echo "$detail" | fold -s -w 66 | while IFS= read -r line; do
    echo -e "  ${CYAN}║${RESET}  ${GRAY}${line}${RESET}"
  done

  if [[ -n "$cves" && "$cves" != "-" ]]; then
    echo -e "  ${CYAN}╠════════════════════════════════════════════════════════════════════╣${RESET}"
    echo -e "  ${CYAN}║${RESET}  ${RED}Known CVEs  :${RESET}  ${RED}${cves}${RESET}"
  fi

  if [[ -n "$exploits" && "$exploits" != "-" ]]; then
    echo -e "  ${CYAN}║${RESET}  ${ORANGE}Exploit Refs:${RESET}  ${ORANGE}${exploits}${RESET}"
  fi

  echo -e "  ${CYAN}╚════════════════════════════════════════════════════════════════════╝${RESET}"
  echo ""
}

print_port_row() {
  local entry="$1"
  IFS='|' read -r port name proto enc cat desc detail risk cves exploits <<< "$entry"
  local e_badge p_badge r_icon
  e_badge=$(enc_badge "$enc")
  p_badge=$(proto_badge "$proto")
  r_icon=$(risk_icon "$risk")
  printf "  ${WHITE}%-7s${RESET} ${CYAN}%-22s${RESET} %-12s %-10s %s  ${GRAY}%s${RESET}\n" \
    "$port" "$name" "$(echo -e "$p_badge")" "$(echo -e "$e_badge")" "$(echo -e "$r_icon")" "$desc"
}

spinner() {
  local pid=$1
  local msg="${2:-Working}"
  local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
  local i=0
  while kill -0 "$pid" 2>/dev/null; do
    printf "\r  ${CYAN}${frames[$i]}${RESET}  ${GRAY}%s...${RESET}" "$msg"
    i=$(( (i+1) % ${#frames[@]} ))
    sleep 0.1
  done
  printf "\r%-60s\r" " "
}

progress_bar() {
  local current=$1 total=$2 width=${3:-40}
  local filled=$(( current * width / total ))
  local empty=$(( width - filled ))
  local bar=""
  for ((i=0; i<filled; i++)); do bar+="█"; done
  for ((i=0; i<empty; i++)); do bar+="░"; done
  printf "  ${CYAN}[%s]${RESET} %d/%d\r" "$bar" "$current" "$total"
}

port_count() {
  echo "${#PORT_DATA[@]}"
}
