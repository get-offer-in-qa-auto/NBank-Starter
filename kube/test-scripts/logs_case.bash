#!/bin/bash
set -e

echo "🛠 Создаем пользователя как админ..."
curl -s -X POST http://localhost:4111/api/v1/admin/users \
  -H "Content-Type: application/json" \
  -H "Authorization: Basic YWRtaW46YWRtaW4=" \
  -d '{
    "username": "Kate19981",
    "password": "Kate19981№%#",
    "role": "USER"
  }' || true

echo "🏦 Создаем аккаунт..."
curl -X POST http://localhost:4111/api/v1/accounts \
  -H "Authorization: Basic S2F0ZTE5OTgxOkthdGUxOTk4MeKEliUj" \
  -H "Content-Type: application/json"

echo "📋 Проверяем список аккаунтов..."
curl -X GET http://localhost:4111/api/v1/customer/accounts \
  -H "Authorization: Basic S2F0ZTE5OTgxOkthdGUxOTk4MeKEliUj" \
  -H "Content-Type: application/json"

echo "💸 Пробуем внести депозит более 200000..."
curl -X POST http://localhost:4111/api/v1/accounts/deposit \
  -H "Authorization: Basic S2F0ZTE5OTgxOkthdGUxOTk4MeKEliUj" \
  -H "Content-Type: application/json" \
  -d '{
    "id": 1,
    "balance": 200001
  }'
