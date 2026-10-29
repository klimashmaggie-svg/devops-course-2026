
#!/usr/bin/env bash
# Практическая работа № 6
# Автоматический деплой статического сайта
# Использование: ./scripts/deploy.sh [--dry-run]

set -euo pipefail

# Настройки сервера
REMOTE="devops"
REMOTE_DIR="/var/www/devops-site"
SITE_URL="https://devops.local"
SERVER_IP="192.168.56.2"
CA_CERT="${HOME}/devops.crt"

# Пути проекта
ROOT="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
LOCAL_DIR="${ROOT}/site/"
RSYNC_BIN="$(brew --prefix rsync)/bin/rsync"

# Проверка аргументов
DRY_RUN=false

if [[ $# -eq 1 && "$1" == "--dry-run" ]]; then
    DRY_RUN=true
elif [[ $# -ne 0 ]]; then
    echo "Ошибка: допустим только аргумент --dry-run" >&2
    exit 1
fi

# Проверка главной страницы
if [[ ! -f "${LOCAL_DIR}index.html" ]]; then
    echo "Ошибка: site/index.html отсутствует" >&2
    exit 1
fi

# Проверка чистоты Git
if [[ -n "$(git -C "$ROOT" status --porcelain)" ]]; then
    echo "Ошибка: имеются незафиксированные изменения Git" >&2
    exit 1
fi

# Проверка TLS-сертификата
if [[ ! -f "$CA_CERT" ]]; then
    echo "Ошибка: сертификат ${CA_CERT} не найден" >&2
    exit 1
fi

# Получение короткого хеша коммита
COMMIT="$(git -C "$ROOT" rev-parse --short HEAD)"

# Подготовка rsync
RSYNC_ARGS=(
    -avz
    --delete
    --chmod=D755,F644
)

# Пробный режим
if [[ "$DRY_RUN" == true ]]; then
    RSYNC_ARGS+=(--dry-run)
fi

# Передача файлов через SSH
"$RSYNC_BIN" "${RSYNC_ARGS[@]}" \
    -e "ssh -o BatchMode=yes -o ConnectTimeout=5" \
    "$LOCAL_DIR" "${REMOTE}:${REMOTE_DIR}/"

# Завершение пробного режима
if [[ "$DRY_RUN" == true ]]; then
    echo "Пробный деплой завершён. Сервер не изменён."
    exit 0
fi

# Проверка доступности HTTPS
# Используем фиксированный IP для учебной VM,
# сохраняя проверку сертификата по имени devops.local
if ! curl -fsS \
    --connect-timeout 10 \
    --max-time 20 \
    --resolve "devops.local:443:${SERVER_IP}" \
    --cacert "$CA_CERT" \
    "$SITE_URL" \
    -o /dev/null; then

    echo "Ошибка: HTTPS-сайт недоступен" >&2
    exit 1
fi

# Успешное завершение
echo "Деплой завершён успешно. Коммит: $COMMIT"
exit 0

#!/usr/bin/env bash
# Практическая № 6 — автоматический деплой сайта

set -euo pipefail

REMOTE="devops"
REMOTE_DIR="/var/www/devops-site"
SITE_URL="https://devops.local"
CA_CERT="${HOME}/devops.crt"

ROOT="$(git rev-parse --show-toplevel)"
LOCAL_DIR="${ROOT}/site/"
RSYNC_BIN="$(brew --prefix rsync)/bin/rsync"

# Проверяем аргументы
DRY_RUN=false

if [[ $# -eq 1 && "$1" == "--dry-run" ]]; then
    DRY_RUN=true
elif [[ $# -ne 0 ]]; then
    echo "Ошибка: используйте --dry-run или запуск без аргументов" >&2
    exit 1
fi

# Проверяем главную страницу
if [[ ! -f "${LOCAL_DIR}index.html" ]]; then
    echo "Ошибка: site/index.html отсутствует" >&2
    exit 1
fi

# Проверяем чистоту Git
if [[ -n "$(git -C "$ROOT" status --porcelain)" ]]; then
    echo "Ошибка: в Git есть незафиксированные изменения" >&2
    exit 1
fi

# Проверяем сертификат
if [[ ! -f "$CA_CERT" ]]; then
    echo "Ошибка: сертификат не найден" >&2
    exit 1
fi

COMMIT="$(git -C "$ROOT" rev-parse --short HEAD)"

RSYNC_ARGS=(-avz --delete --chmod=D755,F644)

if [[ "$DRY_RUN" == true ]]; then
    RSYNC_ARGS+=(--dry-run)
fi

# Доставляем файлы по SSH без запроса пароля
"$RSYNC_BIN" "${RSYNC_ARGS[@]}" \
    -e "ssh -o BatchMode=yes -o ConnectTimeout=5" \
    "$LOCAL_DIR" "${REMOTE}:${REMOTE_DIR}/"

if [[ "$DRY_RUN" == true ]]; then
    echo "Пробный деплой завершён. Сервер не изменён."
    exit 0
fi

# Проверяем доступность сайта
if ! curl -fsS --connect-timeout 5 \
    --cacert "$CA_CERT" \
    "$SITE_URL" -o /dev/null; then
    echo "Ошибка: HTTPS-сайт недоступен" >&2
    exit 1
fi

echo "Деплой завершён успешно. Коммит: $COMMIT"

