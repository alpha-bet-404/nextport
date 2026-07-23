# ⚡ NEXPORT — Intelligent Threat Analysis Suite

> **Professional Network Port Intelligence, Live Threat Intelligence & AI-Driven Security Analytics Platform**
>
> ---
> 🖥️ **GitHub Profile:** [@alpha-bet-404](https://github.com/alpha-bet-404) <br>
> 📦 **Official Repository:** [github.com/alpha-bet-404/nexport](https://github.com/alpha-bet-404/nexport) <br>
> 🔒 **Copyright:** © 2026 alpha-bet. All rights reserved.

---

**NEXPORT** is an advanced, high-performance security reconnaissance and automation tool tailored for **Kali Linux** and security operations. Designed and engineered by cybersecurity professional **alpha-bet**, it bridges the gap between raw network scanning and actionable vulnerability intelligence.

NEXPORT features **Live Threat Intelligence** — real-time integration with the **Shodan API** and **CIRCL CVE API** that automatically enriches every scan with external perspective data, live CVE hits on detected service versions, and internet-facing vulnerability telemetry. An optional **AI Intelligence Layer** can now be activated to deliver structured security assessments — powered by OpenAI, Google, or Anthropic — that appear before the raw data, giving SOC analysts and penetration testers an immediate, analyst-grade interpretation of every scan.

Wrapped in a stunning, high-contrast **Cyberpunk ANSI neon interface**, NEXPORT ensures maximum data scannability under critical engagement timelines.

---

## ⚡ Key Features

* 📦 **System-Wide Auto Integration:** Advanced installer deploys a native wrapper granting full execution rights from anywhere in the system.
* 🛠️ **Strict Modular Architecture:** Code logic, UI rendering, Nmap engines, databases, live API clients, and the AI Intelligence Layer are strictly separated across clean, self-documenting `.sh` files with **zero code bloat**.
* 🗄️ **Massive Vulnerability Database:** Deeply mapped catalog linking thousands of ports to risk indices (HIGH/MED/LOW), encryption compliance flags (`[CLR]`), and known real-world exploits.
* 🔍 **Intelligent Live Nmap Parser:** Wraps Nmap into 6 professional deployment modes (Quick, Standard, Full, Stealth, Vuln, Custom) with automated version extraction and lookup integration.
* 🌐 **Live Shodan Integration:** Automatically queries the Shodan API for any public IP after a scan — fetches open ports, service banners, organization data, ISP, geolocation, and live CVEs from Shodan's internet-wide scan perspective.
* 🛡️ **Live CVE Lookup via CIRCL:** Detects service version strings from nmap output and fires lightweight HTTP requests to `cve.circl.lu` to retrieve the top 5 most critical live CVE IDs for each detected version — in real time.
* 🤖 **AI Intelligence Layer *(NEW)*:** Optional AI-driven analysis module that delivers structured security insights — threat overview, critical findings, attack surface analysis, and hardening recommendations — powered by the AI provider of your choice. Dormant by default; activates only when a valid key is present.
* 📊 **Production-Ready Reports:** Instantly exports scan findings to `JSON`, `CSV`, `Markdown (.md)`, or searchable `HTML` for client reporting.
* 🎯 **Gamified Training Engine:** Interactive Quiz Mode trains junior SOC analysts and penetration testers on critical ports and threat scenarios.

---

## 🤖 AI Intelligence Layer — Architecture

`modules/ai_intel.sh` is the optional intelligence layer in NEXPORT. It operates as a **pre-display analysis pipeline** that processes raw scan output before any data is shown to the operator.

### System Protocol

The AI module enforces four hard constraints:

| Constraint | Implementation |
|---|---|
| **Scope Limitation** | The AI is restricted to analysing the input scan data only. It is explicitly instructed not to modify, refactor, or reference the NEXPORT codebase. |
| **Branding Integrity** | Copyright headers, project branding, and attribution are preserved at all times. |
| **Data Integrity** | The model is instructed never to fabricate or hallucinate vulnerabilities. If the data is ambiguous or insufficient to assess a category, it is required to state: *"Insufficient data to assess."* |
| **Optional Activation** | The module remains dormant unless a validated API key is present in `~/.nexport/config`. No key = standard mode, unchanged. |

### Architectural Flow

```
  [ nmap scan complete ]
           │
           ▼
  run_ai_intel_analysis()           ← modules/ai_intel.sh  (FIRST — if key active)
    └── Structured assessment:
        ├── Threat Overview
        ├── Critical Findings
        ├── Attack Surface Analysis
        └── Analyst Recommendations
           │
           ▼
  _summarize_nmap_output()          ← Local database analysis
           │
           ▼
  run_live_threat_intel()           ← modules/api_intel.sh
    ├── Shodan Host API             ← External ports, banners, org, vulns
    └── CIRCL CVE search API        ← Live CVE IDs per detected version
```

**Display order:**
1. **AI Intelligence Insight** *(if key is active)*
2. **Raw Scan Data** — NexPort database analysis, Shodan, CVE reports

**Key design properties:**
- Graceful degradation: if no key is configured or the provider is unreachable, the layer is silently skipped — the standard scan output is completely unaffected.
- The AI receives a truncated, sanitised view of the scan output (up to 3,500 characters) to prevent token overflow.
- API keys are stored with `chmod 600` in `~/.nexport/config` — never echoed to the terminal.
- All three supported providers use separate endpoint and header formats, managed transparently via the `NEXPORT_AI_PROVIDER` identifier stored alongside the key.

---

## 🔑 AI Intelligence Layer Setup

### Interactive Configuration Workflow

Executing `nexport intel set-ai-key <key>` triggers an interactive setup that **does not immediately save the key**. The flow is:

```
Step 1: Provider selection menu
        ┌─────────────────────────────────────────────────────────┐
        │ 1) OpenAI     — GPT-4o / GPT-4-Turbo                   │
        │ 2) Google     — Gemini 1.5 Pro / Flash                  │
        │ 3) Anthropic  — Claude 3.5 Sonnet                       │
        └─────────────────────────────────────────────────────────┘

Step 2: Handshake validation
        A lightweight API call verifies the key against the selected
        provider before any data is written to disk.

Step 3: Contextual storage (only on validation success)
        Both NEXPORT_AI_KEY and NEXPORT_AI_PROVIDER are written to
        ~/.nexport/config with chmod 600 permissions.
```

```bash
# Activate the AI Intelligence Layer (interactive — prompts for provider):
nexport intel set-ai-key YOUR_API_KEY

# Deactivate (reverts to standard mode):
nexport intel clear-ai-key

# View AI layer command reference:
nexport intel ai-help
```

### Supported Providers

| # | Provider | Models Used | API Endpoint |
|---|----------|-------------|-------------|
| 1 | **OpenAI** | GPT-4o / GPT-4-Turbo | `api.openai.com/v1/chat/completions` |
| 2 | **Google** | Gemini 1.5 Pro / Flash | `generativelanguage.googleapis.com/v1beta` |
| 3 | **Anthropic** | Claude 3.5 Sonnet | `api.anthropic.com/v1/messages` |

> The `NEXPORT_AI_PROVIDER` identifier is stored in the config alongside the key. This ensures the correct endpoint format, authentication headers, and request schema are applied automatically on every call — no manual configuration is required after setup.

### 💡 Pro-Tip: The Ultimate Free & Fast Setup (Recommended)

For the absolute best balance between **extreme reasoning power, ultra-fast response, and 100% free access**, we highly recommend activating the AI Layer using **Meta's Llama 3.3 (70B)** via **Groq**.

* **Why this configuration?** Groq's free tier is highly generous, and their LPU architecture generates the entire security summary and streams it into your terminal with near-zero latency (~3-5 seconds max).
* **How to configure it:**
  1. Get a free API key from the [Groq Console](https://console.groq.com/).
  2. Run `nexport intel set-ai-key YOUR_GROQ_API_KEY`.
  3. Select **Option 4 (Custom)** from the interactive menu.
  4. Provide the following values when prompted:
     * **Base URL / Endpoint:** `https://api.groq.com/openai/v1/chat/completions`
     * **Model Name:** `llama-3.3-70b-versatile`

---

## 🌐 Live Threat Intelligence — Shodan Integration

```bash
# Save your Shodan API key (stored securely in ~/.nexport/config)
nexport intel set-key YOUR_SHODAN_API_KEY

# Alternatively, export it for the current session only:
export SHODAN_API_KEY=YOUR_SHODAN_API_KEY

# Remove a saved key:
nexport intel clear-key
```

> Get a free Shodan API key at [https://account.shodan.io](https://account.shodan.io)
> The free tier supports host lookups — sufficient for NexPort's query volume.

---

## 🛡️ Live CVE Lookup — CIRCL.LU

No API key required. CIRCL's CVE API is open and free.

NexPort automatically extracts versioned service strings from nmap banners after any Standard, Full, Stealth, Vuln, or Custom scan (modes that include `-sV`):

```
22/tcp  open  ssh     OpenSSH 8.4p1 Debian
80/tcp  open  http    Apache httpd 2.4.49
3306/tcp open mysql   MySQL 5.7.36-log
```

Each detected `<product> <version>` pair triggers a query to:
```
https://cve.circl.lu/api/search/<product>/<version>
```

The top 5 most critical CVE IDs are extracted from the JSON response and displayed inline in the **Live Threat Intel** section.

> **Tip:** Run scans in **Standard (2)** or higher mode to enable `-sV` version detection, which is required for CIRCL CVE lookups.

---

## ⚙️ System Installation & Global Deployment

```bash
# 1. Clone the official repository:
git clone https://github.com/alpha-bet/nexport.git
cd nexport

# 2. Grant execution permissions:
chmod +x nexport/nexport

# 3. Install system-wide (requires root):
sudo ./nexport/nexport --install

# 4. Run globally from anywhere:
nexport

# 5. (Optional) Set your Shodan API key after installation:
nexport intel set-key YOUR_SHODAN_API_KEY

# 6. (Optional) Activate the AI Intelligence Layer:
nexport intel set-ai-key YOUR_AI_API_KEY

# ❌ Uninstall:
sudo nexport --uninstall
```

---

## 📖 Full Command Reference

### 🔎 Lookup

| Command | Description | Example |
|---------|-------------|---------|
| `-h <port\|name>` | Deep info on a port | `-h 22`, `-h ssh`, `-h 443` |
| `-a`, `--all` | List all ports by category | `-a` |
| `-t`, `--top` | Top 30 most targeted ports | `-t` |

### 🔍 Search & Filter

| Command | Description | Example |
|---------|-------------|---------|
| `-s <keyword>` | Search name, protocol, description, CVE | `-s database` |
| `-c <category>` | Filter by category | `-c web` |
| `-p <proto>` | Filter by protocol | `-p tcp` |
| `-e <enc>` | Filter by encryption | `-e no` |
| `-r <level>` | Filter by risk level | `-r critical` |
| `--cve <CVE-ID>` | Find ports linked to a CVE | `--cve CVE-2020-1938` |

### 📡 Scan & Analyze

| Command | Description |
|---------|-------------|
| `scan <target>` | Live nmap scan + AI insight + NexPort DB analysis + Live Threat Intel |
| `paste` / `summarize` | Paste existing nmap output for AI insight + DB analysis |

**Scan modes available after `scan <target>`:**

| # | Mode | Flags | Notes |
|---|------|-------|-------|
| 1 | Quick | `-T4 --open` | No version detection (~10s) |
| 2 | Standard | `-T4 -sV --open` | Version detection — **enables CVE lookup** (~30s) |
| 3 | Full | `-T4 -sV -p- --open` | All 65535 ports + versions (~5-20min) |
| 4 | Stealth | `-T4 -sS -O -A --open` | Requires root |
| 5 | Vuln | `-T4 -sV --script=vuln --open` | NSE vuln scripts, requires root |
| 6 | Custom | user-defined | Enter your own nmap flags |

### 🌐 Live Threat Intel

| Command | Description |
|---------|-------------|
| `intel set-key <key>` | Save Shodan API key to `~/.nexport/config` |
| `intel clear-key` | Remove saved Shodan API key |
| `intel <public-ip>` | On-demand Shodan + CVE lookup for a specific IP |
| `intel help` | Show intel sub-command reference |

### 🤖 AI Intelligence Layer

| Command | Description |
|---------|-------------|
| `intel set-ai-key <key>` | Interactive provider selection + handshake validation + key storage |
| `intel clear-ai-key` | Remove AI API key (reverts to standard mode) |
| `intel ai-help` | Show AI Intelligence Layer command reference |

**Sample AI Intelligence Layer output:**

```
╔══════════════════════════════════════════════════════════════════════╗
║  ★ AI INTELLIGENCE INSIGHT                                           ║
║  Powered by Anthropic Claude 3.5 Sonnet · Input-scoped analysis only ║
╚══════════════════════════════════════════════════════════════════════╝

  ────────────────────────────────────────────────────────────────────

  1. THREAT OVERVIEW
     The target presents a moderately elevated attack surface. Exposure
     of SSH and an unencrypted HTTP service on port 80 constitutes the
     primary risk. No encrypted web layer (443) was detected.

  2. CRITICAL FINDINGS
     Port 3306 (MySQL) is externally reachable. Database services
     exposed directly to the internet represent a critical misconfiguration.

  3. ATTACK SURFACE ANALYSIS
     An adversary would prioritise the MySQL port for credential brute-force
     and the SSH service for key-based exploitation if the server version
     is unpatched. The HTTP service may expose web application attack vectors.

  4. ANALYST RECOMMENDATIONS
     [1] Immediately restrict port 3306 to localhost or a VPN interface.
     [2] Deploy a TLS certificate and enforce HTTPS on port 443.
     [3] Audit SSH configuration: disable PasswordAuthentication, enforce
         key-based auth, and review authorised_keys for all accounts.

  ────────────── AI analysis complete  ·  Raw data follows ──────────────
```

### ⚙️ System

| Command | Description |
|---------|-------------|
| `-q`, `--quiz` | Interactive port knowledge quiz |
| `--install` | Install to `/usr/local/bin` (requires sudo) |
| `--uninstall` | Remove from system (requires sudo) |
| `--version` | Show version |
| `--help` | Show help |
| `exit` / `quit` | Exit NexPort |

---

## 🗂️ Project Structure

```
nexport/
├── nexport                     # Main entry point & dispatcher
├── lib/
│   ├── colors.sh               # ANSI color variables, badges, risk icons
│   └── ui.sh                   # Banner, dividers, port info printers
├── data/
│   ├── ports_db.sh             # Core port vulnerability database
│   ├── ports_db_ext1.sh        # Extended database — batch 1
│   ├── ports_db_ext2.sh        # Extended database — batch 2
│   └── ports_db_ext3.sh        # Extended database — batch 3
└── modules/
    ├── lookup.sh               # Port lookup and show-all logic
    ├── search.sh               # Keyword search, protocol/risk/enc filters, CVE search
    ├── category.sh             # Category listing and filtering
    ├── top_ports.sh            # Top 30 most targeted ports
    ├── quiz.sh                 # Interactive training quiz
    ├── nmap_scan.sh            # Live nmap scan engine
    ├── summarizer.sh           # Nmap output parser & threat summary
    ├── export.sh               # JSON / CSV / Markdown / HTML export
    ├── api_intel.sh            # Shodan + CIRCL live threat intel
    └── ai_intel.sh             # ★ NEW — Optional AI Intelligence Layer
```

---

## 🔗 API Endpoints Used

| API | Endpoint | Auth | Notes |
|-----|----------|------|-------|
| Shodan Host Lookup | `https://api.shodan.io/shodan/host/{ip}?key={key}` | API Key | Per Shodan plan |
| CIRCL CVE Search | `https://cve.circl.lu/api/search/{product}/{version}` | None | Open, fair use |
| OpenAI Chat | `https://api.openai.com/v1/chat/completions` | Bearer token | GPT-4o |
| Google Gemini | `https://generativelanguage.googleapis.com/v1beta/...` | Query param | Gemini 1.5 Pro |
| Anthropic Messages | `https://api.anthropic.com/v1/messages` | `x-api-key` header | Claude 3.5 Sonnet |

> NexPort uses `curl` with a **12-second timeout** for validation handshakes and a **35-second timeout** for AI analysis calls. All API interactions fail gracefully — a failed or missing key never breaks the scan output.

---

## 🧪 jq vs. Fallback Parsing

NexPort's `api_intel.sh` auto-detects `jq` at runtime:

| Feature | With `jq` | Without `jq` |
|---------|-----------|--------------|
| Shodan org/ISP/country | ✅ Full | ✅ Full |
| Shodan port list | ✅ Full | ✅ Full |
| Shodan banner details | ✅ Full (per-service breakdown) | ⚠️ Basic (regex, limited) |
| Shodan vuln CVE IDs | ✅ Full | ✅ Full |
| CIRCL CVE IDs | ✅ Full | ✅ Full |

Install `jq` for the richest output:
```bash
sudo apt install jq       # Debian / Ubuntu / Kali
sudo dnf install jq       # Fedora / RHEL
sudo pacman -S jq         # Arch Linux
brew install jq           # macOS
```

---

## ⚠️ Operational Notes

* **Version detection is required for CIRCL CVE lookup.** Quick scan mode (`-T4 --open`) does not invoke `-sV`, so no version strings are extracted and the CVE lookup section will advise you accordingly.
* **Shodan only enriches public IPs.** Private RFC1918 addresses (`10.x`, `172.16-31.x`, `192.168.x`), loopback, link-local, and multicast ranges are automatically excluded from external Shodan queries.
* **AI analysis is input-scoped.** The AI module analyses only the scan data passed to it. It is explicitly prohibited from accessing, modifying, or referencing the NEXPORT codebase. If analysis cannot be performed from the available data, it states so explicitly.
* **API keys are stored with `chmod 600`.** The key file at `~/.nexport/config` is restricted to the owner. No key value is ever printed or logged to the terminal.
* **curl is required** for all live API calls. It is pre-installed on all major Linux distributions.
* The existing local scan summary and database lookup pipelines are **completely unmodified** by the AI layer. The AI Intelligence section prepends before them and never interferes with the standard output.

---

## 📜 License

```
                                 Apache License
                           Version 2.0, January 2004
                        http://www.apache.org/licenses/

   TERMS AND CONDITIONS FOR USE, REPRODUCTION, AND DISTRIBUTION

   1. Definitions.

      "License" shall mean the terms and conditions for use, reproduction,
      and distribution as defined by Sections 1 through 9 of this document.

      "Licensor" shall mean the copyright owner or entity authorized by
      the copyright owner that is granting the License.

      "Legal Entity" shall mean the union of the acting entity and all
      other entities that control, are controlled by, or are under common
      control with that entity. For the purposes of this definition,
      "control" means (i) the power, direct or indirect, to cause the
      direction or management of such entity, whether by contract or
      otherwise, or (ii) ownership of fifty percent (50%) or more of the
      outstanding shares, or (iii) beneficial ownership of such entity.

      "You" (or "Your") shall mean an individual or Legal Entity
      exercising permissions granted by this License.

      "Source" form shall mean the preferred form for making modifications,
      including but not limited to software source code, documentation
      source, and configuration files.

      "Object" form shall mean any form resulting from mechanical
      transformation or translation of a Source form, including but
      not limited to compiled object code, generated documentation,
      and conversions to other media types.

      "Work" shall mean the work of authorship, whether in Source or
      Object form, made available under the License, as indicated by a
      copyright notice that is included in or attached to the work
      (an example is provided in the Appendix below).

      "Derivative Works" shall mean any work, whether in Source or Object
      form, that is based on (or derived from) the Work and for which the
      editorial revisions, annotations, elaborations, or other modifications
      represent, as a whole, an original work of authorship. For the purposes
      of this License, Derivative Works shall not include works that remain
      separable from, or merely link (or bind by name) to the interfaces of,
      the Work and Derivative Works thereof.

      "Contribution" shall mean any work of authorship, including
      the original version of the Work and any modifications or additions
      to that Work or Derivative Works thereof, that is intentionally
      submitted to Licensor for inclusion in the Work by the copyright owner
      or by an individual or Legal Entity authorized to submit on behalf of
      the copyright owner. For the purposes of this definition, "submitted"
      means any form of electronic, verbal, or written communication sent
      to the Licensor or its representatives, including but not limited to
      communication on electronic mailing lists, source code control systems,
      and issue tracking systems that are managed by, or on behalf of, the
      Licensor for the purpose of discussing and improving the Work, but
      excluding communication that is conspicuously marked or otherwise
      designated in writing by the copyright owner as "Not a Contribution."

      "Contributor" shall mean Licensor and any individual or Legal Entity
      on behalf of whom a Contribution has been received by Licensor and
      subsequently incorporated within the Work.

   2. Grant of Copyright License. Subject to the terms and conditions of
      this License, each Contributor hereby grants to You a perpetual,
      worldwide, non-exclusive, no-charge, royalty-free, irrevocable
      copyright license to reproduce, prepare Derivative Works of,
      publicly display, publicly perform, sublicense, and distribute the
      Work and such Derivative Works in Source or Object form.

   3. Grant of Patent License. Subject to the terms and conditions of
      this License, each Contributor hereby grants to You a perpetual,
      worldwide, non-exclusive, no-charge, royalty-free, irrevocable
      (except as stated in this section) patent license to make, have made,
      use, offer to sell, sell, import, and otherwise transfer the Work,
      where such license applies only to those patent claims licensable
      by such Contributor that are necessarily infringed by their
      Contribution(s) alone or by combination of their Contribution(s)
      with the Work to which such Contribution(s) was submitted. If You
      institute patent litigation against any entity (including a
      cross-claim or counterclaim in a lawsuit) alleging that the Work
      or a Contribution incorporated within the Work constitutes direct
      or contributory patent infringement, then any patent licenses
      granted to You under this License for that Work shall terminate
      as of the date such litigation is filed.

   4. Redistribution. You may reproduce and distribute copies of the
      Work or Derivative Works thereof in any medium, with or without
      modifications, and in Source or Object form, provided that You
      meet the following conditions:

      (a) You must give any other recipients of the Work or
          Derivative Works a copy of this License; and

      (b) You must cause any modified files to carry prominent notices
          stating that You changed the files; and

      (c) You must retain, in the Source form of any Derivative Works
          that You distribute, all copyright, patent, trademark, and
          attribution notices from the Source form of the Work,
          excluding those notices that do not pertain to any part of
          the Derivative Works; and

      (d) If the Work includes a "NOTICE" text file as part of its
          distribution, then any Derivative Works that You distribute must
          include a readable copy of the attribution notices contained
          within such NOTICE file, excluding those notices that do not
          pertain to any part of the Derivative Works, in at least one
          of the following places: within a NOTICE text file distributed
          as part of the Derivative Works; within the Source form or
          documentation, if provided along with the Derivative Works; or,
          within a display generated by the Derivative Works, if and
          wherever such third-party notices normally appear. The contents
          of the NOTICE file are for informational purposes only and
          do not modify the License. You may add Your own attribution
          notices within Derivative Works that You distribute, alongside
          or as an addendum to the NOTICE text from the Work, provided
          that such additional attribution notices cannot be construed
          as modifying the License.

      You may add Your own copyright statement to Your modifications and
      may provide additional or different license terms and conditions
      for use, reproduction, or distribution of Your modifications, or
      for any such Derivative Works as a whole, provided Your use,
      reproduction, and distribution of the Work otherwise complies with
      the conditions stated in this License.

   5. Submission of Contributions. Unless You explicitly state otherwise,
      any Contribution intentionally submitted for inclusion in the Work
      by You to the Licensor shall be under the terms and conditions of
      this License, without any additional terms or conditions.
      Notwithstanding the above, nothing herein shall supersede or modify
      the terms of any separate license agreement you may have executed
      with Licensor regarding such Contributions.

   6. Trademarks. This License does not grant permission to use the trade
      names, trademarks, service marks, or product names of the Licensor,
      except as required for reasonable and customary use in describing the
      origin of the Work and reproducing the content of the NOTICE file.

   7. Disclaimer of Warranty. Unless required by applicable law or
      agreed to in writing, Licensor provides the Work (and each
      Contributor provides its Contributions) on an "AS IS" BASIS,
      WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
      implied, including, without limitation, any warranties or conditions
      of TITLE, NON-INFRINGEMENT, MERCHANTABILITY, or FITNESS FOR A
      PARTICULAR PURPOSE. You are solely responsible for determining the
      appropriateness of using or redistributing the Work and assume any
      risks associated with Your exercise of permissions under this License.

   8. Limitation of Liability. In no event and under no legal theory,
      whether in tort (including negligence), contract, or otherwise,
      unless required by applicable law (such as deliberate and grossly
      negligent acts) or agreed to in writing, shall any Contributor be
      liable to You for damages, including any direct, indirect, special,
      incidental, or consequential damages of any character arising as a
      result of this License or out of the use or inability to use the
      Work (including but not limited to damages for loss of goodwill,
      work stoppage, computer failure or malfunction, or any and all
      other commercial damages or losses), even if such Contributor
      has been advised of the possibility of such damages.

   9. Accepting Warranty or Additional Liability. While redistributing
      the Work or Derivative Works thereof, You may choose to offer,
      and charge a fee for, acceptance of support, warranty, indemnity,
      or other liability obligations and/or rights consistent with this
      License. However, in accepting such obligations, You may act only
      on Your own behalf and on Your sole responsibility, not on behalf
      of any other Contributor, and only if You agree to indemnify,
      defend, and hold each Contributor harmless for any liability
      incurred by, or claims asserted against, such Contributor by reason
      of your accepting any such warranty or additional liability.

   END OF TERMS AND CONDITIONS

   APPENDIX: How to apply the Apache License to your work.

      To apply the Apache License to your work, attach the following
      boilerplate notice, with the fields enclosed by brackets "[]"
      replaced with your own identifying information. (Don't include
      the brackets!)  The text should be enclosed in the appropriate
      comment syntax for the file format. We also recommend that a
      file or class name and description of purpose be included on the
      same "printed page" as the copyright notice for easier
      identification within third-party archives.

   Copyright [2026] [alpha-bet]

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.

```

---

*NEXPORT — Intelligent Threat Analysis Suite*
*Developed by **alpha-bet** — https://github.com/alpha-bet-404/nexport.git*
