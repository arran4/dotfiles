#!/bin/bash
set -e

fetch_ipv4() {
  if command -v curl >/dev/null 2>&1; then
    curl -fsS4 https://ipv4.icanhazip.com
  elif command -v wget >/dev/null 2>&1; then
    wget -qO- --inet4-only https://ipv4.icanhazip.com
  else
    dig +short -4 myip.opendns.com @resolver1.opendns.com
  fi
}

fetch_ipv6() {
  if command -v curl >/dev/null 2>&1; then
    curl -fsS6 --noproxy '*' https://ipv6.icanhazip.com
  elif command -v wget >/dev/null 2>&1; then
    wget -qO- --inet6-only https://ipv6.icanhazip.com
  else
    dig +short -6 myip.opendns.com @resolver1.opendns.com
  fi
}

printf 'IPv4: %s\n' "$(fetch_ipv4 2>/dev/null || echo 'Unavailable')"
printf 'IPv6: %s\n' "$(fetch_ipv6 2>/dev/null || echo 'Unavailable')"
