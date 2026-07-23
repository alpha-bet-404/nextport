#!/usr/bin/env bash

# Copyright (c) 2026 Steven Osama (zeroman). All rights reserved.
# Lead Developer: Steven Osama | GitHub: @zeroman-root

NEXPORT_SCAN_OUTDIR="${HOME}/.nexport/scans"
NEXPORT_REPORTS_DIR="${HOME}/.nexport/reports"

_ensure_scan_dir() {
  mkdir -p "$NEXPORT_SCAN_OUTDIR"
}

_ensure_reports_dir() {
  mkdir -p "$NEXPORT_REPORTS_DIR"
}

_nmap_not_found() {
  echo -e "\n  ${RED}${FAIL} nmap is not installed on this system.${RESET}"
  echo -e "  ${YELLOW}Install with one of:${RESET}"
  printf "  ${GREEN}%-42s${RESET} %s\n" "sudo apt install nmap"  "(Debian / Ubuntu)"
  printf "  ${GREEN}%-42s${RESET} %s\n" "sudo dnf install nmap"  "(Fedora / RHEL)"
  printf "  ${GREEN}%-42s${RESET} %s\n" "sudo pacman -S nmap"    "(Arch Linux)"
  printf "  ${GREEN}%-42s${RESET} %s\n" "brew install nmap"      "(macOS)"
  echo -e "\n  ${GRAY}Use ${GREEN}paste${GRAY} to summarize existing nmap output without running a scan.${RESET}\n"
}

_select_scan_mode() {
  echo -e "  ${CYAN}Select scan mode:${RESET}" >/dev/tty
  echo -e "  ${GREEN}1${RESET}  ${WHITE}Quick${RESET}      - Top 1000 ports, no service detection  ${DIM}(~10s)${RESET}" >/dev/tty
  echo -e "  ${GREEN}2${RESET}  ${WHITE}Standard${RESET}   - Top 1000 ports + version detection    ${DIM}(~30s)${RESET}" >/dev/tty
  echo -e "  ${GREEN}3${RESET}  ${WHITE}Full${RESET}       - All 65535 ports + version detection   ${DIM}(~5-20min)${RESET}" >/dev/tty
  echo -e "  ${GREEN}4${RESET}  ${WHITE}Stealth${RESET}    - SYN scan, OS detect, script engine    ${DIM}(requires root)${RESET}" >/dev/tty
  echo -e "  ${GREEN}5${RESET}  ${WHITE}Vuln${RESET}       - Top 1000 ports + NSE vuln scripts      ${DIM}(requires root)${RESET}" >/dev/tty
  echo -e "  ${GREEN}6${RESET}  ${WHITE}Custom${RESET}     - Enter your own nmap flags" >/dev/tty
  echo "" >/dev/tty

  local scan_choice
  while true; do
    echo -ne "  ${YELLOW}Choice [1-6]: ${RESET}" >/dev/tty
    read -r scan_choice </dev/tty

    case "$scan_choice" in
      1|2|3|4|5) break ;;
      6)
        echo -ne "  ${YELLOW}Enter nmap flags: ${RESET}" >/dev/tty
        local custom_flags
        read -r custom_flags </dev/tty
        if [[ -n "$custom_flags" ]]; then
          echo "$custom_flags"
        else
          echo -e "  ${RED}No flags entered. Defaulting to Quick scan.${RESET}" >/dev/tty
          echo "-T4 --open"
        fi
        return
        ;;
      "")
        echo -e "  ${YELLOW}No input detected. Please enter a number from 1 to 6.${RESET}" >/dev/tty
        ;;
      *)
        echo -e "  ${RED}Invalid choice '${scan_choice}'. Please enter a number from 1 to 6.${RESET}" >/dev/tty
        ;;
    esac
  done

  case "$scan_choice" in
    1) echo "-T4 --open" ;;
    2) echo "-T4 -sV --open" ;;
    3) echo "-T4 -sV -p- --open" ;;
    4) echo "-T4 -sS -O -A --open" ;;
    5) echo "-T4 -sV --script=vuln --open" ;;
  esac
}

# ── Interactive export format prompt ────────────────────────────────────────

_prompt_export_choice() {
  echo "" >/dev/tty
  echo -e "  ${CYAN}╔══ Report Export ════════════════════════════════════════════════════╗${RESET}" >/dev/tty
  echo -e "  ${CYAN}║${RESET}  Save scan results to a file?  ${DIM}(output still shown on screen)${RESET}  ${CYAN}║${RESET}" >/dev/tty
  echo -e "  ${CYAN}╚═════════════════════════════════════════════════════════════════════╝${RESET}" >/dev/tty
  echo -ne "  ${YELLOW}Save report? [y/N]: ${RESET}" >/dev/tty

  local save_choice
  read -r save_choice </dev/tty
  if [[ "${save_choice,,}" != "y" ]]; then
    echo "none"
    return
  fi

  echo "" >/dev/tty
  echo -e "  ${CYAN}Select report format:${RESET}" >/dev/tty
  echo -e "  ${GREEN}1${RESET}  ${WHITE}Text File${RESET}   (.txt)   Plain readable report" >/dev/tty
  echo -e "  ${GREEN}2${RESET}  ${WHITE}Markdown${RESET}    (.md)    Formatted for GitHub / docs" >/dev/tty
  echo -e "  ${GREEN}3${RESET}  ${WHITE}JSON${RESET}        (.json)  Structured machine-readable" >/dev/tty
  echo -e "  ${GREEN}4${RESET}  ${WHITE}HTML Report${RESET} (.html)  Styled browser-viewable page" >/dev/tty
  echo "" >/dev/tty

  local fmt_choice
  while true; do
    echo -ne "  ${YELLOW}Format [1-4]: ${RESET}" >/dev/tty
    read -r fmt_choice </dev/tty
    case "$fmt_choice" in
      1) echo "txt";  return ;;
      2) echo "md";   return ;;
      3) echo "json"; return ;;
      4) echo "html"; return ;;
      "") echo -e "  ${YELLOW}Please enter 1, 2, 3 or 4.${RESET}" >/dev/tty ;;
      *)  echo -e "  ${RED}Invalid choice. Enter 1, 2, 3 or 4.${RESET}" >/dev/tty ;;
    esac
  done
}

# ── ANSI code stripper ──────────────────────────────────────────────────────

_strip_ansi() {
  sed 's/\x1b\[[0-9;?]*[a-zA-Z]//g; s/\r//g'
}

# ── Report writers ──────────────────────────────────────────────────────────

_write_nexport_report() {
  local format="$1"
  local target="$2"
  local nmap_flags="$3"
  local timestamp="$4"
  local nmap_raw="$5"
  local analysis_text="$6"

  _ensure_reports_dir

  local safe_target="${target//\//_}"
  local ts_slug
  ts_slug=$(date +"%Y%m%d_%H%M%S")
  local outfile="${NEXPORT_REPORTS_DIR}/nexport_${safe_target}_${ts_slug}.${format}"

  case "$format" in
    txt)
      {
        printf '%0.s=' {1..56}; echo
        echo "  NEXPORT — Intelligent Threat Analysis Suite"
        printf '%0.s=' {1..56}; echo
        printf "  %-12s %s\n" "Target:"     "$target"
        printf "  %-12s %s\n" "Scan Mode:"  "nmap $nmap_flags $target"
        printf "  %-12s %s\n" "Date/Time:"  "$timestamp"
        printf '%0.s=' {1..56}; echo
        echo ""
        echo "[ RAW NMAP OUTPUT ]"
        printf '%0.s-' {1..56}; echo
        echo "$nmap_raw"
        echo ""
        printf '%0.s-' {1..56}; echo
        echo "[ ANALYSIS & THREAT INTELLIGENCE ]"
        printf '%0.s-' {1..56}; echo
        echo "$analysis_text"
        echo ""
        printf '%0.s=' {1..56}; echo
        echo "  Report generated by NEXPORT — Intelligent Threat Analysis Suite | Steven Osama (zeroman)"
        printf '%0.s=' {1..56}; echo
      } > "$outfile"
      ;;

    md)
      {
        echo "# NEXPORT — Intelligent Threat Analysis Suite"
        echo ""
        echo "| Field | Value |"
        echo "|-------|-------|"
        echo "| **Target** | \`${target}\` |"
        echo "| **Scan Mode** | \`nmap ${nmap_flags} ${target}\` |"
        echo "| **Date / Time** | ${timestamp} |"
        echo ""
        echo "---"
        echo ""
        echo "## Raw Nmap Output"
        echo ""
        echo '```'
        echo "$nmap_raw"
        echo '```'
        echo ""
        echo "## Analysis & Threat Intelligence"
        echo ""
        echo '```'
        echo "$analysis_text"
        echo '```'
        echo ""
        echo "---"
        echo ""
        echo "*Report generated by [NEXPORT](https://github.com/zeroman-root) — Intelligent Threat Analysis Suite | (zeroman)*"
      } > "$outfile"
      ;;

    json)
      local esc_target esc_flags esc_nmap esc_analysis
      esc_target=$(printf '%s' "$target"         | sed 's/\\/\\\\/g; s/"/\\"/g')
      esc_flags=$(printf '%s'  "$nmap_flags"     | sed 's/\\/\\\\/g; s/"/\\"/g')
      esc_nmap=$(printf '%s'   "$nmap_raw"       | sed 's/\\/\\\\/g; s/"/\\"/g; s/      /\\t/g' \
                  | awk '{printf "%s\\n", $0}')
      esc_analysis=$(printf '%s' "$analysis_text" | sed 's/\\/\\\\/g; s/"/\\"/g; s/     /\\t/g' \
                  | awk '{printf "%s\\n", $0}')
      {
        printf '{\n'
        printf '  "tool": "NEXPORT — Intelligent Threat Analysis Suite",\n'
        printf '  "author": "(zeroman)",\n'
        printf '  "report": {\n'
        printf '    "target": "%s",\n'           "$esc_target"
        printf '    "nmap_command": "nmap %s %s",\n' "$esc_flags" "$esc_target"
        printf '    "timestamp": "%s",\n'        "$timestamp"
        printf '    "nmap_output": "%s",\n'      "$esc_nmap"
        printf '    "analysis": "%s"\n'          "$esc_analysis"
        printf '  }\n'
        printf '}\n'
      } > "$outfile"
      ;;

    html)
      local h_target h_flags h_nmap h_analysis
      h_target=$(printf '%s'   "$target"         | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')
      h_flags=$(printf '%s'    "$nmap_flags"     | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')
      h_nmap=$(printf '%s'     "$nmap_raw"       | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')
      h_analysis=$(printf '%s' "$analysis_text"  | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')
      cat > "$outfile" << HTMLEOF
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>NEXPORT — ${h_target}</title>
<style>
*{box-sizing:border-box;margin:0;padding:0}
body{background:#080b0f;color:#a8b5c4;font-family:'Courier New',Courier,monospace;padding:28px 32px;line-height:1.65}
h1{color:#00e5cc;font-size:1.45rem;border-bottom:1px solid #00e5cc33;padding-bottom:12px;margin-bottom:22px;letter-spacing:.04em}
h2{color:#00aaff;font-size:1rem;margin:32px 0 12px;text-transform:uppercase;letter-spacing:.08em}
.badge{display:inline-block;background:#00e5cc14;color:#00e5cc;border:1px solid #00e5cc33;
       border-radius:3px;padding:1px 8px;font-size:.75rem;margin-left:10px;vertical-align:middle;letter-spacing:.06em}
table{border-collapse:collapse;width:100%;max-width:680px;margin-bottom:24px}
td{padding:7px 16px;border:1px solid #18222e;font-size:.9rem}
td:first-child{color:#4a6a8a;width:140px;white-space:nowrap}
td:last-child{color:#d8e4f0}
pre{background:#0b0f14;border:1px solid #18222e;border-left:3px solid #00e5cc33;
    padding:16px;border-radius:4px;overflow-x:auto;white-space:pre-wrap;
    word-break:break-all;font-size:.85rem;max-height:560px;overflow-y:auto;line-height:1.55}
footer{margin-top:44px;padding-top:14px;border-top:1px solid #18222e;
       color:#2e3e50;font-size:.78rem;text-align:center}
footer a{color:#3a5a7a;text-decoration:none}
</style>
</head>
<body>
<h1>&#9889; NEXPORT — Intelligent Threat Analysis Suite <span class="badge">SECURITY</span></h1>
<table>
<tr><td>Target</td><td>${h_target}</td></tr>
<tr><td>Scan Command</td><td>nmap ${h_flags} ${h_target}</td></tr>
<tr><td>Date / Time</td><td>${timestamp}</td></tr>
<tr><td>Generated By</td><td>NEXPORT — Intelligent Threat Analysis Suite &mdash; (zeroman)</td></tr>
</table>

<h2>Raw Nmap Output</h2>
<pre>${h_nmap}</pre>

<h2>Analysis &amp; Threat Intelligence</h2>
<pre>${h_analysis}</pre>

<footer>
  Generated by <strong>NEXPORT</strong> — Intelligent Threat Analysis Suite &mdash;
  Author: (zeroman) &mdash;
  <a href="https://github.com/zeroman-root">GitHub</a>
</footer>
</body>
</html>
HTMLEOF
      ;;
  esac

  echo "$outfile"
}

# ── Legacy auto-save (raw nmap output to ~/.nexport/scans/) ─────────────────

_parse_open_ports_from_nmap() {
  local nmap_output="$1"
  local ports=()
  while IFS= read -r line; do
    if [[ "$line" =~ ^([0-9]+)/[a-z]+[[:space:]]+open ]]; then
      ports+=("${BASH_REMATCH[1]}")
    fi
  done <<< "$nmap_output"
  echo "${ports[@]}"
}

_save_scan_report() {
  local target="$1"
  local output="$2"
  local flags="$3"
  _ensure_scan_dir
  local timestamp
  timestamp=$(date +"%Y%m%d_%H%M%S")
  local safe_target="${target//\//_}"
  local outfile="${NEXPORT_SCAN_OUTDIR}/scan_${safe_target}_${timestamp}.txt"
  {
    echo "NEXPORT — Intelligent Threat Analysis Suite"
    echo "Target  : $target"
    echo "Flags   : nmap $flags $target"
    echo "Date    : $(date)"
    echo "======================================"
    echo "$output"
  } > "$outfile"
  echo "$outfile"
}

# ── Main scan runner ─────────────────────────────────────────────────────────

run_nmap_scan() {
  local target="$1"

  if ! command -v nmap &>/dev/null; then
    _nmap_not_found
    return
  fi

  clear
  echo -e "\n  ${BOLD}${CYAN}NEXPORT — Live Nmap Scan Engine${RESET}"
  echo -e "  ${GRAY}Target: ${WHITE}${target}${RESET}\n"

  # ── Step 1: Scan mode selection ───────────────────────────────────────────
  local nmap_flags
  local _mode_tmp
  _mode_tmp=$(mktemp /tmp/nexport_mode_XXXXXX)
  _select_scan_mode > "$_mode_tmp"
  nmap_flags=$(cat "$_mode_tmp")
  rm -f "$_mode_tmp"

  if [[ -z "$nmap_flags" ]]; then
    echo -e "  ${RED}${FAIL} Failed to select scan mode. Aborting.${RESET}\n"
    return 1
  fi

  # ── Step 2: Export format prompt ──────────────────────────────────────────
  local export_format
  local _fmt_tmp
  _fmt_tmp=$(mktemp /tmp/nexport_fmt_XXXXXX)
  _prompt_export_choice > "$_fmt_tmp"
  export_format=$(cat "$_fmt_tmp")
  rm -f "$_fmt_tmp"

  local scan_timestamp
  scan_timestamp=$(date "+%Y-%m-%d %H:%M:%S")

  # ── Step 3: Run nmap, stream live to terminal ─────────────────────────────
  echo ""
  echo -e "  ${CYAN}Executing: ${WHITE}nmap ${nmap_flags} ${target}${RESET}"
  echo -e "  ${GRAY}Streaming results live...${RESET}"
  echo ""
  thick_divider

  local raw_out_tmp
  raw_out_tmp=$(mktemp /tmp/nexport_scan_XXXXXX.txt)
  nmap $nmap_flags "$target" 2>&1 | tee "$raw_out_tmp"

  thick_divider
  echo ""

  local scan_output
  scan_output=$(cat "$raw_out_tmp")
  rm -f "$raw_out_tmp"

  if ! echo "$scan_output" | grep -q "open"; then
    echo -e "  ${YELLOW}${WARN} No open ports detected in scan output.${RESET}"
    echo -e "  ${GRAY}Check connectivity, firewall rules, and consider using sudo for SYN scan.${RESET}\n"
    return
  fi

  # ── Step 4: Auto-save raw scan log ───────────────────────────────────────
  local saved_path
  saved_path=$(_save_scan_report "$target" "$scan_output" "$nmap_flags")
  echo -e "  ${GREEN}${OK} Scan log saved: ${DIM}${saved_path}${RESET}"
  echo -e "  ${BOLD}${CYAN}Analyzing results against NEXPORT vulnerability database...${RESET}\n"

  # ── Step 5: DB analysis → live threat intel → AI Intelligence Layer (last)
  # Display order: a) DB summary  b) Live threat intel  c) AI Cognitive Analytics
  # AI runs AFTER all other output so that clear() inside _print_overview does not
  # wipe it, and so it appears as a final synthesis layer the user reads last.
  local combined_tmp
  combined_tmp=$(mktemp /tmp/nexport_combined_XXXXXX)

  {
    _summarize_nmap_output "$scan_output" "$target"
    run_live_threat_intel "$target" "$scan_output"
    run_ai_intel_analysis "$scan_output" "$target"
  } 2>&1 | tee "$combined_tmp"

  local combined_raw
  combined_raw=$(cat "$combined_tmp" | tr -d "\0")
  rm -f "$combined_tmp"

  # ── Step 6: Write formatted report if requested ──────────────────────────
  if [[ "$export_format" != "none" ]]; then
    local clean_nmap clean_analysis
    clean_nmap=$(printf '%s' "$scan_output"   | _strip_ansi)
    clean_analysis=$(printf '%s' "$combined_raw" | _strip_ansi)

    local report_path
    report_path=$(_write_nexport_report \
      "$export_format" "$target" "$nmap_flags" \
      "$scan_timestamp" "$clean_nmap" "$clean_analysis")

    echo ""
    echo -e "  ${GREEN}${OK} Scan complete. Report successfully saved to:${RESET}"
    echo -e "  ${WHITE}${BOLD}    ${report_path}${RESET}"
    echo ""
  fi
}
