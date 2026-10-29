#!/usr/bin/env bash

set -uo pipefail

PASS=0
FAIL=0

check() {
    local desc="$1"
    local expected="$2"
    local actual="$3"

    if [[ "$actual" == "$expected" ]]; then
        echo "[OK] $desc"
        ((PASS+=1))
    else
        echo "[FAIL] $desc: ожидалось '$expected', получено '$actual'"
        ((FAIL+=1))
    fi
}

echo "=== Аудит сервера $(hostname) ==="

echo "[1] Проверка SSH"
check "Вход root запрещён" "no" \
    "$(sudo sshd -T | awk '$1=="permitrootlogin"{print $2}')"
check "Парольный вход отключён" "no" \
    "$(sudo sshd -T | awk '$1=="passwordauthentication"{print $2}')"
check "Порт SSH" "2222" \
    "$(sudo sshd -T | awk '$1=="port"{print $2}')"
check "MaxAuthTries" "3" \
    "$(sudo sshd -T | awk '$1=="maxauthtries"{print $2}')"

echo "[2] Проверка UFW"
check "UFW активен" "active" \
    "$(sudo ufw status | awk '/^Status:/{print $2}')"
check "Входящие соединения запрещены" "deny" \
    "$(sudo ufw status verbose | sed -n 's/^Default: \([^ ]*\) (incoming).*$/\1/p')"

echo "[3] Пользователи"
awk -F: '$3>=1000 && $3<65534 {
    printf "Пользователь: %s, UID: %s\n", $1, $3
}' /etc/passwd

echo "[5] Контейнеризация"

check "Docker активен" "active" \
    "$(systemctl is-active docker 2>/dev/null || true)"

check "PostgreSQL healthy" "healthy" \
    "$(docker inspect -f '{{.State.Health.Status}}' app-db-1 2>/dev/null || true)"

UNSAFE_PORTS="$(
    sudo ss -tlnH | awk '
    {
        address=$4
        if (address ~ /:(5000|5432)$/ &&
            address !~ /^127\.0\.0\.1:/) {
            print address
        }
    }'
)"

if [[ -z "$UNSAFE_PORTS" ]]; then
    PORT_STATUS="safe"
else
    PORT_STATUS="unsafe"
fi

check "Порты 5000 и 5432 защищены" "safe" "$PORT_STATUS"

check "Права файла .env" "600" \
    "$(stat -c '%a' /home/devops/app/.env 2>/dev/null || true)"

echo "=========================="
echo "Проверок пройдено: $PASS"
echo "Ошибок: $FAIL"

if [[ "$FAIL" -eq 0 ]]; then
    echo "Аудит пройден успешно"
    exit 0
else
    echo "Аудит выявил нарушения"
    exit 1
fi
