#!/bin/bash
# enable-doh-mikrotik.sh — Enable DoH on MikroTik RouterOS via SSH
# Usage: ssh admin@<router-ip> < enable-doh-mikrotik.sh
#
# Or run directly:
#   sshpass -p 'your-password' ssh admin@10.10.10.1 "$(cat enable-doh-mikrotik.sh)"

# Add static DNS entry for DoH server (avoids chicken-and-egg problem)
/ip dns static add name=cloudflare-dns.com address=1.1.1.1
/ip dns static add name=cloudflare-dns.com address=1.0.0.1

# Set DoH server URL
/ip dns set use-doh-server=https://cloudflare-dns.com/dns-query

# Disable certificate verification (simplest approach)
/ip dns set verify-doh-cert=no

# Remove plain DNS servers
/ip dns set servers=""

# Flush old DNS cache
/ip dns cache flush

# Allow other devices to use this router as DNS (optional, uncomment if needed)
# /ip dns set allow-remote-requests=yes

# Print final config
/ip dns print
