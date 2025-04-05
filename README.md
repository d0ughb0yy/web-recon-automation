# Automated Subdomain Recon Script
## About
This script is a personal project and my way of learning bash scripting.
The script is a Bash automation tool designed for bug bounty hunters and security researchers to streamline reconnaissance workflows. It leverages popular tools like subfinder, httpx, katana, and xnlinkfinder to enumerate subdomains, probe live hosts, crawl websites, and extract JavaScript links. The script includes rate limiting to avoid WAF triggers, fetches subdomains from crt.sh (parsed via HTML), and provides a modular flag-based execution system. Results are organized in a timestamped directory, with temporary files cleaned up post-execution.

## Requirements
The script depends on the following tools and utilities, which must be installed and accessible in your PATH:

**Subfinder**
```
https://github.com/projectdiscovery/subfinder
```
**HTTPX**
```
https://github.com/projectdiscovery/httpx
```
**Katana**
```
https://github.com/projectdiscovery/katana
```
**xnLinkFinder**
```
https://github.com/xnl-h4ck3r/xnlinkfinder
```
**Anew**
```
https://github.com/tomnomnom/anew
```
### Warning: Mind the Spelling
**Tool Name Sensitivity:** 
The script assumes tools are installed or aliased with specific names (e.g., subfinder, httpx, katana, xnlinkfinder). Variations in spelling or capitalization (e.g., xnLinkFinder vs. xnlinkfinder) may cause the script to fail if they don’t match your system’s configuration. Verify tool names with command -v <tool> or type <tool> in your shell and ensure they align with the script’s expectations. For example, if katana is an alias, it must be defined (e.g., alias katana='docker run ...') and sourced in your shell environment. It is easy to find in the script where each tool is located and correct it according to your system.

## Use Cases
The script supports various reconnaissance scenarios through its flag-based system.
Below are common use cases:

### Full Reconnaissance Workflow
```
./recon.sh target.com --all
```
Runs the entire pipeline:
1. Enumerates subdomains with Subfinder and crt.sh (HTML parsing, wildcard removal).
2. Probes live hosts with httpx (rate-limited to 10 req/s by default).
3. Crawls live subdomains with Katana (rate-limited to 10 req/s by default) and extracts .js files.
P4. rocesses .js files with xnlinkfinder.
Output: Combined subdomains, live subdomains, crawl results, and JS links in a timestamped directory.

### Subdomain Enumeration Only
```
./recon.sh target.com --sub
```
Gathers subdomains using Subfinder and crt.sh, combining them into a deduplicated list. The crt.sh temporary file is cleaned up afterward.
Output: subfinder_subdomains.txt, subdomains.txt (combined).

### Basic HTTP Probing
```
./recon.sh target.com --probe
```
Probes subdomains from subdomains.txt with httpx (rate-limited to 10 req/s by default), filtering out 404 responses.
Output: live_subdomains.txt.
*Prerequisite: Requires subdomains.txt from a prior --sub run.*

### Detailed HTTP Scanning
```
./recon.sh target.com --probe --scan
```
Runs the basic httpx probe plus a detailed scan with status codes, locations, CDN info, server details, IPs, and titles.
Output: live_subdomains.txt, httpx_scan.txt.
*Prerequisite: Requires subdomains.txt and the --probe flag.*

### Web Crawling and JS Link Extraction
```
./recon.sh target.com --spider
```
Crawls live subdomains with Katana (rate-limited to 10 req/s by default), extracts .js files, and processes them with xnlinkfinder.
Output: katana_output.txt, js_files.txt, xnlinkfinder_output.txt.
*Prerequisite: Requires live_subdomains.txt from a prior --probe run.*

### Custom Rate Limiting
```
./recon.sh target.com --all --rl 5
```
Runs the full pipeline with a custom rate limit of 5 requests per second for httpx and Katana, adjustable via the --rl flag.
Output: Same as Use Case 1, with rate limiting applied.

### Combined Example
```
./recon.sh target.com --sub --probe --scan --spider --rl 3
```
Executes subdomain enumeration, basic probing, detailed scanning, and crawling/link extraction in sequence with a 3 req/s rate limit.
Output: All relevant files in a timestamped directory.
