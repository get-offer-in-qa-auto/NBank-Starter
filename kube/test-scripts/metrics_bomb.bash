#!/bin/bash
set -e

export LC_CTYPE=C  # Fix tr on macOS

API="http://localhost:8083"
ADMIN_AUTH="admin:admin"
HEADERS=(-H "Content-Type: application/json")

# ─────────────────────────────
generate_username_password() {
  local upper=$(tr -dc 'A-Z' </dev/urandom | head -c3)
  local lower=$(tr -dc 'a-z' </dev/urandom | head -c3)
  local digits=$(tr -dc '0-9' </dev/urandom | head -c3)
  local user="${upper}${lower}${digits}"
  local pass="${user}!@#"
  echo "$user|$pass"
}

# ─────────────────────────────
user_count=$(( RANDOM % 100 + 1 ))
echo "📌 Generating $user_count users..."

declare -a USERNAMES=()
declare -a PASSWORDS=()
declare -a TOKENS=()

for ((i=1; i<=user_count; i++)); do
  creds=$(generate_username_password)
  uname="${creds%%|*}"
  pass="${creds##*|}"

  # create user
  resp=$(curl -s -o /dev/null -w "%{http_code}" -u $ADMIN_AUTH \
    -X POST "$API/api/v1/admin/users" \
    "${HEADERS[@]}" \
    -d "{\"username\": \"$uname\", \"password\": \"$pass\", \"role\": \"USER\"}")

  if [ "$resp" -eq 201 ]; then
    echo "✅ Created $uname"
    USERNAMES+=("$uname")
    PASSWORDS+=("$pass")
    auth=$(echo -n "$uname:$pass" | base64)
    TOKENS+=("Basic $auth")
  else
    echo "⚠️  Skipped $uname (code $resp)"
  fi
done

# ─────────────────────────────
echo "🏦 Creating accounts..."

for i in "${!USERNAMES[@]}"; do
  uname=${USERNAMES[$i]}
  token=${TOKENS[$i]}

  acc_count=$(( RANDOM % 1000 + 1 ))
  echo "🔁 Creating $acc_count accounts for $uname..."

  for ((j=1; j<=acc_count; j++)); do
    curl -s -X POST "$API/api/v1/accounts" \
      -H "Authorization: $token" \
      "${HEADERS[@]}" > /dev/null
  done

  echo "✅ Done for $uname"
done

echo "🎉 Load generation complete!"
