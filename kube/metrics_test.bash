#!/bin/bash
set -e

export LC_CTYPE=C  # Fix for macOS tr bug with byte sequences

API="http://localhost:8083"
ADMIN_AUTH="admin:admin"
HEADERS=(-H "Content-Type: application/json")

# ─────────────────────────────
generate_username_password() {
  local upper=$(LC_CTYPE=C tr -dc 'A-Z' </dev/urandom | head -c3)
  local lower=$(LC_CTYPE=C tr -dc 'a-z' </dev/urandom | head -c3)
  local digits=$(LC_CTYPE=C tr -dc '0-9' </dev/urandom | head -c3)
  local user="${upper}${lower}${digits}"
  local pass="${user}!@#"
  echo "$user|$pass"
}

# ─────────────────────────────
declare -a USERNAMES=()
declare -a PASSWORDS=()
for i in {1..5}; do
  creds=$(generate_username_password)
  uname="${creds%%|*}"
  pass="${creds##*|}"
  USERNAMES+=("$uname")
  PASSWORDS+=("$pass")
done

# ─────────────────────────────
echo "📌 Creating users..."
for i in "${!USERNAMES[@]}"; do
  uname=${USERNAMES[$i]}
  pword=${PASSWORDS[$i]}
  echo "⏳ Creating user $uname..."

  resp=$(curl -s -o /dev/null -w "%{http_code}" -u $ADMIN_AUTH \
    -X POST "$API/api/v1/admin/users" \
    "${HEADERS[@]}" \
    -d "{\"username\": \"$uname\", \"password\": \"$pword\", \"role\": \"USER\"}")

  if [ "$resp" -eq 201 ]; then
    echo "✅ Created $uname"
  elif [ "$resp" -eq 400 ]; then
    echo "⚠️  Already exists or invalid input for $uname"
  else
    echo "❌ Failed to create $uname ($resp)"
  fi
done

# ─────────────────────────────
echo "🔐 Authenticating users..."
declare -a TOKENS=()
for i in "${!USERNAMES[@]}"; do
  uname=${USERNAMES[$i]}
  pword=${PASSWORDS[$i]}
  auth=$(echo -n "$uname:$pword" | base64)
  TOKENS+=("Basic $auth")
done

# ─────────────────────────────
echo "🏦 Creating accounts for first 3 users..."
for i in 0 1 2; do
  uname=${USERNAMES[$i]}
  token=${TOKENS[$i]}

  curl -s -X POST "$API/api/v1/accounts" \
    -H "Authorization: $token" \
    "${HEADERS[@]}" \
    > /dev/null && echo "✅ Account created for $uname"
done

echo "✅ Script finished"
