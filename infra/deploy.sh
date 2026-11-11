#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$ROOT_DIR/infra/.env.production"
COMPOSE_FILE="$ROOT_DIR/infra/docker-compose.production.yml"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing infra/.env.production. Copy infra/.env.production.example and set real secrets first." >&2
  exit 1
fi

set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

SOURCE_DIR="${MALL4J_SOURCE_DIR:-$ROOT_DIR/../mall4j-upstream}"
SOURCE_DIR="$(cd "$SOURCE_DIR" 2>/dev/null && pwd)" || {
  echo "Mall4j source directory not found: ${MALL4J_SOURCE_DIR:-$ROOT_DIR/../mall4j-upstream}" >&2
  exit 1
}

if [[ ! -f "$SOURCE_DIR/pom.xml" || ! -f "$SOURCE_DIR/db/yami_shop.sql" ]]; then
  echo "The source directory is not a complete gz-yami/mall4j checkout." >&2
  exit 1
fi

for name in MYSQL_ROOT_PASSWORD MYSQL_USER MYSQL_PASSWORD REDIS_PASSWORD XXL_JOB_ACCESS_TOKEN; do
  if [[ -z "${!name:-}" || "${!name}" == REPLACE_* ]]; then
    echo "Set a real value for $name in infra/.env.production before deployment." >&2
    exit 1
  fi
done

if [[ "$MYSQL_USER" != "mall4j_app" ]]; then
  echo "MYSQL_USER must remain mall4j_app because the XXL-JOB schema grants privileges to this account." >&2
  exit 1
fi

echo "Building Mall4j backend modules with Java 17 in a Maven container..."
docker run --rm \
  -v "$SOURCE_DIR:/workspace" \
  -w /workspace \
  maven:3.9-eclipse-temurin-17 \
  mvn -B -DskipTests package

echo "Starting database, Redis, API and admin services..."
MALL4J_SOURCE_DIR="$SOURCE_DIR" docker compose \
  --env-file "$ENV_FILE" \
  -f "$COMPOSE_FILE" \
  up -d --build

echo "Deployment command completed. Review container health and logs:"
MALL4J_SOURCE_DIR="$SOURCE_DIR" docker compose \
  --env-file "$ENV_FILE" \
  -f "$COMPOSE_FILE" \
  ps

echo "API is bound to 127.0.0.1:8086; configure infra/nginx-api.conf and HTTPS before public use."
