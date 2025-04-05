#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${RED}"
cat << "EOF"
   ___       __                  __        __  __                         __   ____
  / _ |__ __/ /____  __ _  ___ _/ /____   / /_/ /  ___   _    _____  ____/ /__/ / /
 / __ / // / __/ _ \/  ' \/ _ `/ __/ -_) / __/ _ \/ -_) | |/|/ / _ \/ __/ / _  /_/ 
/_/ |_\_,_/\__/\___/_/_/_/\_,_/\__/\__/  \__/_//_/\__/  |__,__/\___/_/ /_/\_,_(_)

EOF
echo -e "${GREEN}       Basic Recon Script by d0ughb0y${NC}"
echo -e "${RED}====================================================${NC}"
sleep 1

# Function to fetch and parse subdomains from crt.sh
fetch_crtsh_subdomains() {
    local domain=$1
    echo -e "${GREEN}[+] Fetching subdomains from crt.sh${NC}"
    curl -s "https://crt.sh/?q=${domain}&output=json" | \
    grep -o '"name_value":"[^"]*"' | \
    sed 's/"name_value":"//' | sed 's/"$//' | \
    sed 's/\*\.//g' | \
    sort -u > crtsh_subdomains.txt
    echo -e "${GREEN}[+] Found $(wc -l < crtsh_subdomains.txt) unique subdomains from crt.sh${NC}"
}

# Function to display usage
usage() {
    echo "Usage: $0 <target.com> [--sub] [--probe] [--spider] [--all]"
    echo "  --sub    : Run subfinder only"
    echo "  --probe  : Run httpx only"
    echo "  --scan   : Run a comprehensive httpx scan (requires --probe)"
    echo "  --spider : Run katana and xnlinkfinder only"
    echo "  --all    : Run all tools in sequence"
    echo "  --rl     : Set custom rate limit in req/s for httpx and katana (default: 10)"
    exit 1
}

# Check if target domain is provided
if [ -z "$1" ]; then
    usage
fi

# Set target domain
TARGET=$1
TIMESTAMP=$(date +%Y%m%d)
OUTPUT_DIR="recon_${TARGET}_${TIMESTAMP}"

# Flags
RUN_SUB=false
RUN_PROBE=false
RUN_SPIDER=false
RUN_SCAN=false
RATE_LIMIT=10  # Default rate limit

# Parse command line arguments
shift # Remove target from args
while [ "$#" -gt 0 ]; do
    case "$1" in
        --sub) RUN_SUB=true ;;
        --probe) RUN_PROBE=true ;;
        --scan) RUN_SCAN=true ;;
        --spider) RUN_SPIDER=true ;;
        --all) RUN_SUB=true; RUN_PROBE=true; RUN_SPIDER=true ;;
        --rl)
            shift
            if [[ "$1" =~ ^[0-9]+$ && "$1" -gt 0 ]]; then
                RATE_LIMIT=$1
            else
                echo "Error: --rl requires a positive integer (e.g., --rl 5)"
                usage
            fi
            ;;
        *) usage ;;
    esac
    shift
done

# If no flags specified, show usage
if [ "$RUN_SUB" = false ] && [ "$RUN_PROBE" = false ] && [ "$RUN_SPIDER" = false ]; then
    usage
fi

# Check if --scan is used without --probe
if [ "$RUN_SCAN" = true ] && [ "$RUN_PROBE" = false ]; then
    echo "Error: --scan flag requires --probe flag"
    usage
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"
cd "$OUTPUT_DIR" || exit

echo -e "${GREEN}[+] Starting reconnaissance for $TARGET${NC}"

# Subdomain enumeration with subfinder and crt.sh
if [ "$RUN_SUB" = true ]; then
    echo -e "${GREEN}[+] Running subfinder${NC}"
    subfinder -d "$TARGET" -o subfinder_subdomains.txt
    
    fetch_crtsh_subdomains "$TARGET"
    
    # Combine and deduplicate subdomains
    echo -e "${GREEN}[+] Combining and deduplicating subdomains${NC}"
    cat subfinder_subdomains.txt crtsh_subdomains.txt | sort -u > subdomains.txt
    echo -e "${GREEN}[+] Total unique subdomains: $(wc -l < subdomains.txt)${NC}"
fi

# Probe live hosts with httpx
if [ "$RUN_PROBE" = true ]; then
    if [ -f subdomains.txt ]; then
        echo -e "${GREEN}[+] Running httpx with rate limit of $RATE_LIMIT req/s${NC}"
        httpx -l subdomains.txt -fc 404 -o live_subdomains.txt -rl "$RATE_LIMIT"
        
        # Additional scan if --scan flag is present
        if [ "$RUN_SCAN" = true ]; then
            echo -e "${GREEN}[+] Running httpx detailed scan${NC}"
            httpx -l subdomains.txt -fc 404 -sc -location -cdn -server -ip -title -o httpx_scan.txt -rl "$RATE_LIMIT"
        fi
    else
        echo "Error: subdomains.txt not found. Run with --sub first."
    fi
fi

# Web crawling with katana and xnlinkfinder
if [ "$RUN_SPIDER" = true ]; then
    if [ -f live_subdomains.txt ]; then
        echo -e "${GREEN}[+] Running katana with rate limit of $RATE_LIMIT req/s${NC}"
        katana -u live_subdomains.txt -jc -kf all -r "$RATE_LIMIT" | anew katana_output.txt

        echo -e "${GREEN}[+] Processing JavaScript files${NC}"
        grep ".js" katana_output.txt > js_files.txt

        if [ -s js_files.txt ]; then
            echo -e "${GREEN}[+] Running xnlinkfinder on JS files${NC}"
            xnLinkFinder -i js_files.txt -sf "$TARGET" --origin -o xnlinkfinder_output.txt
        else
            echo "No .js files found in katana output"
        fi
    else
        echo "Error: live_subdomains.txt not found. Run with --probe first."
    fi
fi

echo -e "${GREEN}[+] Reconnaissance complete!${NC}"
echo -e "${RED}Results saved in: $OUTPUT_DIR${NC}"
[ -f subfinder_subdomains.txt ] && echo "Subfinder subdomains: subfinder_subdomains.txt"
[ -f subdomains.txt ] && echo "Combined subdomains: subdomains.txt"
[ -f live_subdomains.txt ] && echo "Live subdomains: live_subdomains.txt"
[ -f httpx_scan.txt ] && echo "Detailed httpx scan: httpx_scan.txt"
[ -f katana_output.txt ] && echo "Katana output: katana_output.txt"
[ -f js_files.txt ] && echo "JS files: js_files.txt"
[ -f xnlinkfinder_output.txt ] && echo "xnlinkfinder output: xnlinkfinder_output.txt"

# Clean up crtsh_subdomains.txt if it exists
if [ -f crtsh_subdomains.txt ]; then
    rm crtsh_subdomains.txt
fi