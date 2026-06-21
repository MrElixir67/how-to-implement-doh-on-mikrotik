# How to Implement DNS over HTTPS (DoH) on MikroTik RouterOS

A complete, step-by-step guide to enable **DNS over HTTPS (DoH)** on your MikroTik router using Cloudflare's 1.1.1.1 resolver. This encrypts your DNS queries so your ISP cannot see which domains you visit.

## Why DoH?

Standard DNS queries are sent in plaintext — your ISP, any network intermediary, or even someone on the same WiFi can see every domain you request. DNS over HTTPS wraps these queries in TLS-encrypted HTTPS traffic, making them indistinguishable from regular web browsing.

```
Without DoH:
Device -> MikroTik -> ISP DNS (plaintext) -> Internet
                          ^ your ISP sees every domain

With DoH:
Device -> MikroTik -> DoH Cloudflare (HTTPS encrypted) -> Internet
                          ^ your ISP only sees "connection to 1.1.1.1"
```

## Prerequisites

- A MikroTik router (hEX, RB750Gr3, or any RouterOS 7.x device)
- SSH access to the router (Winbox also works)
- RouterOS version 7.x (DoH was introduced in RouterOS 7)

## Step-by-Step Guide

### Step 1: Verify Your RouterOS Version

SSH into your MikroTik and check the version:

```
[admin@MikroTik] > /system resource print
```

Look for the `version` field — it should be 7.x or later. If you're on RouterOS 6, DoH is not supported.

### Step 2: Add a Static DNS Entry for the DoH Server

Before enabling DoH, you need to add a static DNS record so the router can resolve the DoH server's hostname. Without this, a chicken-and-egg problem occurs: the router needs DNS to find the DoH server, but DoH is supposed to provide DNS.

```
[admin@MikroTik] > /ip dns static add name=cloudflare-dns.com address=1.1.1.1
[admin@MikroTik] > /ip dns static add name=cloudflare-dns.com address=1.0.0.1
```

This resolves `cloudflare-dns.com` to Cloudflare's own IP addresses. The second entry provides a fallback.

Verify the entries were created:

```
[admin@MikroTik] > /ip dns static print where name=cloudflare-dns.com
```

Expected output:

```
Columns: NAME, ADDRESS, TTL
#  NAME                ADDRESS  TTL
0  cloudflare-dns.com  1.1.1.1  1d
1  cloudflare-dns.com  1.0.0.1  1d
```

### Step 3: Set the DoH Server URL

Configure the DoH endpoint. Cloudflare provides a free, privacy-focused DNS resolver at `https://cloudflare-dns.com/dns-query`:

```
[admin@MikroTik] > /ip dns set use-doh-server=https://cloudflare-dns.com/dns-query
```

### Step 4: Disable Certificate Verification (or Set Up CA Certs)

For most setups, disabling certificate verification is the simplest approach:

```
[admin@MikroTik] > /ip dns set verify-doh-cert=no
```

If you prefer proper certificate validation, import CA certificates onto your router. This requires copying the CA bundle to the router — a more advanced setup beyond this guide.

### Step 5: Remove Plain DNS Servers and Flush Cache

Since DoH is now handling all DNS resolution, you can remove the plain UDP/TCP DNS servers and clear the old cache:

```
[admin@MikroTik] > /ip dns set servers=""
[admin@MikroTik] > /ip dns cache flush
```

### Step 6: (Optional) Allow Remote DNS Requests

If you have other devices on your network (like Pi-Hole, other servers, or a secondary router) that use this MikroTik as their DNS resolver, enable remote requests:

```
[admin@MikroTik] > /ip dns set allow-remote-requests=yes
```

### Step 7: Verify Configuration

Check that all settings are applied correctly:

```
[admin@MikroTik] > /ip dns print
```

Expected output (key fields):

```
servers:
use-doh-server: https://cloudflare-dns.com/dns-query
verify-doh-cert: no
allow-remote-requests: yes (or no, depending on your setup)
```

Test that DNS resolution works:

```
[admin@MikroTik] > ping google.com count=2
```

Expected output shows successful ping with resolved IP addresses.

### Step 8: Verify DoH Is Actually Working (External Test)

Visit the following URL from any device on your network to confirm DoH is active:

```
https://one.one.one.one/help/
```

This Cloudflare diagnostic page will show:

| Test | Expected Result |
|------|----------------|
| Connected to 1.1.1.1 | Yes |
| Using DNS over HTTPS (DoH) | Yes |
| Using DNS over TLS (DoT) | No |
| AS Name | Cloudflare, Inc. |
| Cloudflare Data Center | CGK (Jakarta) or nearest location |

## Complete Configuration Reference

If you want to apply everything at once, here is the full set of commands:

```routeros
# Add static DNS entry for DoH server
/ip dns static add name=cloudflare-dns.com address=1.1.1.1
/ip dns static add name=cloudflare-dns.com address=1.0.0.1

# Set DoH server
/ip dns set use-doh-server=https://cloudflare-dns.com/dns-query

# Disable cert verification (simplest approach)
/ip dns set verify-doh-cert=no

# Remove plain DNS servers and flush cache
/ip dns set servers=""
/ip dns cache flush

# Allow other devices to use this router as DNS (optional)
/ip dns set allow-remote-requests=yes
```

## Verifying from Another Machine

From a Linux host or server, you can verify DoH is working through your MikroTik:

```bash
# Query the MikroTik directly
dig google.com @10.10.10.1

# Query a service that resolves through your MikroTik
# (from a device using the MikroTik as its DNS)
dig google.com
```

## How It Works (DNS Flow)

```
Your Device           MikroTik Router          Cloudflare 1.1.1.1
    |                      |                          |
    |--- DNS query ------->|                          |
    |                      |--- DoH (HTTPS) --------->|
    |                      |   ?name=google.com       |
    |                      |     🔒 Encrypted         |
    |                      |<-- DNS response ---------|
    |<-- DNS response -----|       (encrypted)        |
```

Your ISP sees TLS-encrypted traffic to `1.1.1.1:443` — it cannot inspect the DNS queries inside.

## Troubleshooting

### DNS Resolution Fails After Configuring DoH

**Cause:** The router cannot reach `cloudflare-dns.com`. The static DNS entry may not be working.

**Fix:** Verify the static entry:
```
/ip dns static print where name=cloudflare-dns.com
```
If missing, re-add it. Also verify internet connectivity:
```
/ping 1.1.1.1 count=3
```

### "Certificate verification failed" Errors

**Cause:** The router does not have trusted CA certificates.

**Fix:** Either:
- Set `verify-doh-cert=no` (simpler, covered in Step 4)
- Import CA certificates to the router

### DoH Not Working on Older RouterOS

**Cause:** DoH requires RouterOS 7.x.

**Fix:** Upgrade your RouterOS:
```
/system package update check-for-updates
/system package update install
```

## Other DoH Providers

Cloudflare is used in this guide, but you can use any DoH-compatible resolver:

| Provider | DoH URL |
|----------|---------|
| Cloudflare | `https://cloudflare-dns.com/dns-query` |
| Google | `https://dns.google/dns-query` |
| Quad9 | `https://dns.quad9.net/dns-query` |
| OpenDNS | `https://doh.opendns.com/dns-query` |

Replace the `use-doh-server` value with any of the above URLs.

## Rollback

If something goes wrong and you want to revert to plain DNS:

```routeros
/ip dns set use-doh-server="" servers=8.8.8.8,1.1.1.1 allow-remote-requests=yes
/ip dns cache flush
```

## License

MIT
