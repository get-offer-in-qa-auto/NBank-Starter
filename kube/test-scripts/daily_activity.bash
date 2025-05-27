#!/bin/bash

API_URL="http://localhost:4111/api/v1"
ADMIN_AUTH="admin:admin"
ADMIN_AUTH_HEADER="Authorization: Basic $(echo -n $ADMIN_AUTH | base64)"

SUCCESS_COUNT=0
FAIL_COUNT=0

declare -A USER_ACCOUNTS  # Ассоциативный массив: username → список accountId

log_success() {
  echo "✅ SUCCESS: $1"
  SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
}

log_failure() {
  echo "❌ FAILURE: $1"
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

generate_random_string() {
  LC_ALL=C tr -dc 'a-zA-Z0-9' </dev/urandom | head -c 8
}

# --- 1) Создание случайного количества пользователей ---
USER_COUNT=$(( RANDOM % 10 + 1 ))
if (( RANDOM % 10 == 0 )); then
  USER_COUNT=$(( RANDOM % 61 + 40 ))  # выброс
fi

echo "👤 Creating $USER_COUNT users..."

declare -a USER_LIST

for (( i=0; i<$USER_COUNT; i++ )); do
  USERNAME="user$(generate_random_string)"
  PASSWORD="Pass$(generate_random_string)!"

  RESPONSE=$(curl -s -w "%{http_code}" -o /tmp/response_user.json -X POST "$API_URL/admin/users" \
    -H "Content-Type: application/json" \
    -H "$ADMIN_AUTH_HEADER" \
    -d "{\"username\": \"$USERNAME\", \"password\": \"$PASSWORD\", \"role\": \"USER\"}")

  if [ "$RESPONSE" == "201" ]; then
    log_success "Created user $USERNAME"
    USER_LIST+=("$USERNAME:$PASSWORD")
  else
    log_failure "Failed to create user $USERNAME (HTTP $RESPONSE)"
  fi
done

echo "⏸ Pause 1 minute before next phase..."
sleep 60

# --- 2) Создание аккаунтов для пользователей ---
if [ ${#USER_LIST[@]} -gt 0 ]; then
  for USER in "${USER_LIST[@]}"; do
    IFS=":" read -r USERNAME PASSWORD <<< "$USER"
    AUTH_HEADER="Authorization: Basic $(echo -n "$USERNAME:$PASSWORD" | base64)"

    ACCOUNT_COUNT=$(( RANDOM % 4 + 1 ))
    for (( j=0; j<$ACCOUNT_COUNT; j++ )); do
      RESPONSE_JSON=$(curl -s -X POST "$API_URL/accounts" \
        -H "Content-Type: application/json" \
        -H "$AUTH_HEADER")

      ACCOUNT_ID=$(echo "$RESPONSE_JSON" | jq -r .id)
      if [ "$ACCOUNT_ID" != "null" ]; then
        log_success "$USERNAME created account $ACCOUNT_ID"
        USER_ACCOUNTS["$USERNAME"]+="$ACCOUNT_ID "
      else
        log_failure "$USERNAME failed to create account"
      fi
    done
  done
fi

echo "⏸ Pause 2 minutes before transfers..."
sleep 120

# --- 3) Минимум 50 переводов ---
if [ ${#USER_LIST[@]} -gt 1 ]; then
  echo "💸 Performing minimum 50 transfers..."

  for (( t=0; t<50; t++ )); do
    SENDER_IDX=$(( RANDOM % ${#USER_LIST[@]} ))
    RECEIVER_IDX=$(( RANDOM % ${#USER_LIST[@]} ))
    while [ "$SENDER_IDX" -eq "$RECEIVER_IDX" ]; do
      RECEIVER_IDX=$(( RANDOM % ${#USER_LIST[@]} ))
    done

    SENDER="${USER_LIST[$SENDER_IDX]}"
    RECEIVER="${USER_LIST[$RECEIVER_IDX]}"
    IFS=":" read -r SENDER_NAME SENDER_PASS <<< "$SENDER"
    IFS=":" read -r RECEIVER_NAME RECEIVER_PASS <<< "$RECEIVER"

    SENDER_ACCOUNTS=(${USER_ACCOUNTS["$SENDER_NAME"]})
    RECEIVER_ACCOUNTS=(${USER_ACCOUNTS["$RECEIVER_NAME"]})

    if [ ${#SENDER_ACCOUNTS[@]} -eq 0 ] || [ ${#RECEIVER_ACCOUNTS[@]} -eq 0 ]; then
      log_failure "Skipping transfer: no accounts for $SENDER_NAME or $RECEIVER_NAME"
      continue
    fi

    SENDER_ACCOUNT_ID=${SENDER_ACCOUNTS[0]}
    RECEIVER_ACCOUNT_ID=${RECEIVER_ACCOUNTS[0]}

    AUTH_HEADER="Authorization: Basic $(echo -n "$SENDER_NAME:$SENDER_PASS" | base64)"

    # 💰 Пополняем счёт перед переводом, чтобы было с чего списывать
    curl -s -X POST "$API_URL/accounts/deposit" \
      -H "Content-Type: application/json" \
      -H "$AUTH_HEADER" \
      -d "{\"id\": $SENDER_ACCOUNT_ID, \"balance\": 100}" > /dev/null

    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$API_URL/accounts/transfer" \
      -H "Content-Type: application/json" \
      -H "$AUTH_HEADER" \
      -d "{\"senderAccountId\": $SENDER_ACCOUNT_ID, \"receiverAccountId\": $RECEIVER_ACCOUNT_ID, \"amount\": 50}")

    if [ "$RESPONSE" == "200" ]; then
      log_success "$SENDER_NAME transferred to $RECEIVER_NAME"
    else
      log_failure "$SENDER_NAME failed transfer to $RECEIVER_NAME (HTTP $RESPONSE)"
    fi
  done
fi

sleep 10

# --- 4) Пополнения счетов ---
if [ ${#USER_LIST[@]} -gt 0 ]; then
  for USER in "${USER_LIST[@]}"; do
    IFS=":" read -r USERNAME PASSWORD <<< "$USER"
    AUTH_HEADER="Authorization: Basic $(echo -n "$USERNAME:$PASSWORD" | base64)"

    ACCOUNTS=(${USER_ACCOUNTS["$USERNAME"]})
    if [ ${#ACCOUNTS[@]} -eq 0 ]; then
      continue
    fi

    ACCOUNT_ID=${ACCOUNTS[0]}

    DEPOSIT_COUNT=$(( RANDOM % 30 + 1 ))
    for (( d=0; d<$DEPOSIT_COUNT; d++ )); do
      RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$API_URL/accounts/deposit" \
        -H "Content-Type: application/json" \
        -H "$AUTH_HEADER" \
        -d "{\"id\": $ACCOUNT_ID, \"balance\": 100}")

      if [ "$RESPONSE" == "200" ]; then
        log_success "$USERNAME deposited money"
      else
        log_failure "$USERNAME failed deposit (HTTP $RESPONSE)"
      fi
    done
  done
fi

# --- Final Report ---
echo "-----------------------------------"
echo "✅ Total successful requests: $SUCCESS_COUNT"
echo "❌ Total failed requests: $FAIL_COUNT"
