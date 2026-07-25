#!/usr/bin/env bash

# Copyright (c) 2026 Steven Osama (zeroman). All rights reserved.
# Lead Developer: Steven Osama | GitHub: @zeroman-root

declare -A QUIZ_STATS_HISTORY

quiz_mode() {
  clear
  echo -e "\n  ${BOLD}${YELLOW}NEXPORT QUIZ MODE${RESET}"
  echo -e "  ${GRAY}Test your port knowledge. Type ${WHITE}quit${GRAY} anytime to exit.\n${RESET}"

  echo -e "  ${CYAN}Question Type:${RESET}"
  echo -e "  ${GREEN}1${RESET}  ${WHITE}Name the Port${RESET}     — Given a service name, enter its port number"
  echo -e "  ${GREEN}2${RESET}  ${WHITE}Name the Service${RESET}   — Given a port number, name the service"
  echo -e "  ${GREEN}3${RESET}  ${WHITE}Risk Assessment${RESET}    — Given a port, rate its risk level"
  echo -e "  ${GREEN}4${RESET}  ${WHITE}Mixed Mode${RESET}         — Random question types (recommended)"
  echo -ne "\n  ${YELLOW}Type [1-4]: ${RESET}"
  read -r qtype
  [[ -z "$qtype" ]] && qtype=4

  echo -e "\n  ${CYAN}Difficulty:${RESET}"
  echo -e "  ${GREEN}1${RESET}  ${WHITE}Easy${RESET}    — Top 20 most common ports"
  echo -e "  ${GREEN}2${RESET}  ${WHITE}Medium${RESET}  — Well-known ports and services"
  echo -e "  ${GREEN}3${RESET}  ${WHITE}Hard${RESET}    — Full database, any port"
  echo -ne "\n  ${YELLOW}Difficulty [1-3]: ${RESET}"
  read -r difficulty

  local pool=()
  case "$difficulty" in
    1) pool=(22 80 443 21 25 53 3306 3389 23 445 110 143 8080 27017 6379 5432 22 443 80 3389) ;;
    2) pool=(22 80 443 21 25 53 3306 3389 23 445 110 143 8080 27017 6379 5432 6443 2375 161 389 636 1433 3268 9200 5900 1080 1194 51820 5060 554 1883 9090 3000 8443 4444 5601 9418 2181 4040) ;;
    3) pool=($(echo "${!PORT_DATA[@]}" | tr ' ' '\n' | shuf | head -30)) ;;
    *)  pool=(22 80 443 21 25 53 3306 3389 23 445 110 143 8080 27017 6379 5432) ;;
  esac

  local score=0 total=0 wrong_ports=()

  for port in "${pool[@]}"; do
    local entry="${PORT_DATA[$port]}"
    [[ -z "$entry" ]] && continue

    IFS='|' read -r p name proto enc cat desc detail risk cves exploits <<< "$entry"
    ((total++))

    local effective_qtype="$qtype"
    [[ "$qtype" -eq 4 ]] && effective_qtype=$(( RANDOM % 3 + 1 ))

    echo ""
    echo -e "  ${CYAN}──────────────────────────────────────────────────${RESET}"
    echo -e "  ${BOLD}Question ${total}${RESET}"

    local correct=false answer=""

    case "$effective_qtype" in
      1)
        echo -e "  ${WHITE}What port number does ${CYAN}${name}${WHITE} use?${RESET}"
        echo -e "  ${GRAY}Category: ${CATEGORIES[$cat]:-$cat}  │  ${desc}${RESET}"
        echo -ne "  ${YELLOW}Port number: ${RESET}"
        read -r answer
        [[ "${answer,,}" == "quit" ]] && break
        if [[ "$answer" == "$p" ]]; then
          correct=true
        fi
        ;;
      2)
        echo -e "  ${WHITE}What service runs on port ${CYAN}${p}/${proto}${WHITE}?${RESET}"
        echo -e "  ${GRAY}Category: ${CATEGORIES[$cat]:-$cat}  │  Hint: ${desc}${RESET}"
        echo -ne "  ${YELLOW}Service name: ${RESET}"
        read -r answer
        [[ "${answer,,}" == "quit" ]] && break
        if [[ "${answer,,}" == "${name,,}" || "${answer,,}" == *"${name,,}"* || "${name,,}" == *"${answer,,}"* ]]; then
          correct=true
        fi
        ;;
      3)
        echo -e "  ${WHITE}What is the risk level of port ${CYAN}${p} (${name})${WHITE}?${RESET}"
        echo -e "  ${GRAY}${desc}${RESET}"
        echo -e "  ${DIM}Options: low / medium / high / critical${RESET}"
        echo -ne "  ${YELLOW}Risk level: ${RESET}"
        read -r answer
        [[ "${answer,,}" == "quit" ]] && break
        if [[ "${answer,,}" == "${risk,,}" ]]; then
          correct=true
        fi
        ;;
    esac

    if $correct; then
      echo -e "  ${GREEN}${OK} Correct!${RESET}  Port ${WHITE}${p}${RESET} — ${CYAN}${name}${RESET}"
      ((score++))
    else
      echo -e "  ${RED}${FAIL} Wrong!${RESET}"
      case "$effective_qtype" in
        1) echo -e "  ${GRAY}The answer was port ${WHITE}${p}${RESET}" ;;
        2) echo -e "  ${GRAY}The answer was ${WHITE}${name}${RESET}" ;;
        3) echo -e "  ${GRAY}The answer was ${WHITE}${risk}${RESET}  $(risk_color "$risk")" ;;
      esac
      echo -e "  ${DIM}${detail:0:120}${RESET}"
      wrong_ports+=("$p:$name")
    fi
  done

  _quiz_results "$score" "$total" "${wrong_ports[@]}"
}

_quiz_results() {
  local score=$1 total=$2
  shift 2
  local wrong_ports=("$@")

  echo ""
  echo -e "  ${CYAN}══════════════════════════════════════════════════${RESET}"
  echo -e "  ${BOLD}${WHITE}QUIZ COMPLETE${RESET}"
  echo ""

  local pct=0
  [[ $total -gt 0 ]] && pct=$((score * 100 / total))

  echo -e "  Score: ${BOLD}${YELLOW}${score}/${total}${RESET}  (${pct}%)"
  echo -ne "  "
  [[ $total -gt 0 ]] && progress_bar $score $total 36
  echo -e "\n"

  if [[ $pct -ge 95 ]]; then
    echo -e "  ${GOLD}${STAR} PERFECT — You are a network security master.${RESET}"
  elif [[ $pct -ge 80 ]]; then
    echo -e "  ${GREEN}${OK} Excellent! Strong networking fundamentals.${RESET}"
  elif [[ $pct -ge 60 ]]; then
    echo -e "  ${YELLOW}Decent — review your weak spots and try again.${RESET}"
  elif [[ $pct -ge 40 ]]; then
    echo -e "  ${ORANGE}Keep studying — use ${GREEN}-a${ORANGE} to browse all ports.${RESET}"
  else
    echo -e "  ${RED}${FAIL} Needs work — start with ${GREEN}-t${RED} to review top targeted ports.${RESET}"
  fi

  if [[ ${#wrong_ports[@]} -gt 0 ]]; then
    echo ""
    echo -e "  ${YELLOW}Ports to review:${RESET}"
    for wp in "${wrong_ports[@]}"; do
      IFS=':' read -r p n <<< "$wp"
      printf "  ${RED}%-7s${RESET} ${GRAY}%s${RESET}\n" "$p" "$n"
    done
  fi
  echo ""
}
