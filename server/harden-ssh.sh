#!/usr/bin/env bash
# ============================================================
# SSH Hardening — run ONLY after confirming key-based login works
# for mithiles.joshi. Running this locks out root SSH permanently.
# ============================================================
set -euo pipefail

SSHD_CONFIG="/etc/ssh/sshd_config"

echo "==> Hardening SSH..."

# Disable root login
sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' "$SSHD_CONFIG"
# Disable password auth (key only)
sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' "$SSHD_CONFIG"
# Disable empty passwords
sed -i 's/^#*PermitEmptyPasswords.*/PermitEmptyPasswords no/' "$SSHD_CONFIG"
# Allow only specific user
grep -q "^AllowUsers" "$SSHD_CONFIG" \
  || echo "AllowUsers mithiles.joshi" >> "$SSHD_CONFIG"

sshd -t && systemctl restart ssh
echo "    Root login disabled."
echo "    Password auth disabled."
echo "    Only 'mithiles.joshi' with SSH key can log in."
echo ""
echo "✅ SSH hardened."
