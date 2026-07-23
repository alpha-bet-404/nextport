#!/usr/bin/env bash

# Copyright (c) 2026 Steven Osama (zeroman). All rights reserved.
# Lead Developer: Steven Osama | GitHub: @zeroman-root

summarize_paste_mode() {
  clear
  echo -e "\n  ${BOLD}${CYAN}NexPort — Paste-and-Summarize Mode${RESET}"
  echo -e "  ${GRAY}Paste your nmap output below.${RESET}"
  echo -e "  ${GRAY}Press ${WHITE}Ctrl+D${GRAY} when done, or type ${WHITE}END${GRAY} on a blank line.${RESET}\n"
  divider
  echo ""

  local lines=()
  while IFS= read -r line; do
    [[ "$line" == "END" ]] && break
    lines+=("$line")
  done

  local nmap_output
  nmap_output=$(printf '%s\n' "${lines[@]}")

  if [[ -z "$nmap_output" ]]; then
    echo -e "  ${RED}No input received.${RESET}\n"
    return
  fi

  local target
  target=$(echo "$nmap_output" | grep -oP '(?<=Nmap scan report for )[^\s]+' | head -1)
  [[ -z "$target" ]] && target="Unknown Target"

  echo ""
  echo -e "  ${BOLD}${CYAN}Analyzing output for: ${WHITE}${target}${RESET}\n"

  # Standard DB summary first, then AI Cognitive Analytics last.
  # AI must run AFTER _summarize_nmap_output because that function calls
  # _print_overview → clear, which would wipe any AI output printed before it.
  _summarize_nmap_output "$nmap_output" "$target"
  run_ai_intel_analysis "$nmap_output" "$target"
}

_extract_open_ports() {
  local nmap_output="$1"
  local open_ports=()
  local port_lines=()

  while IFS= read -r line; do
    if [[ "$line" =~ ^([0-9]+)/([a-z]+)[[:space:]]+open[[:space:]]*(.*) ]]; then
      local port="${BASH_REMATCH[1]}"
      local proto="${BASH_REMATCH[2]^^}"
      local service="${BASH_REMATCH[3]}"
      open_ports+=("$port")
      port_lines+=("${port}|${proto}|${service}")
    fi
  done <<< "$nmap_output"

  printf '%s\n' "${open_ports[@]}" > /tmp/nexport_open_ports.$$
  printf '%s\n' "${port_lines[@]}" > /tmp/nexport_port_lines.$$
}

_match_database() {
  local port_lines_file="$1"
  declare -gA matched_entries
  declare -gA scan_info
  unknown_ports=()

  while IFS='|' read -r port proto service; do
    scan_info[$port]="$service"
    if [[ "${PORT_DATA[$port]+_}" ]]; then
      matched_entries[$port]="${PORT_DATA[$port]}"
    else
      unknown_ports+=("$port")
    fi
  done < "$port_lines_file"
}

_classify_risk() {
  high_risk_ports=()
  medium_risk_ports=()
  low_risk_ports=()
  critical_risk_ports=()
  declare -gA cat_groups

  for port in "${!matched_entries[@]}"; do
    IFS='|' read -r p name proto enc cat desc detail risk cves exploits <<< "${matched_entries[$port]}"
    case "${risk^^}" in
      CRITICAL) critical_risk_ports+=("$port") ;;
      HIGH)     high_risk_ports+=("$port") ;;
      MEDIUM)   medium_risk_ports+=("$port") ;;
      *)        low_risk_ports+=("$port") ;;
    esac
    cat_groups[$cat]+="$port "
  done
}

_collect_cves() {
  all_cves=()
  for port in "${!matched_entries[@]}"; do
    IFS='|' read -r p name proto enc cat desc detail risk cves exploits <<< "${matched_entries[$port]}"
    if [[ -n "$cves" && "$cves" != "-" ]]; then
      IFS=',' read -ra cve_list <<< "$cves"
      for cve in "${cve_list[@]}"; do
        cve=$(echo "$cve" | tr -d ' ')
        all_cves+=("${port}:${name}:${cve}")
      done
    fi
  done
}

_collect_unencrypted() {
  unencrypted_ports=()
  for port in "${!matched_entries[@]}"; do
    IFS='|' read -r p name proto enc rest <<< "${matched_entries[$port]}"
    [[ "${enc^^}" == "NO" ]] && unencrypted_ports+=("${port}:${name}")
  done
}

_print_overview() {
  local target="$1"
  local total_open="$2"
  local known="$3"
  local unknown="$4"

  clear
  echo ""
  echo -e "  ${CYAN}╔══════════════════════════════════════════════════════════════════════╗${RESET}"
  echo -e "  ${CYAN}║${RESET}  ${BOLD}${WHITE}NexPort Intelligent Threat Summary${RESET}                               ${CYAN}║${RESET}"
  echo -e "  ${CYAN}║${RESET}  ${GRAY}Target: ${WHITE}${target}${RESET}"
  echo -e "  ${CYAN}║${RESET}  ${GRAY}Date  : $(date)${RESET}"
  echo -e "  ${CYAN}╚══════════════════════════════════════════════════════════════════════╝${RESET}"
  echo ""

  echo -e "  ${BOLD}${WHITE}[ OVERVIEW ]${RESET}"
  divider
  printf "  ${CYAN}Open ports total  :${RESET}  %d\n" "$total_open"
  printf "  ${GREEN}Recognized in DB  :${RESET}  %d\n" "$known"
  [[ $unknown -gt 0 ]] && printf "  ${YELLOW}Unrecognized      :${RESET}  %d  ${DIM}(investigate — may be custom services or backdoors)${RESET}\n" "$unknown"
  echo ""
}

_print_risk_summary() {
  echo -e "  ${BOLD}${WHITE}[ RISK ASSESSMENT ]${RESET}"
  divider

  [[ ${#critical_risk_ports[@]} -gt 0 ]] && \
    echo -e "  ${RED}${BOLD}CRITICAL${RESET} ${RED}:  ${#critical_risk_ports[@]} port(s) — IMMEDIATE action required${RESET}"
  [[ ${#high_risk_ports[@]} -gt 0 ]] && \
    echo -e "  ${RED}HIGH     :  ${#high_risk_ports[@]} port(s) — urgent review needed${RESET}"
  [[ ${#medium_risk_ports[@]} -gt 0 ]] && \
    echo -e "  ${YELLOW}MEDIUM   :  ${#medium_risk_ports[@]} port(s) — harden and monitor${RESET}"
  [[ ${#low_risk_ports[@]} -gt 0 ]] && \
    echo -e "  ${GREEN}LOW      :  ${#low_risk_ports[@]} port(s) — generally acceptable${RESET}"
  echo ""
}

_print_port_details() {
  local open_ports=("$@")
  echo -e "  ${BOLD}${WHITE}[ PORT DETAILS ]${RESET}"
  divider

  for port in $(printf '%s\n' "${open_ports[@]}" | sort -n); do
    if [[ "${matched_entries[$port]+_}" ]]; then
      IFS='|' read -r p name proto enc cat desc detail risk cves exploits <<< "${matched_entries[$port]}"
      local e_badge r_text r_icon svc_info
      e_badge=$(enc_badge "$enc")
      r_text=$(risk_color "$risk")
      r_icon=$(risk_icon "$risk")
      svc_info="${scan_info[$port]}"

      printf "  %s ${WHITE}%-7s${RESET} ${CYAN}%-22s${RESET} %s  %s\n" \
        "$(echo -e "$r_icon")" "$port" "$name" "$(echo -e "$e_badge")" "$(echo -e "$r_text")"
      printf "        ${GRAY}%s${RESET}\n" "$desc"
      [[ -n "$svc_info" ]] && printf "        ${DIM}nmap banner: %s${RESET}\n" "$svc_info"
      [[ -n "$cves" && "$cves" != "-" ]] && \
        printf "        ${RED}CVEs: %s${RESET}\n" "$cves"
      echo ""
    else
      local svc_info="${scan_info[$port]}"
      printf "  ${YELLOW}[?]  %-7s${RESET} ${YELLOW}UNRECOGNIZED${RESET}  ${DIM}(investigate — not in NexPort database)${RESET}\n" "$port"
      [[ -n "$svc_info" ]] && printf "        ${DIM}nmap banner: %s${RESET}\n" "$svc_info"
      echo ""
    fi
  done
}

_print_service_groups() {
  [[ ${#cat_groups[@]} -eq 0 ]] && return

  echo -e "  ${BOLD}${WHITE}[ SERVICE GROUPS ]${RESET}"
  divider
  for cat in "${!cat_groups[@]}"; do
    local sorted_ports
    sorted_ports=$(echo "${cat_groups[$cat]}" | tr ' ' '\n' | sort -n | tr '\n' ' ')
    printf "  ${CYAN}%-20s${RESET} ${GRAY}Ports: %s${RESET}\n" \
      "$(echo -e "${CATEGORIES[$cat]:-$cat}")" "${sorted_ports}"
  done
  echo ""
}

_print_encryption_audit() {
  [[ ${#unencrypted_ports[@]} -eq 0 ]] && return

  echo -e "  ${BOLD}${WHITE}[ ENCRYPTION AUDIT ]${RESET}"
  divider
  echo -e "  ${YELLOW}${WARN} The following open services transmit data in plaintext:${RESET}\n"
  for entry in "${unencrypted_ports[@]}"; do
    IFS=':' read -r port name <<< "$entry"
    printf "  ${RED}%-7s${RESET} ${WHITE}%-22s${RESET} ${GRAY}Cleartext — encrypted alternative strongly advised${RESET}\n" "$port" "$name"
  done
  echo ""
}

_print_cve_report() {
  [[ ${#all_cves[@]} -eq 0 ]] && return

  echo -e "  ${BOLD}${WHITE}[ KNOWN CVE EXPOSURE ]${RESET}"
  divider
  echo -e "  ${RED}${WARN} Open ports with associated CVEs — verify patch status immediately:${RESET}\n"
  for entry in "${all_cves[@]}"; do
    IFS=':' read -r port name cve <<< "$entry"
    printf "  ${WHITE}%-7s${RESET} ${CYAN}%-22s${RESET} ${RED}%s${RESET}\n" "$port" "$name" "$cve"
  done
  echo ""
}

_generate_plain_english_summary() {
  local target="$1"
  shift
  local ports=("$@")

  local web_found=() db_found=() remote_found=()
  local risky_found=() email_found=() devops_found=()
  local voip_found=() iot_found=() proxy_found=()
  local crypto_found=()

  for port in "${ports[@]}"; do
    [[ ! "${matched_entries[$port]+_}" ]] && continue
    IFS='|' read -r p name proto enc cat desc detail risk cves exploits <<< "${matched_entries[$port]}"
    case "$cat" in
      WEB)                            web_found+=("${name}(${p})") ;;
      DATABASE)                       db_found+=("${name}(${p})") ;;
      REMOTE)                         remote_found+=("${name}(${p})") ;;
      EMAIL)                          email_found+=("${name}(${p})") ;;
      DEV|CONTAINER|DISTRIBUTED)      devops_found+=("${name}(${p})") ;;
      VOIP)                           voip_found+=("${name}(${p})") ;;
      IOT)                            iot_found+=("${name}(${p})") ;;
      PROXY)                          proxy_found+=("${name}(${p})") ;;
      CRYPTO)                         crypto_found+=("${name}(${p})") ;;
    esac
    [[ "${risk^^}" == "HIGH" || "${risk^^}" == "CRITICAL" ]] && risky_found+=("${name}(${p})")
  done

  echo -e "  ${BOLD}${WHITE}[ PLAIN ENGLISH SUMMARY ]${RESET}"
  divider

  echo -ne "  "
  echo -e "${WHITE}${target}${RESET} has ${BOLD}${#ports[@]} open port(s)${RESET} visible on this scan."

  [[ ${#web_found[@]} -gt 0 ]] && {
    local https_note=""
    printf '%s\n' "${ports[@]}" | grep -q "^443$" && https_note=" — HTTPS is active"
    { printf '%s\n' "${ports[@]}" | grep -q "^80$" && ! printf '%s\n' "${ports[@]}" | grep -q "^443$"; } && \
      https_note=" — ${YELLOW}HTTPS not detected; HTTP-only is insecure${RESET}"
    echo -e "  ${CYAN}Web services${RESET} running: ${web_found[*]}${https_note}."
  }

  [[ ${#email_found[@]} -gt 0 ]] && \
    echo -e "  ${CYAN}Email services${RESET} exposed: ${email_found[*]}."

  [[ ${#db_found[@]} -gt 0 ]] && \
    echo -e "  ${RED}${WARN} Database ports publicly reachable${RESET}: ${db_found[*]}. These must never be internet-facing."

  [[ ${#remote_found[@]} -gt 0 ]] && {
    echo -e "  ${MAGENTA}Remote access${RESET} available via: ${remote_found[*]}."
    printf '%s\n' "${ports[@]}" | grep -q "^23$" && \
      echo -e "  ${RED}Telnet is open — cleartext credentials. Disable immediately and replace with SSH.${RESET}"
    printf '%s\n' "${ports[@]}" | grep -q "^3389$" && \
      echo -e "  ${RED}RDP exposed — primary ransomware entry vector. Restrict to VPN or known IPs.${RESET}"
    printf '%s\n' "${ports[@]}" | grep -q "^5900$" && \
      echo -e "  ${YELLOW}VNC exposed — tunnel through SSH and set strong password.${RESET}"
  }

  [[ ${#devops_found[@]} -gt 0 ]] && {
    echo -e "  ${YELLOW}DevOps/infrastructure services${RESET} reachable: ${devops_found[*]}."
    printf '%s\n' "${ports[@]}" | grep -q "^2375$" && \
      echo -e "  ${RED}${BOLD}CRITICAL: Docker API (2375) is open and unencrypted — full host takeover possible!${RESET}"
    printf '%s\n' "${ports[@]}" | grep -q "^4444$" && \
      echo -e "  ${RED}${BOLD}CRITICAL: Port 4444 is open — default Metasploit listener. Investigate immediately!${RESET}"
  }

  [[ ${#iot_found[@]} -gt 0 ]] && \
    echo -e "  ${RED}${WARN} Industrial/IoT protocols exposed${RESET}: ${iot_found[*]}. Air-gap or isolate immediately."

  [[ ${#voip_found[@]} -gt 0 ]] && \
    echo -e "  ${MAGENTA}VoIP services${RESET} exposed: ${voip_found[*]}. Secure signaling with TLS/SIPS."

  [[ ${#proxy_found[@]} -gt 0 ]] && \
    echo -e "  ${YELLOW}Proxy/tunnel services${RESET}: ${proxy_found[*]}. Verify authorized use."

  [[ ${#crypto_found[@]} -gt 0 ]] && \
    echo -e "  ${GOLD}Blockchain/crypto services${RESET}: ${crypto_found[*]}."

  [[ ${#unknown_ports[@]} -gt 0 ]] && \
    echo -e "  ${YELLOW}${#unknown_ports[@]} unrecognized port(s)${RESET} (${unknown_ports[*]}) — investigate manually."

  echo ""
  local total_critical_high=$(( ${#critical_risk_ports[@]} + ${#high_risk_ports[@]} ))
  echo -ne "  "
  if [[ $total_critical_high -ge 5 ]]; then
    echo -e "${RED}${BOLD}VERDICT: CRITICAL ATTACK SURFACE — Multiple severe exposures. Immediate hardening required.${RESET}"
  elif [[ $total_critical_high -ge 2 ]]; then
    echo -e "${RED}${BOLD}VERDICT: HIGH RISK — Several dangerous ports open. Review and harden urgently.${RESET}"
  elif [[ $total_critical_high -ge 1 ]]; then
    echo -e "${YELLOW}${BOLD}VERDICT: MODERATE RISK — Some concerning ports detected. Investigate and harden.${RESET}"
  else
    echo -e "${GREEN}${BOLD}VERDICT: LOW RISK — No critical exposures from recognized ports.${RESET}"
  fi
  echo ""
}

_generate_recommendations() {
  local open_ports_ref=("$@")
  local recs=()

  _add_rec() { recs+=("$1"); }

  printf '%s\n' "${open_ports_ref[@]}" | grep -q "^22$" && \
    _add_rec "${GREEN}SSH (22):${RESET} Disable root login, enforce key auth, use fail2ban, consider port knocking."
  printf '%s\n' "${open_ports_ref[@]}" | grep -q "^23$" && \
    _add_rec "${RED}Telnet (23):${RESET} DISABLE IMMEDIATELY. Every credential sent is cleartext. Replace with SSH."
  printf '%s\n' "${open_ports_ref[@]}" | grep -q "^21$" && \
    _add_rec "${RED}FTP (21):${RESET} Replace with SFTP (SSH/22) or FTPS (990). FTP sends credentials in plaintext."
  printf '%s\n' "${open_ports_ref[@]}" | grep -q "^20$" && \
    _add_rec "${RED}FTP-DATA (20):${RESET} Active-mode FTP data channel. Disable FTP entirely — use SFTP instead."
  { printf '%s\n' "${open_ports_ref[@]}" | grep -q "^80$" && ! printf '%s\n' "${open_ports_ref[@]}" | grep -q "^443$"; } && \
    _add_rec "${YELLOW}HTTP only (80):${RESET} Deploy TLS certificate and redirect all HTTP traffic to HTTPS."
  printf '%s\n' "${open_ports_ref[@]}" | grep -q "^3389$" && \
    _add_rec "${RED}RDP (3389):${RESET} Never expose to internet. Place behind VPN. Enable NLA, MFA, account lockout."
  printf '%s\n' "${open_ports_ref[@]}" | grep -q "^5900$" && \
    _add_rec "${RED}VNC (5900):${RESET} Tunnel through SSH. Strong password required. Never expose directly."
  printf '%s\n' "${open_ports_ref[@]}" | grep -q "^139$" && \
    _add_rec "${RED}NetBIOS SMB (139):${RESET} Disable SMBv1. Apply MS17-010 patch. Block from internet immediately."
  printf '%s\n' "${open_ports_ref[@]}" | grep -q "^445$" && \
    _add_rec "${RED}SMB (445):${RESET} Disable SMBv1. Enable SMB signing and encryption. Block port from internet."
  for db_port in 3306 5432 1433 1521 27017 6379 9200 11211 5984 9042 28015; do
    printf '%s\n' "${open_ports_ref[@]}" | grep -q "^${db_port}$" && \
      _add_rec "${RED}Database (${db_port}):${RESET} Databases must never be internet-facing. Use firewall, VPN, or SSH tunnel."
  done
  printf '%s\n' "${open_ports_ref[@]}" | grep -q "^2375$" && \
    _add_rec "${RED}Docker API (2375):${RESET} CRITICAL — Close immediately. Use TLS Docker API on 2376 with client certificates."
  printf '%s\n' "${open_ports_ref[@]}" | grep -q "^4444$" && \
    _add_rec "${RED}Port 4444:${RESET} CRITICAL — Default Metasploit listener. Investigate for compromise immediately."
  printf '%s\n' "${open_ports_ref[@]}" | grep -q "^161$" && \
    _add_rec "${YELLOW}SNMP (161):${RESET} Upgrade to SNMPv3. Change default community strings. Restrict to monitoring hosts."
  printf '%s\n' "${open_ports_ref[@]}" | grep -q "^389$" && \
    _add_rec "${YELLOW}LDAP (389):${RESET} Use LDAPS (636). Enable LDAP signing to prevent relay and credential attacks."
  printf '%s\n' "${open_ports_ref[@]}" | grep -q "^9200$" && \
    _add_rec "${RED}Elasticsearch (9200):${RESET} Enable X-Pack security. Never expose to internet. Billions of records breached."
  printf '%s\n' "${open_ports_ref[@]}" | grep -q "^6443$" && \
    _add_rec "${YELLOW}Kubernetes API (6443):${RESET} Enforce RBAC, audit logs, network policies. Restrict API server access."
  printf '%s\n' "${open_ports_ref[@]}" | grep -q "^1080$" && \
    _add_rec "${YELLOW}SOCKS proxy (1080):${RESET} Unauthorized proxy = unauthorized pivot. Verify intent and restrict access."
  printf '%s\n' "${open_ports_ref[@]}" | grep -q "^5060$" && \
    _add_rec "${YELLOW}SIP (5060):${RESET} Enable SIP authentication. Use SIPS (5061). Restrict to carrier IPs."
  printf '%s\n' "${open_ports_ref[@]}" | grep -q "^502$" && \
    _add_rec "${RED}Modbus (502):${RESET} CRITICAL — Industrial protocol with no authentication. Isolate from all networks."
  printf '%s\n' "${open_ports_ref[@]}" | grep -q "^1883$" && \
    _add_rec "${RED}MQTT (1883):${RESET} Enable authentication and TLS. Switch to MQTT-TLS on port 8883."
  printf '%s\n' "${open_ports_ref[@]}" | grep -q "^8888$" && \
    _add_rec "${RED}Jupyter (8888):${RESET} Bind to localhost only. Jupyter has arbitrary code execution built-in."

  echo -e "  ${BOLD}${WHITE}[ HARDENING RECOMMENDATIONS ]${RESET}"
  divider

  if [[ ${#recs[@]} -eq 0 ]]; then
    echo -e "  ${GREEN}${OK} No critical recommendations for detected ports. Maintain regular patching and monitoring.${RESET}"
    return
  fi

  local i=1
  for rec in "${recs[@]}"; do
    echo -e "  ${CYAN}[${i}]${RESET} $(echo -e "$rec")"
    ((i++))
  done
}

_summarize_nmap_output() {
  local nmap_output="$1"
  local target="${2:-Unknown}"

  _extract_open_ports "$nmap_output"

  local open_ports=()
  while IFS= read -r line; do
    [[ -n "$line" ]] && open_ports+=("$line")
  done < /tmp/nexport_open_ports.$$

  rm -f /tmp/nexport_open_ports.$$

  if [[ ${#open_ports[@]} -eq 0 ]]; then
    echo -e "  ${YELLOW}No open ports detected in the provided output.${RESET}\n"
    rm -f /tmp/nexport_port_lines.$$
    return
  fi

  unset matched_entries scan_info
  declare -gA matched_entries
  declare -gA scan_info
  unknown_ports=()

  _match_database /tmp/nexport_port_lines.$$
  rm -f /tmp/nexport_port_lines.$$

  unset cat_groups
  critical_risk_ports=() high_risk_ports=() medium_risk_ports=() low_risk_ports=()
  _classify_risk

  all_cves=()
  _collect_cves

  unencrypted_ports=()
  _collect_unencrypted

  _print_overview "$target" "${#open_ports[@]}" "${#matched_entries[@]}" "${#unknown_ports[@]}"
  _print_risk_summary
  _print_port_details "${open_ports[@]}"
  _print_service_groups
  _print_encryption_audit
  _print_cve_report
  _generate_plain_english_summary "$target" "${open_ports[@]}"
  _generate_recommendations "${open_ports[@]}"
  echo ""
}
