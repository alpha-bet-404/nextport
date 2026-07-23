#!/usr/bin/env bash

# Copyright (c) 2026 Steven Osama (zeroman). All rights reserved.
# Lead Developer: Steven Osama | GitHub: @zeroman-root

RED='\e[1;31m'
GREEN='\e[1;32m'
YELLOW='\e[1;33m'
CYAN='\e[1;36m'
BLUE='\e[1;34m'
MAGENTA='\e[1;35m'
WHITE='\e[1;37m'
GRAY='\e[0;37m'
DARK_GRAY='\e[2;37m'
ORANGE='\e[38;5;214m'
PINK='\e[38;5;213m'
LIME='\e[38;5;118m'
TEAL='\e[38;5;51m'
PURPLE='\e[38;5;135m'
GOLD='\e[38;5;220m'

BOLD='\e[1m'
DIM='\e[2m'
ITALIC='\e[3m'
UNDERLINE='\e[4m'
BLINK='\e[5m'
RESET='\e[0m'

LOCK="${GREEN}[ENC]${RESET}"
OPEN="${RED}[CLR]${RESET}"
PARTIAL="${YELLOW}[~ENC]${RESET}"
TCP="${CYAN}[TCP]${RESET}"
UDP="${YELLOW}[UDP]${RESET}"
BOTH="${MAGENTA}[T/U]${RESET}"
ARROW="${CYAN}➜${RESET}"
BULLET="${CYAN}•${RESET}"
WARN="${YELLOW}⚠${RESET}"
OK="${GREEN}✓${RESET}"
FAIL="${RED}✗${RESET}"
INFO="${CYAN}ℹ${RESET}"
STAR="${YELLOW}★${RESET}"
SKULL="${RED}☠${RESET}"
SHIELD="${GREEN}⛉${RESET}"
FIRE="${ORANGE}🔥${RESET}"

declare -A CATEGORIES=(
  ["WEB"]="${CYAN}WEB${RESET}"
  ["EMAIL"]="${YELLOW}EMAIL${RESET}"
  ["FILE"]="${GREEN}FILE TRANSFER${RESET}"
  ["REMOTE"]="${MAGENTA}REMOTE ACCESS${RESET}"
  ["NETWORK"]="${BLUE}NETWORK SERVICES${RESET}"
  ["WINDOWS"]="${CYAN}WINDOWS / SMB / AD${RESET}"
  ["DATABASE"]="${RED}DATABASE${RESET}"
  ["SECURITY"]="${RED}SECURITY / PENTEST${RESET}"
  ["VPN"]="${GREEN}VPN${RESET}"
  ["DEV"]="${YELLOW}DEVELOPMENT${RESET}"
  ["CONTAINER"]="${BLUE}CONTAINER / CLOUD${RESET}"
  ["LOGGING"]="${GRAY}LOGGING / MONITORING${RESET}"
  ["CHAT"]="${MAGENTA}CHAT / MESSAGING${RESET}"
  ["DIRECTORY"]="${CYAN}DIRECTORY SERVICES${RESET}"
  ["HOSTING"]="${GREEN}WEB HOSTING${RESET}"
  ["VIRTUAL"]="${BLUE}VIRTUALIZATION${RESET}"
  ["PRINT"]="${GRAY}PRINTING${RESET}"
  ["NEWS"]="${GRAY}NEWS / USENET${RESET}"
  ["DISTRIBUTED"]="${BLUE}DISTRIBUTED SYSTEMS${RESET}"
  ["PROXY"]="${YELLOW}PROXY / TUNNEL${RESET}"
  ["IOT"]="${ORANGE}IoT / INDUSTRIAL / SCADA${RESET}"
  ["VOIP"]="${MAGENTA}VoIP / TELEPHONY${RESET}"
  ["GAMING"]="${GREEN}GAMING${RESET}"
  ["STREAMING"]="${CYAN}STREAMING / MEDIA${RESET}"
  ["CRYPTO"]="${GOLD}CRYPTO / BLOCKCHAIN${RESET}"
  ["BACKUP"]="${BLUE}BACKUP / STORAGE${RESET}"
  ["MGMT"]="${WHITE}MANAGEMENT${RESET}"
)

risk_color() {
  case "${1^^}" in
    CRITICAL) echo "${RED}${BOLD}CRITICAL${RESET}" ;;
    HIGH)     echo "${RED}HIGH${RESET}" ;;
    MEDIUM)   echo "${YELLOW}MEDIUM${RESET}" ;;
    LOW)      echo "${GREEN}LOW${RESET}" ;;
    INFO)     echo "${CYAN}INFO${RESET}" ;;
    *)        echo "${GRAY}UNKNOWN${RESET}" ;;
  esac
}

proto_badge() {
  case "${1^^}" in
    TCP)          echo "$TCP" ;;
    UDP)          echo "$UDP" ;;
    TCP/UDP|BOTH) echo "$BOTH" ;;
    *)            echo "${GRAY}[$1]${RESET}" ;;
  esac
}

enc_badge() {
  case "${1^^}" in
    YES)     echo "$LOCK" ;;
    PARTIAL) echo "$PARTIAL" ;;
    NO)      echo "$OPEN" ;;
    *)       echo "${GRAY}[$1]${RESET}" ;;
  esac
}

risk_icon() {
  case "${1^^}" in
    CRITICAL) echo "${RED}${BOLD}[!!!]${RESET}" ;;
    HIGH)     echo "${RED}[!!]${RESET}" ;;
    MEDIUM)   echo "${YELLOW}[!]${RESET}" ;;
    LOW)      echo "${GREEN}[i]${RESET}" ;;
    *)        echo "${GRAY}[?]${RESET}" ;;
  esac
}
