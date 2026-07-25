#!/usr/bin/env bash

# Copyright (c) 2026 Steven Osama (zeroman). All rights reserved.
# Lead Developer: Steven Osama | GitHub: @zeroman-root

NEXPORT_CONFIG_DIR="${HOME}/.nexport"
NEXPORT_CONFIG_FILE="${NEXPORT_CONFIG_DIR}/config"

# ── Config helpers ──────────────────────────────────────────────────────────

_intel_load_config() {
  [[ -f "$NEXPORT_CONFIG_FILE" ]] && source "$NEXPORT_CONFIG_FILE"
}

intel_set_shodan_key() {
  local key="$1"
  if [[ -z "$key" ]]; then
    echo -e "\n  ${RED}${FAIL} Usage: intel set-key <your-shodan-api-key>${RESET}\n"
    return 1
  fi
  mkdir -p "$NEXPORT_CONFIG_DIR"
  local tmpfile
  tmpfile=$(mktemp "${NEXPORT_CONFIG_DIR}/config.XXXXXX")
  grep -v "^SHODAN_API_KEY=" "$NEXPORT_CONFIG_FILE" 2>/dev/null > "$tmpfile" || true
  echo "SHODAN_API_KEY=\"${key}\"" >> "$tmpfile"
  mv "$tmpfile" "$NEXPORT_CONFIG_FILE"
  chmod 600 "$NEXPORT_CONFIG_FILE"
  echo -e "\n  ${GREEN}${OK} Shodan API key saved to ${DIM}${NEXPORT_CONFIG_FILE}${RESET}\n"
}

intel_clear_shodan_key() {
  if [[ ! -f "$NEXPORT_CONFIG_FILE" ]]; then
    echo -e "\n  ${YELLOW}${WARN} No config file found — nothing to clear.${RESET}\n"
    return
  fi
  local tmpfile
  tmpfile=$(mktemp "${NEXPORT_CONFIG_DIR}/config.XXXXXX")
  grep -v "^SHODAN_API_KEY=" "$NEXPORT_CONFIG_FILE" > "$tmpfile" 2>/dev/null || true
  mv "$tmpfile" "$NEXPORT_CONFIG_FILE"
  echo -e "\n  ${GREEN}${OK} Shodan API key cleared.${RESET}\n"
}

# ── Public IP detection ─────────────────────────────────────────────────────

_is_public_ipv4() {
  local ip="$1"
  [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1
  IFS='.' read -r a b c d <<< "$ip"
  [[ $a -eq 10 ]]                                   && return 1
  [[ $a -eq 172 && $b -ge 16 && $b -le 31 ]]        && return 1
  [[ $a -eq 192 && $b -eq 168 ]]                    && return 1
  [[ $a -eq 127 ]]                                  && return 1
  [[ $a -eq 169 && $b -eq 254 ]]                    && return 1
  [[ $a -ge 224 ]]                                  && return 1
  return 0
}

_resolve_to_ip() {
  local host="$1"
  if [[ "$host" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
    echo "$host"
    return 0
  fi
  local resolved
  resolved=$(python3 -c "import socket; print(socket.gethostbyname('${host}'))" 2>/dev/null)
  if [[ -z "$resolved" ]]; then
    resolved=$(getent hosts "$host" 2>/dev/null | awk '{print $1}' | head -1)
  fi
  if [[ -z "$resolved" ]]; then
    return 1
  fi
  echo "$resolved"
}

# ── JSON helpers (jq-first, regex fallback) ─────────────────────────────────

_has_jq() {
  command -v jq &>/dev/null
}

_json_scalar() {
  local json="$1" key="$2"
  if _has_jq; then
    echo "$json" | jq -r ".${key} // empty" 2>/dev/null
  else
    echo "$json" | grep -oP "\"${key}\"\s*:\s*\K(\"[^\"]*\"|-?[0-9]+(\.[0-9]+)?)" \
      | head -1 | tr -d '"'
  fi
}

_json_array_scalars() {
  local json="$1" key="$2"
  if _has_jq; then
    echo "$json" | jq -r ".${key}[]? // empty" 2>/dev/null
  else
    echo "$json" | grep -oP "\"${key}\"\s*:\s*\[\K[^\]]+" \
      | tr ',' '\n' | tr -d '" ' | grep -v '^$'
  fi
}

# ── Shodan Integration ──────────────────────────────────────────────────────

_shodan_fetch() {
  local ip="$1" api_key="$2"
  local response
  response=$(curl -sf --max-time 12 \
    "https://api.shodan.io/shodan/host/${ip}?key=${api_key}" 2>/dev/null)
  local rc=$?
  if [[ $rc -ne 0 || -z "$response" ]]; then
    echo -e "  ${YELLOW}${WARN} Shodan: request failed (network timeout or unreachable).${RESET}" >&2
    return 1
  fi
  local err
  err=$(_json_scalar "$response" "error")
  if [[ -n "$err" ]]; then
    echo -e "  ${RED}${FAIL} Shodan: ${err}${RESET}" >&2
    return 1
  fi
  echo "$response"
}

_shodan_display() {
  local response="$1" ip="$2"

  local org country isp city hostname

  org=$(_json_scalar "$response" "org")
  country=$(_json_scalar "$response" "country_name")
  isp=$(_json_scalar "$response" "isp")
  city=$(_json_scalar "$response" "city")

  if _has_jq; then
    hostname=$(echo "$response" | jq -r '.hostnames[0] // empty' 2>/dev/null)
  else
    hostname=$(echo "$response" | grep -oP '"hostnames"\s*:\s*\[\s*"\K[^"]+' | head -1)
  fi

  local shodan_ports
  if _has_jq; then
    shodan_ports=$(echo "$response" | jq -r '.ports[]?' 2>/dev/null \
      | sort -n | tr '\n' ' ' | sed 's/ $//')
  else
    shodan_ports=$(echo "$response" | grep -oP '"ports"\s*:\s*\[\K[^\]]+' \
      | tr ',' ' ' | tr -d '\t')
  fi

  local shodan_vulns
  if _has_jq; then
    shodan_vulns=$(echo "$response" | jq -r '.vulns | keys[]?' 2>/dev/null \
      | sort | head -5 | tr '\n' '  ')
  else
    shodan_vulns=$(echo "$response" | grep -oP '"CVE-[0-9]{4}-[0-9]+"' \
      | tr -d '"' | head -5 | tr '\n' '  ')
  fi

  echo ""
  echo -e "  ${CYAN}╔══ SHODAN EXTERNAL VIEW ══════════════════════════════════════════════╗${RESET}"
  echo -e "  ${CYAN}║${RESET}  ${YELLOW}Target IP   :${RESET}  ${WHITE}${ip}${RESET}"
  [[ -n "$org" ]]      && echo -e "  ${CYAN}║${RESET}  ${YELLOW}Organization:${RESET}  ${WHITE}${org}${RESET}"
  [[ -n "$isp" ]]      && echo -e "  ${CYAN}║${RESET}  ${YELLOW}ISP         :${RESET}  ${WHITE}${isp}${RESET}"
  [[ -n "$country" ]]  && echo -e "  ${CYAN}║${RESET}  ${YELLOW}Location    :${RESET}  ${WHITE}${city:+${city}, }${country}${RESET}"
  [[ -n "$hostname" ]] && echo -e "  ${CYAN}║${RESET}  ${YELLOW}Hostname    :${RESET}  ${WHITE}${hostname}${RESET}"
  echo -e "  ${CYAN}╠══ Ports (Shodan perspective) ══════════════════════════════════════╣${RESET}"
  if [[ -n "$shodan_ports" ]]; then
    echo -e "  ${CYAN}║${RESET}  ${GREEN}${shodan_ports}${RESET}"
  else
    echo -e "  ${CYAN}║${RESET}  ${GRAY}No port data returned${RESET}"
  fi

  if [[ -n "$shodan_vulns" ]]; then
    echo -e "  ${CYAN}╠══ Vulnerabilities Detected by Shodan ══════════════════════════════╣${RESET}"
    echo -e "  ${CYAN}║${RESET}  ${RED}${SKULL} ${shodan_vulns}${RESET}"
  fi

  echo -e "  ${CYAN}╠══ Service Banners ══════════════════════════════════════════════════╣${RESET}"
  if _has_jq; then
    local banner_count=0
    while IFS= read -r banner_line && [[ $banner_count -lt 5 ]]; do
      [[ -z "$banner_line" ]] && continue
      echo -e "  ${CYAN}║${RESET}  ${GRAY}${banner_line}${RESET}"
      ((banner_count++))
    done < <(echo "$response" | jq -r '
      .data[]? |
      ((.port | tostring) + "/" + (.transport // "tcp") + "  " +
       (.product // "") + " " + (.version // "") +
       "  →  " + ((.data // "") | split("\n")[0] | .[0:55]))
    ' 2>/dev/null)
    [[ $banner_count -eq 0 ]] && \
      echo -e "  ${CYAN}║${RESET}  ${GRAY}No banner data returned${RESET}"
  else
    echo -e "  ${CYAN}║${RESET}  ${DIM}Install jq for full banner parsing${RESET}"
  fi

  echo -e "  ${CYAN}╚══════════════════════════════════════════════════════════════════════╝${RESET}"
}

# ── CIRCL CVE Live Lookup ───────────────────────────────────────────────────

_sanitize_version() {
  local v="$1"
  v="${v%%-*}"
  v="${v%%+*}"
  v="${v%%[^0-9A-Za-z]*}"
  if [[ ! "$v" =~ ^[0-9]+\.[0-9] ]]; then
    return 1
  fi
  printf '%s' "$v"
}

_extract_nmap_versions() {
  local nmap_output="$1"

  while IFS= read -r line; do
    if [[ "$line" =~ ^([0-9]+)/([a-z]+)[[:space:]]+open[[:space:]]+([^[:space:]]+)[[:space:]]+(.*) ]]; then
      local port="${BASH_REMATCH[1]}"
      local service="${BASH_REMATCH[3]}"
      local banner="${BASH_REMATCH[4]}"

      if [[ "$banner" =~ ([A-Za-z][A-Za-z0-9_/]+)[[:space:]]+([0-9]+\.[0-9]+[0-9.p]*) ]]; then
        local product="${BASH_REMATCH[1],,}"
        local raw_version="${BASH_REMATCH[2]}"

        local version
        version=$(_sanitize_version "$raw_version") || continue

        product="${product// /_}"
        echo "${port}|${service}|${product}|${version}"
      fi
    fi
  done <<< "$nmap_output"
}

_extract_nmap_services() {
  local nmap_output="$1"
  while IFS= read -r line; do
    if [[ "$line" =~ ^([0-9]+)/([a-z]+)[[:space:]]+open[[:space:]]+([^[:space:]]+) ]]; then
      echo "${BASH_REMATCH[1]}|${BASH_REMATCH[3]}"
    fi
  done <<< "$nmap_output"
}

_cpe_lookup() {
  case "${1,,}" in
    openssh|ssh)                       echo "openbsd openssh" ;;
    apache|httpd|http_server|http|www) echo "apache http_server" ;;
    nginx)                             echo "nginx nginx" ;;
    lighttpd)                          echo "lighttpd lighttpd" ;;
    iis|microsoft-iis)                 echo "microsoft iis" ;;
    mysql)                             echo "mysql mysql" ;;
    mariadb)                           echo "mariadb mariadb" ;;
    postgresql|postgres)               echo "postgresql postgresql" ;;
    mongodb)                           echo "mongodb mongodb" ;;
    redis)                             echo "redislabs redis" ;;
    elasticsearch)                     echo "elastic elasticsearch" ;;
    vsftpd|ftp)                        echo "vsftpd vsftpd" ;;
    proftpd)                           echo "proftpd_project proftpd" ;;
    samba|smbd|smb|microsoft-ds|netbios-ssn) echo "samba samba" ;;
    bind|named|domain)                 echo "isc bind" ;;
    postfix|smtp|mail)                 echo "postfix postfix" ;;
    sendmail)                          echo "sendmail sendmail" ;;
    dovecot|pop3|imap)                 echo "dovecot dovecot" ;;
    exim)                              echo "exim exim" ;;
    tomcat)                            echo "apache tomcat" ;;
    php)                               echo "php php" ;;
    openssl|https|ssl)                 echo "openssl openssl" ;;
    jenkins)                           echo "jenkins jenkins" ;;
    wordpress)                         echo "wordpress wordpress" ;;
    drupal)                            echo "drupal drupal" ;;
    filezilla)                         echo "filezilla-project filezilla_server" ;;
    rdp|ms-wbt-server|msrdp)           echo "microsoft remote_desktop_protocol" ;;
    telnet)                            echo "mit telnet" ;;
    snmp)                              echo "net-snmp net-snmp" ;;
    ntp)                               echo "ntp ntp" ;;
    rtsp)                              echo "live555 live555" ;;
    vnc|rfb)                           echo "realvnc realvnc" ;;
    cups|ipp)                          echo "apple cups" ;;
    opensslv*)                         echo "openssl openssl" ;;
    *)
      local p="${1,,}"
      p="${p// /_}"
      p="${p//-/_}"
      echo "${p} ${p}" ;;
  esac
}

_circl_search() {
  local raw_product="$1"

  local vendor product
  read -r vendor product <<< "$(_cpe_lookup "$raw_product")"

  local response
  response=$(curl -sf --max-time 10 \
    "https://cve.circl.lu/api/search/${vendor}/${product}" 2>/dev/null)

  if [[ -z "$response" || "$response" == "null" || \
        "$response" == "[]"  || "$response" == "{}" ]]; then
    return 1
  fi

  if _has_jq; then
    local count
    count=$(echo "$response" | jq '(.results // []) | length' 2>/dev/null)
    [[ -z "$count" || "$count" == "0" ]] && return 1
  else
    echo "$response" | grep -q '"CVE-' || return 1
  fi

  echo "$response"
}

_extract_top5_cves() {
  local response="$1"

  if _has_jq; then
    echo "$response" | jq -r '
      (.results // (if type == "array" then . else [] end))
      | map(select((.id // "") | startswith("CVE-")))
      | sort_by(
          -.( .cvss
              | if   . == null          then 0
                elif type == "number"   then .
                else (tonumber? // 0)
                end
            )
        )
      | .[0:5][]
      | [
          .id,
          ( .cvss
            | if   . == null        then "N/A"
              elif type == "number" then tostring
              else .
              end ),
          ((.summary // "") | ltrimstr(" ") | .[0:68])
        ]
      | join("|")
    ' 2>/dev/null | grep -v '^[[:space:]]*$'
  else
    echo "$response" \
      | grep -oE '"id"[[:space:]]*:[[:space:]]*"CVE-[0-9]+-[0-9]+"' \
      | grep -oE 'CVE-[0-9]+-[0-9]+' \
      | sort -u \
      | head -5 \
      | while IFS= read -r cid; do
          echo "${cid}|N/A|"
        done
  fi
}

_print_circl_result() {
  local port="$1" service="$2" product="$3" version="$4"
  shift 4
  local records=("$@")

  local clean=()
  for r in "${records[@]}"; do
    [[ -n "$r" ]] && clean+=("$r")
  done
  [[ ${#clean[@]} -eq 0 ]] && return

  printf "  ${WHITE}%-7s${RESET} ${CYAN}%-18s${RESET}  ${DIM}%s %s${RESET}\n" \
    "$port" "$service" "$product" "$version"

  for record in "${clean[@]}"; do
    IFS='|' read -r cve_id cvss summary <<< "$record"
    [[ -z "$cve_id" ]] && continue
    local cvss_label=""
    [[ -n "$cvss" && "$cvss" != "N/A" ]] && cvss_label="  ${YELLOW}CVSS:${cvss}${RESET}"
    echo -e "          ${RED}${SKULL} ${BOLD}${cve_id}${RESET}${cvss_label}"
    [[ -n "$summary" ]] && \
      echo -e "              ${GRAY}${summary}...${RESET}"
  done
  echo ""
}

# ── Network reachability check ──────────────────────────────────────────────

_intel_net_ok() {
  curl -sf --max-time 5 --head "https://cve.circl.lu" &>/dev/null
}

# ── intel command dispatcher ────────────────────────────────────────────────

show_intel_help() {
  echo ""
  echo -e "  ${BOLD}${CYAN}╔══ NexPort — Live Threat Intel Commands ══════════════════════════╗${RESET}"
  echo -e "  ${CYAN}║${RESET}"
  echo -e "  ${CYAN}║${RESET}  ${BOLD}${WHITE}Shodan Integration${RESET}"
  echo -e "  ${CYAN}║${RESET}  ${GREEN}intel set-key <key>${RESET}      Save Shodan API key to ${DIM}~/.nexport/config${RESET}"
  echo -e "  ${CYAN}║${RESET}  ${GREEN}intel clear-key${RESET}          Remove saved Shodan API key"
  echo -e "  ${CYAN}║${RESET}  ${GREEN}intel <ip>${RESET}               Run on-demand Shodan + CVE lookup for an IP"
  echo -e "  ${CYAN}║${RESET}"
  echo -e "  ${CYAN}║${RESET}  ${BOLD}${WHITE}AI Intelligence Layer${RESET}  ${PURPLE}★ NEW${RESET}"
  echo -e "  ${CYAN}║${RESET}  ${GREEN}intel set-ai-key <key>${RESET}   Configure AI provider & save validated key"
  echo -e "  ${CYAN}║${RESET}  ${GREEN}intel clear-ai-key${RESET}       Remove AI API key (revert to standard mode)"
  echo -e "  ${CYAN}║${RESET}  ${GREEN}intel ai-help${RESET}            Show AI Intelligence Layer reference"
  echo -e "  ${CYAN}║${RESET}"
  echo -e "  ${CYAN}║${RESET}  ${GRAY}Shodan key can also be supplied via env: ${GREEN}export SHODAN_API_KEY=<key>${RESET}"
  echo -e "  ${CYAN}║${RESET}  ${GRAY}CVE lookup (CIRCL.LU) runs automatically after every scan${RESET}"
  echo -e "  ${CYAN}║${RESET}"
  echo -e "  ${BOLD}${CYAN}╚══════════════════════════════════════════════════════════════════╝${RESET}"
  echo ""
}

intel_dispatch() {
  local subcmd="${1:-}"
  shift || true

  case "$subcmd" in
    "set-key")
      intel_set_shodan_key "${1:-}" ;;
    "clear-key")
      intel_clear_shodan_key ;;
    "set-ai-key")
      ai_intel_set_key "${1:-}" ;;
    "clear-ai-key")
      ai_intel_clear_key ;;
    "ai-help")
      show_ai_intel_help ;;
    "help"|"--help"|"")
      show_intel_help ;;
    *)
      if _is_public_ipv4 "$subcmd"; then
        _intel_load_config
        local api_key="${SHODAN_API_KEY:-}"
        run_live_threat_intel "$subcmd" ""
      else
        echo -e "\n  ${RED}${FAIL} Unknown intel command: '${subcmd}'${RESET}"
        show_intel_help
      fi
      ;;
  esac
}

# ── Main orchestrator — called after every scan ─────────────────────────────

run_live_threat_intel() {
  local target="$1"
  local nmap_output="${2:-}"

  _intel_load_config

  local api_key="${SHODAN_API_KEY:-}"
  local has_shodan=false
  local has_network=false

  [[ -n "$api_key" ]] && has_shodan=true

  if _intel_net_ok; then
    has_network=true
  fi

  if ! $has_shodan && ! $has_network; then
    echo -e "  ${GRAY}${INFO} Live Threat Intel: network unreachable — skipping.${RESET}\n"
    return
  fi

  echo ""
  echo -e "  ${CYAN}╔══════════════════════════════════════════════════════════════════════╗${RESET}"
  echo -e "  ${CYAN}║${RESET}  ${BOLD}${FIRE} LIVE THREAT INTELLIGENCE${RESET}                                      ${CYAN}║${RESET}"
  echo -e "  ${CYAN}║${RESET}  ${GRAY}Real-time data from Shodan & CIRCL CVE API${RESET}                         ${CYAN}║${RESET}"
  echo -e "  ${CYAN}╚══════════════════════════════════════════════════════════════════════╝${RESET}"
  echo ""

  # ── Shodan block ──────────────────────────────────────────────────────────
  if $has_shodan; then
    local shodan_ip
    shodan_ip=$(_resolve_to_ip "$target" 2>/dev/null)
    if [[ -n "$shodan_ip" ]] && _is_public_ipv4 "$shodan_ip"; then
      echo -e "  ${CYAN}${ARROW} Querying Shodan for ${WHITE}${target}${CYAN}...${RESET}"
      local shodan_resp
      shodan_resp=$(_shodan_fetch "$shodan_ip" "$api_key" 2>&1)
      if [[ $? -eq 0 && -n "$shodan_resp" ]]; then
        _shodan_display "$shodan_resp" "$shodan_ip"
      fi
    else
      echo -e "  ${GRAY}${INFO} Shodan: ${WHITE}${target}${GRAY} is a private/local address — external lookup skipped.${RESET}"
    fi
  else
    echo -e "  ${GRAY}${INFO} Shodan: No API key configured.${RESET}"
    echo -e "  ${DIM}  Provide one with:  ${GREEN}nexport intel set-key <api-key>${RESET}"
    echo -e "  ${DIM}  Or via env:        ${GREEN}export SHODAN_API_KEY=<api-key>${RESET}"
  fi

  echo ""

  # ── CIRCL CVE live lookup block ───────────────────────────────────────────
  if $has_network && [[ -n "$nmap_output" ]]; then
    echo -e "  ${BOLD}${WHITE}[ LIVE CVE LOOKUP — CIRCL.LU ]${RESET}"
    divider
    echo -e "  ${GRAY}Querying https://cve.circl.lu for each detected service...${RESET}\n"

    local version_entries=()
    while IFS= read -r line; do
      [[ -n "$line" ]] && version_entries+=("$line")
    done < <(_extract_nmap_versions "$nmap_output")

    local service_entries=()
    while IFS= read -r line; do
      [[ -n "$line" ]] && service_entries+=("$line")
    done < <(_extract_nmap_services "$nmap_output")

    if [[ ${#service_entries[@]} -eq 0 ]]; then
      echo -e "  ${GRAY}${INFO} No open services detected in scan output.${RESET}"
      echo ""
    else
      local -A handled_ports=()
      local found_any=false

      # ── Phase 1: versioned lookup ─────────────────────────────────────────
      for entry in "${version_entries[@]}"; do
        IFS='|' read -r port service product version <<< "$entry"
        [[ -z "$product" ]] && continue

        handled_ports["$port"]=1

        printf "  ${WHITE}%-7s${RESET} ${CYAN}%-18s${RESET}  ${DIM}%s %s${RESET}\n" \
          "$port" "$service" "$product" "$version"

        local circl_resp
        circl_resp=$(_circl_search "$product")
        if [[ $? -ne 0 || -z "$circl_resp" ]]; then
          echo -e "          ${GRAY}${INFO} CIRCL returned no data for '${product}' — cannot assess.${RESET}"
          echo ""
          continue
        fi

        local -a raw_records clean_records
        mapfile -t raw_records < <(_extract_top5_cves "$circl_resp")
        clean_records=()
        for r in "${raw_records[@]}"; do
          [[ -n "$r" ]] && clean_records+=("$r")
        done

        if [[ ${#clean_records[@]} -gt 0 ]]; then
          for record in "${clean_records[@]}"; do
            IFS='|' read -r cve_id cvss summary <<< "$record"
            [[ -z "$cve_id" ]] && continue
            local cvss_label=""
            [[ -n "$cvss" && "$cvss" != "N/A" ]] && \
              cvss_label="  ${YELLOW}CVSS:${cvss}${RESET}"
            echo -e "          ${RED}${SKULL} ${BOLD}${cve_id}${RESET}${cvss_label}"
            [[ -n "$summary" ]] && \
              echo -e "              ${GRAY}${summary}...${RESET}"
          done
          found_any=true
        else
          echo -e "          ${GREEN}${OK} No known CVEs for this version — Service appears up-to-date.${RESET}"
        fi
        echo ""
      done

      # ── Phase 2: service-name fallback ────────────────────────────────────
      for sentry in "${service_entries[@]}"; do
        IFS='|' read -r sport sservice <<< "$sentry"
        [[ -n "${handled_ports[$sport]:-}" ]] && continue

        printf "  ${WHITE}%-7s${RESET} ${CYAN}%-18s${RESET}  ${DIM}(no version detected — generic lookup)${RESET}\n" \
          "$sport" "$sservice"

        local circl_resp2
        circl_resp2=$(_circl_search "$sservice")
        if [[ $? -ne 0 || -z "$circl_resp2" ]]; then
          echo -e "          ${GRAY}${INFO} No threat data for '${sservice}' — run with ${GREEN}-sV${GRAY} for precise version lookup.${RESET}"
          echo ""
          continue
        fi

        local -a raw2 clean2
        mapfile -t raw2 < <(_extract_top5_cves "$circl_resp2")
        clean2=()
        for r in "${raw2[@]}"; do
          [[ -n "$r" ]] && clean2+=("$r")
        done

        if [[ ${#clean2[@]} -gt 0 ]]; then
          echo -e "          ${YELLOW}${WARN} Known CVEs for ${sservice} (version unconfirmed):${RESET}"
          for record in "${clean2[@]}"; do
            IFS='|' read -r cve_id cvss summary <<< "$record"
            [[ -z "$cve_id" ]] && continue
            local cvss_label2=""
            [[ -n "$cvss" && "$cvss" != "N/A" ]] && \
              cvss_label2="  ${YELLOW}CVSS:${cvss}${RESET}"
            echo -e "          ${RED}${SKULL} ${BOLD}${cve_id}${RESET}${cvss_label2}"
            [[ -n "$summary" ]] && \
              echo -e "              ${GRAY}${summary}...${RESET}"
          done
          found_any=true
        else
          echo -e "          ${GREEN}${OK} No known CVEs found for '${sservice}'.${RESET}"
        fi
        echo ""
      done

      if ! $found_any && [[ ${#version_entries[@]} -eq 0 ]]; then
        echo -e "  ${GREEN}${OK} No CVE matches — consider running with ${GREEN}-sV${RESET} for deeper version analysis.${RESET}"
        echo ""
      fi
    fi
  elif $has_network && [[ -z "$nmap_output" ]]; then
    echo -e "  ${BOLD}${WHITE}[ LIVE CVE LOOKUP — CIRCL.LU ]${RESET}"
    divider
    echo -e "  ${GRAY}${INFO} No nmap output provided — CVE version lookup skipped.${RESET}"
    echo ""
  fi

  echo -e "  ${DIM}──────────────── Live Threat Intel complete ────────────────────────${RESET}"
  echo ""
}
