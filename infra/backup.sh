#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$ROOT_DIR/infra/.env.production"
BACKUP_DIR="$ROOT_DIR/backups"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing infra/.env.production." >&2
  exit 1
fi

set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

if [[ -z "${MYSQL_ROOT_PASSWORD:-}" ]]; then
  echo "MYSQL_ROOT_PASSWORD is missing." >&2
  exit 1
fi

mkdir -p "$BACKUP_DIR"
chmod 700 "$BACKUP_DIR"

echo "Backing up Mall4j databases..."
docker exec -e MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mall4j-mysql \
  mysqldump -uroot --single-transaction --routines --triggers \
  --default-character-set=utf8mb4 --databases yami_shops xxl_job \
  > "$BACKUP_DIR/databases-$STAMP.sql"

echo "Backing up persistent uploaded images..."
docker run --rm --volumes-from mall4j-admin \
  -v "$BACKUP_DIR:/backup" \
  alpine:3.20 \
  tar -czf "/backup/images-$STAMP.tar.gz" -C /data/mall4j/images .

chmod 600 "$BACKUP_DIR/databases-$STAMP.sql" "$BACKUP_DIR/images-$STAMP.tar.gz"

# Keep the latest 30 days of local backups; copy backups off-server as well.
find "$BACKUP_DIR" -type f -mtime +30 -delete

echo "Backup completed: $BACKUP_DIR"
