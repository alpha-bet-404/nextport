#!/usr/bin/env bash

# Copyright (c) 2026 Steven Osama (zeroman). All rights reserved.
# Lead Developer: Steven Osama | GitHub: @zeroman-root

# ── AI Intelligence Layer ────────────────────────────────────────────────────
# Optional module: dormant by default. Activates only when a valid AI API key
# is present in ~/.nexport/config.
#
# Design: Model-agnostic. The module stores and uses whatever provider, model,
# and endpoint the user specifies — it does not hardcode any model name or URL.
# It treats the AI as a generic text processor:  key + endpoint + model → response.
#
# Scope: This module analyses INPUT DATA ONLY. It does not access or modify
# the NEXPORT codebase. Branding and attribution are fully preserved.

_ai_intel_load_config() {
  [[ -f "$NEXPORT_CONFIG_FILE" ]] && source "$NEXPORT_CONFIG_FILE"
}

_ai_intel_is_active() {
  _ai_intel_load_config
  [[ -n "${NEXPORT_AI_KEY:-}" && -n "${NEXPORT_AI_PROVIDER:-}" && -n "${NEXPORT_AI_MODEL:-}" ]]
}

# ── Default endpoints (used only when user leaves endpoint blank) ─────────────

_ai_default_endpoint() {
  local provider="$1" model="${2:-}"
  case "$provider" in
    openai)    echo "https://api.openai.com/v1/chat/completions" ;;
    google)    echo "https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent" ;;
    anthropic) echo "https://api.anthropic.com/v1/messages" ;;
    custom)    echo "" ;;
  esac
}

# ── Interactive setup ─────────────────────────────────────────────────────────

_ai_select_provider() {
  echo "" >/dev/tty
  echo -e "  ${BOLD}${CYAN}╔══ AI Intelligence Layer — Provider Selection ══════════════════════╗${RESET}" >/dev/tty
  echo -e "  ${CYAN}║${RESET}                                                                      ${CYAN}║${RESET}" >/dev/tty
  echo -e "  ${CYAN}║${RESET}  ${GREEN}1${RESET}  ${WHITE}OpenAI${RESET}     — GPT-4o, GPT-4-Turbo, o1, o3 …               ${CYAN}║${RESET}" >/dev/tty
  echo -e "  ${CYAN}║${RESET}  ${GREEN}2${RESET}  ${WHITE}Google${RESET}     — Gemini 2.0 Flash, 1.5 Pro, 1.5 Flash …      ${CYAN}║${RESET}" >/dev/tty
  echo -e "  ${CYAN}║${RESET}  ${GREEN}3${RESET}  ${WHITE}Anthropic${RESET}  — Claude 3.5 Sonnet, Claude 3 Opus …          ${CYAN}║${RESET}" >/dev/tty
  echo -e "  ${CYAN}║${RESET}  ${GREEN}4${RESET}  ${WHITE}Custom${RESET}     — Any OpenAI-compatible API (Ollama, Groq …)  ${CYAN}║${RESET}" >/dev/tty
  echo -e "  ${CYAN}║${RESET}                                                                      ${CYAN}║${RESET}" >/dev/tty
  echo -e "  ${BOLD}${CYAN}╚══════════════════════════════════════════════════════════════════════╝${RESET}" >/dev/tty
  echo "" >/dev/tty

  local choice
  while true; do
    echo -ne "  ${YELLOW}Select provider [1-4]: ${RESET}" >/dev/tty
    read -r choice </dev/tty
    case "$choice" in
      1) echo "openai";    return ;;
      2) echo "google";    return ;;
      3) echo "anthropic"; return ;;
      4) echo "custom";    return ;;
      "") echo -e "  ${YELLOW}Please enter 1, 2, 3 or 4.${RESET}" >/dev/tty ;;
      *)  echo -e "  ${RED}Invalid choice.${RESET}" >/dev/tty ;;
    esac
  done
}

_ai_prompt_model() {
  local provider="$1"
  local suggestion=""
  case "$provider" in
    openai)    suggestion="gpt-4o" ;;
    google)    suggestion="gemini-2.0-flash" ;;
    anthropic) suggestion="claude-3-5-sonnet-20241022" ;;
    custom)    suggestion="" ;;
  esac

  echo "" >/dev/tty
  if [[ -n "$suggestion" ]]; then
    echo -e "  ${CYAN}Model name${RESET} ${GRAY}(default: ${WHITE}${suggestion}${GRAY}, or type your own):${RESET}" >/dev/tty
  else
    echo -e "  ${CYAN}Model name${RESET} ${GRAY}(e.g. llama3, mistral, gpt-4o-mini):${RESET}" >/dev/tty
  fi

  local model_input
  echo -ne "  ${YELLOW}Model: ${RESET}" >/dev/tty
  read -r model_input </dev/tty

  if [[ -z "$model_input" && -n "$suggestion" ]]; then
    echo "$suggestion"
  elif [[ -z "$model_input" ]]; then
    echo -e "  ${RED}Model name is required for custom providers.${RESET}" >/dev/tty
    echo ""
  else
    echo "$model_input"
  fi
}

_ai_prompt_endpoint() {
  local provider="$1" model="$2"
  local default_url
  default_url=$(_ai_default_endpoint "$provider" "$model")

  echo "" >/dev/tty
  if [[ -n "$default_url" ]]; then
    echo -e "  ${CYAN}API endpoint${RESET} ${GRAY}(press Enter for default):${RESET}" >/dev/tty
    echo -e "  ${DIM}  Default: ${default_url}${RESET}" >/dev/tty
  else
    echo -e "  ${CYAN}API endpoint${RESET} ${GRAY}(full URL, e.g. http://localhost:11434/v1/chat/completions):${RESET}" >/dev/tty
  fi

  local ep_input
  echo -ne "  ${YELLOW}Endpoint: ${RESET}" >/dev/tty
  read -r ep_input </dev/tty

  if [[ -z "$ep_input" && -n "$default_url" ]]; then
    echo "$default_url"
  elif [[ -z "$ep_input" && -z "$default_url" ]]; then
    echo -e "  ${RED}Endpoint URL is required for custom providers.${RESET}" >/dev/tty
    echo ""
  else
    # Strip trailing slash
    echo "${ep_input%/}"
  fi
}

# ── Generic validation (provider-schema aware, fully user-config-driven) ──────

_ai_validate_key() {
  local provider="$1" key="$2" model="$3" endpoint="$4"

  echo -ne "  ${CYAN}${ARROW} Performing handshake validation...${RESET}" >/dev/tty

  local resp http_code tmp_body
  tmp_body=$(mktemp /tmp/nexport_curl_XXXXXX)

  case "$provider" in
    # ── OpenAI schema (OpenAI + Custom) ──────────────────────────────────────
    openai|custom)
      resp=$(curl -sL --max-time 15 \
        -w "%{http_code}" -o "$tmp_body" \
        -H "Authorization: Bearer ${key}" \
        -H "Content-Type: application/json" \
        -d "{\"model\":\"${model}\",\"messages\":[{\"role\":\"user\",\"content\":\"ping\"}],\"max_tokens\":1}" \
        "${endpoint}" 2>/dev/null)
      ;;
    # ── Google Gemini schema ──────────────────────────────────────────────────
    google)
      resp=$(curl -sL --max-time 15 \
        -w "%{http_code}" -o "$tmp_body" \
        -H "Content-Type: application/json" \
        -d '{"contents":[{"parts":[{"text":"ping"}]}],"generationConfig":{"maxOutputTokens":1}}' \
        "${endpoint}?key=${key}" 2>/dev/null)
      ;;
    # ── Anthropic schema ─────────────────────────────────────────────────────
    anthropic)
      resp=$(curl -sL --max-time 15 \
        -w "%{http_code}" -o "$tmp_body" \
        -H "x-api-key: ${key}" \
        -H "anthropic-version: 2023-06-01" \
        -H "Content-Type: application/json" \
        -d "{\"model\":\"${model}\",\"max_tokens\":1,\"messages\":[{\"role\":\"user\",\"content\":\"ping\"}]}" \
        "${endpoint}" 2>/dev/null)
      ;;
  esac

  http_code="$resp"
  local body
  body=$(cat "$tmp_body"); rm -f "$tmp_body"

  # Network failure
  if [[ -z "$body" && ( -z "$http_code" || "$http_code" == "000" ) ]]; then
    local host
    host=$(echo "$endpoint" | grep -oP '(?<=://)([^/]+)')
    echo -e "\r  ${RED}${FAIL} Cannot reach ${host:-endpoint} — check network / endpoint URL.              ${RESET}" >/dev/tty
    return 1
  fi

  # API error (body contains "error")
  if echo "$body" | grep -q '"error"'; then
    local msg
    msg=$(echo "$body" | grep -oP '"message"\s*:\s*"\K[^"]+' | head -1)
    [[ -z "$msg" ]] && msg=$(echo "$body" | grep -oP '"error"\s*:\s*\{[^}]*"message"\s*:\s*"\K[^"]+' | head -1)
    [[ -z "$msg" ]] && msg="API key rejected or model not available"
    echo -e "\r  ${RED}${FAIL} Handshake failed: ${msg}                     ${RESET}" >/dev/tty
    return 1
  fi

  echo -e "\r  ${GREEN}${OK} Handshake successful — key and model confirmed valid.              ${RESET}" >/dev/tty
  return 0
}

# ── Key management ────────────────────────────────────────────────────────────

ai_intel_set_key() {
  local raw_key="${1:-}"

  if [[ -z "$raw_key" ]]; then
    echo -e "\n  ${RED}${FAIL} Usage: intel set-ai-key <your-api-key>${RESET}\n"
    return 1
  fi

  # Step 1: Provider selection
  local provider
  provider=$(_ai_select_provider)
  [[ -z "$provider" ]] && return 1

  # Step 2: Model name (user-specified, with default suggestion)
  local model
  model=$(_ai_prompt_model "$provider")
  if [[ -z "$model" ]]; then
    echo -e "\n  ${RED}${FAIL} Model name is required. Aborting.${RESET}\n"
    return 1
  fi

  # Step 3: Endpoint (user-specified or auto-default)
  local endpoint
  endpoint=$(_ai_prompt_endpoint "$provider" "$model")
  if [[ -z "$endpoint" ]]; then
    echo -e "\n  ${RED}${FAIL} Endpoint URL is required. Aborting.${RESET}\n"
    return 1
  fi

  echo "" >/dev/tty

  # Step 4: Validation handshake using the exact user-provided settings.
  # Key is NOT written to disk until this passes.
  if ! _ai_validate_key "$provider" "$raw_key" "$model" "$endpoint"; then
    echo -e "\n  ${YELLOW}${WARN} Key not saved — handshake validation did not pass.${RESET}"
    echo -e "  ${GRAY}Check the model name, endpoint, and key, then re-run: ${GREEN}intel set-ai-key <key>${RESET}\n"
    return 1
  fi

  # Step 5: Persist all four fields to config
  mkdir -p "$NEXPORT_CONFIG_DIR"
  local tmpfile
  tmpfile=$(mktemp "${NEXPORT_CONFIG_DIR}/config.XXXXXX")
  {
    grep -v "^NEXPORT_AI_KEY="      "$NEXPORT_CONFIG_FILE" 2>/dev/null || true
  } | grep -v "^NEXPORT_AI_PROVIDER=" \
    | grep -v "^NEXPORT_AI_MODEL=" \
    | grep -v "^NEXPORT_AI_ENDPOINT=" \
    | grep -v "^NEXPORT_GOOGLE_MODEL=" > "$tmpfile" 2>/dev/null || true
  printf 'NEXPORT_AI_KEY="%s"\n'      "$raw_key"  >> "$tmpfile"
  printf 'NEXPORT_AI_PROVIDER="%s"\n' "$provider" >> "$tmpfile"
  printf 'NEXPORT_AI_MODEL="%s"\n'    "$model"    >> "$tmpfile"
  printf 'NEXPORT_AI_ENDPOINT="%s"\n' "$endpoint" >> "$tmpfile"
  mv "$tmpfile" "$NEXPORT_CONFIG_FILE"
  chmod 600 "$NEXPORT_CONFIG_FILE"

  local provider_display
  case "$provider" in
    openai)    provider_display="OpenAI" ;;
    google)    provider_display="Google Gemini" ;;
    anthropic) provider_display="Anthropic" ;;
    custom)    provider_display="Custom (OpenAI-compatible)" ;;
  esac

  echo ""
  echo -e "  ${BOLD}${GREEN}${OK} AI Intelligence Layer activated.${RESET}"
  echo -e "  ${CYAN}Provider :${RESET}  ${WHITE}${provider_display}${RESET}"
  echo -e "  ${CYAN}Model    :${RESET}  ${WHITE}${model}${RESET}"
  echo -e "  ${CYAN}Endpoint :${RESET}  ${DIM}${endpoint}${RESET}"
  echo -e "  ${CYAN}Config   :${RESET}  ${DIM}${NEXPORT_CONFIG_FILE}${RESET}"
  echo -e "  ${GRAY}AI Cognitive Analytics will appear after scan data and threat intel.${RESET}\n"
}

ai_intel_clear_key() {
  if [[ ! -f "$NEXPORT_CONFIG_FILE" ]]; then
    echo -e "\n  ${YELLOW}${WARN} No config file found — nothing to clear.${RESET}\n"
    return
  fi
  local tmpfile
  tmpfile=$(mktemp "${NEXPORT_CONFIG_DIR}/config.XXXXXX")
  {
    grep -v "^NEXPORT_AI_KEY="      "$NEXPORT_CONFIG_FILE" 2>/dev/null || true
  } | grep -v "^NEXPORT_AI_PROVIDER=" \
    | grep -v "^NEXPORT_AI_MODEL=" \
    | grep -v "^NEXPORT_AI_ENDPOINT=" \
    | grep -v "^NEXPORT_GOOGLE_MODEL=" > "$tmpfile" 2>/dev/null || true
  mv "$tmpfile" "$NEXPORT_CONFIG_FILE"
  echo -e "\n  ${GREEN}${OK} AI Intelligence Layer cleared. NEXPORT in standard mode.${RESET}\n"
}

# ── JSON escaping ─────────────────────────────────────────────────────────────

_ai_escape_json() {
  printf '%s' "$1" \
    | sed 's/\\/\\\\/g; s/"/\\"/g' \
    | awk '{printf "%s\\n", $0}' \
    | sed '$ s/\\n$//'
}

# ── Generic API dispatcher (model-agnostic) ───────────────────────────────────
# Uses the provider schema to construct the request, but all model names,
# endpoint URLs, and auth headers come entirely from the stored config.

_ai_call_provider() {
  local provider="$1" key="$2" model="$3" endpoint="$4" prompt="$5"

  local escaped
  escaped=$(_ai_escape_json "$prompt")

  local system_msg="You are a security analyst AI embedded in NEXPORT. Analyse the provided scan data and output concise, structured, terminal-friendly security insights for SOC analysts and pentesters. Base all findings STRICTLY on the input data. NEVER fabricate or hallucinate vulnerabilities, CVEs, or services not present in the provided data. If the data is ambiguous or insufficient to assess a category, state explicitly: Insufficient data to assess. Do not reference, modify, or discuss any codebase."
  local esc_sys
  esc_sys=$(_ai_escape_json "$system_msg")

  local response

  case "$provider" in
    # ── OpenAI schema (also used for Custom / OpenAI-compatible) ─────────────
    openai|custom)
      response=$(curl -sL --max-time 35 \
        -H "Authorization: Bearer ${key}" \
        -H "Content-Type: application/json" \
        -d "{\"model\":\"${model}\",\"messages\":[{\"role\":\"system\",\"content\":\"${esc_sys}\"},{\"role\":\"user\",\"content\":\"${escaped}\"}],\"max_tokens\":900,\"temperature\":0.15}" \
        "${endpoint}" 2>/dev/null)

      echo "$response" \
        | grep -oP '"content"\s*:\s*"\K(?:[^"\\]|\\.)*' \
        | head -1 \
        | sed 's/\\n/\n/g; s/\\"/"/g; s/\\\\/\\/g; s/\\t/  /g'
      ;;

    # ── Google Gemini schema ──────────────────────────────────────────────────
    google)
      local full_prompt="${system_msg}

${prompt}"
      local esc_full
      esc_full=$(_ai_escape_json "$full_prompt")

      response=$(curl -sL --max-time 35 \
        -H "Content-Type: application/json" \
        -d "{\"contents\":[{\"parts\":[{\"text\":\"${esc_full}\"}]}],\"generationConfig\":{\"maxOutputTokens\":900,\"temperature\":0.15}}" \
        "${endpoint}?key=${key}" 2>/dev/null)

      echo "$response" \
        | grep -oP '"text"\s*:\s*"\K(?:[^"\\]|\\.)*' \
        | head -1 \
        | sed 's/\\n/\n/g; s/\\"/"/g; s/\\\\/\\/g; s/\\t/  /g'
      ;;

    # ── Anthropic schema ─────────────────────────────────────────────────────
    anthropic)
      response=$(curl -sL --max-time 35 \
        -H "x-api-key: ${key}" \
        -H "anthropic-version: 2023-06-01" \
        -H "Content-Type: application/json" \
        -d "{\"model\":\"${model}\",\"max_tokens\":900,\"system\":\"${esc_sys}\",\"messages\":[{\"role\":\"user\",\"content\":\"${escaped}\"}]}" \
        "${endpoint}" 2>/dev/null)

      echo "$response" \
        | grep -oP '"text"\s*:\s*"\K(?:[^"\\]|\\.)*' \
        | head -1 \
        | sed 's/\\n/\n/g; s/\\"/"/g; s/\\\\/\\/g; s/\\t/  /g'
      ;;
  esac
}

# ── Main analysis orchestrator ────────────────────────────────────────────────
# Called BEFORE raw scan data is displayed. Fully silent if no key is configured.

run_ai_intel_analysis() {
  local scan_data="$1"
  local target="${2:-Unknown}"

  _ai_intel_load_config

  local ai_key="${NEXPORT_AI_KEY:-}"
  local ai_provider="${NEXPORT_AI_PROVIDER:-}"
  local ai_model="${NEXPORT_AI_MODEL:-}"
  local ai_endpoint="${NEXPORT_AI_ENDPOINT:-}"

  # Dormant if any required field is missing
  [[ -z "$ai_key" || -z "$ai_provider" || -z "$ai_model" ]] && return 0

  # Reconstruct missing endpoint from defaults (backwards-compat with old configs)
  if [[ -z "$ai_endpoint" ]]; then
    ai_endpoint=$(_ai_default_endpoint "$ai_provider" "$ai_model")
  fi
  [[ -z "$ai_endpoint" ]] && return 0

  # Truncate oversized inputs to protect against token overflow
  local truncated_data="${scan_data:0:3500}"
  [[ ${#scan_data} -gt 3500 ]] && truncated_data+="
[... input truncated to 3500 chars ...]"

  local prompt="NEXPORT Intelligence Analysis Request
Target: ${target}

Provide a structured security intelligence assessment in FOUR sections:

1. THREAT OVERVIEW
   High-level risk posture based on observed data.

2. CRITICAL FINDINGS
   Immediately dangerous exposures present in the data.
   If none: state 'No critical findings in provided data.'

3. ATTACK SURFACE ANALYSIS
   Key attack vectors an adversary would prioritise based on the data.

4. ANALYST RECOMMENDATIONS
   Top 3 concrete, actionable hardening steps derived strictly from this data.

IMPORTANT: Analyse only what is present in the input. Do not infer, fabricate,
or speculate about services or vulnerabilities not in the provided data.
If a section cannot be assessed from the data, write: 'Insufficient data to assess.'

--- BEGIN SCAN DATA ---
${truncated_data}
--- END SCAN DATA ---"

  local provider_display
  case "$ai_provider" in
    openai)    provider_display="OpenAI · ${ai_model}" ;;
    google)    provider_display="Google Gemini · ${ai_model}" ;;
    anthropic) provider_display="Anthropic · ${ai_model}" ;;
    custom)    provider_display="Custom · ${ai_model}" ;;
    *)         provider_display="${ai_model}" ;;
  esac

  echo ""
  echo -e "  ${CYAN}╔══════════════════════════════════════════════════════════════════════╗${RESET}"
  echo -e "  ${CYAN}║${RESET}  ${BOLD}${PURPLE}★ AI COGNITIVE ANALYTICS${RESET}                                        ${CYAN}║${RESET}"
  echo -e "  ${CYAN}║${RESET}  ${GRAY}${provider_display} · Synthesising scan data above…${RESET}"
  echo -e "  ${CYAN}╚══════════════════════════════════════════════════════════════════════╝${RESET}"
  echo ""

  local ai_tmp
  ai_tmp=$(mktemp /tmp/nexport_ai_XXXXXX)

  _ai_call_provider "$ai_provider" "$ai_key" "$ai_model" "$ai_endpoint" "$prompt" \
    > "$ai_tmp" 2>/dev/null &
  local ai_pid=$!
  spinner "$ai_pid" "AI analyst processing scan data"
  wait "$ai_pid" 2>/dev/null

  local ai_response
  ai_response=$(cat "$ai_tmp")
  rm -f "$ai_tmp"

  if [[ -z "$ai_response" ]]; then
    echo -e "  ${YELLOW}${WARN} AI Intelligence Layer: No response received.${RESET}"
    echo -e "  ${GRAY}  The provider may be unreachable or the key may have expired.${RESET}"
    echo -e "  ${GRAY}  Re-configure: ${GREEN}intel set-ai-key <key>${RESET}"
    echo ""
  echo -e "  ${DIM}────────────────────────── Scan output above ───────────────────────${RESET}"
    echo ""
    return 0
  fi

  echo -e "  ${DIM}────────────────────────────────────────────────────────────────────${RESET}"
  echo ""
  while IFS= read -r line; do
    if [[ -z "$line" ]]; then
      echo ""
    else
      echo -e "  ${line}"
    fi
  done <<< "$ai_response"
  echo ""
  echo -e "  ${DIM}──────────────────────── AI analysis complete ──────────────────────${RESET}"
  echo ""
}

# ── Help text ─────────────────────────────────────────────────────────────────

show_ai_intel_help() {
  _ai_intel_load_config
  local active_model="${NEXPORT_AI_MODEL:-not configured}"
  local active_provider="${NEXPORT_AI_PROVIDER:-none}"
  local active_endpoint="${NEXPORT_AI_ENDPOINT:-}"

  echo ""
  echo -e "  ${BOLD}${CYAN}╔══ NexPort — AI Intelligence Layer ══════════════════════════════════╗${RESET}"
  echo -e "  ${CYAN}║${RESET}"
  echo -e "  ${CYAN}║${RESET}  ${GREEN}intel set-ai-key <key>${RESET}   Interactive setup: provider + model + endpoint"
  echo -e "  ${CYAN}║${RESET}  ${GREEN}intel clear-ai-key${RESET}       Remove AI config (revert to standard mode)"
  echo -e "  ${CYAN}║${RESET}"
  echo -e "  ${CYAN}║${RESET}  ${BOLD}${WHITE}Supported Provider Schemas:${RESET}"
  echo -e "  ${CYAN}║${RESET}    ${GREEN}1)${RESET}  OpenAI     — GPT-4o, o1, o3-mini, any gpt-* model"
  echo -e "  ${CYAN}║${RESET}    ${GREEN}2)${RESET}  Google     — gemini-2.0-flash, gemini-1.5-pro, etc."
  echo -e "  ${CYAN}║${RESET}    ${GREEN}3)${RESET}  Anthropic  — claude-3-5-sonnet-*, claude-3-opus-*, etc."
  echo -e "  ${CYAN}║${RESET}    ${GREEN}4)${RESET}  Custom     — Any OpenAI-compatible API (Ollama, Groq, Mistral …)"
  echo -e "  ${CYAN}║${RESET}"
  echo -e "  ${CYAN}║${RESET}  ${BOLD}${WHITE}Model & Endpoint:${RESET}"
  echo -e "  ${CYAN}║${RESET}  ${GRAY}  You specify the model name and endpoint during setup.${RESET}"
  echo -e "  ${CYAN}║${RESET}  ${GRAY}  NEXPORT does not hardcode any model name or URL.${RESET}"
  echo -e "  ${CYAN}║${RESET}  ${GRAY}  Any model supported by the chosen schema will work.${RESET}"
  echo -e "  ${CYAN}║${RESET}"

  if [[ "$active_provider" != "none" ]]; then
    echo -e "  ${CYAN}║${RESET}  ${BOLD}${WHITE}Current Configuration:${RESET}"
    echo -e "  ${CYAN}║${RESET}    Provider : ${WHITE}${active_provider}${RESET}"
    echo -e "  ${CYAN}║${RESET}    Model    : ${WHITE}${active_model}${RESET}"
    [[ -n "$active_endpoint" ]] && \
      echo -e "  ${CYAN}║${RESET}    Endpoint : ${DIM}${active_endpoint}${RESET}"
    echo -e "  ${CYAN}║${RESET}"
  fi

  echo -e "  ${CYAN}║${RESET}  ${GRAY}When active, AI analysis appears AFTER scan data and threat intel.${RESET}"
  echo -e "  ${CYAN}║${RESET}  ${GRAY}Dormant without a key — standard mode fully unaffected.${RESET}"
  echo -e "  ${CYAN}║${RESET}  ${GRAY}The AI analyses INPUT DATA ONLY. It never touches the codebase.${RESET}"
  echo -e "  ${CYAN}║${RESET}"
  echo -e "  ${BOLD}${CYAN}╚══════════════════════════════════════════════════════════════════════╝${RESET}"
  echo ""
}
