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

for name in MYSQL_ROOT_PASSWORD MYSQL_USER MYSQL_PASSWORD REDIS_PASSWORD XXL_JOB_ACCESS_TOKEN MALL4J_API_BASE_URL MALL4J_ADMIN_API_BASE_URL MALL4J_RESOURCES_BASE_URL MALL4J_ADMIN_WEB_ORIGIN SHOP_TOKEN_AES_KEY; do
  if [[ -z "${!name:-}" || "${!name}" == REPLACE_* ]]; then
    echo "Set a real value for $name in infra/.env.production before deployment." >&2
    exit 1
  fi
done

if [[ "$MALL4J_API_BASE_URL" != https://* || "$MALL4J_ADMIN_API_BASE_URL" != https://* || "$MALL4J_RESOURCES_BASE_URL" != https://* ]]; then
  echo "Both API base URLs must be HTTPS URLs." >&2
  exit 1
fi
if [[ "$MALL4J_API_BASE_URL" == *example.com* || "$MALL4J_ADMIN_API_BASE_URL" == *example.com* || "$MALL4J_RESOURCES_BASE_URL" == *example.com* ]]; then
  echo "Replace example.com API URLs with your real deployed domains." >&2
  exit 1
fi
if [[ ! "$MALL4J_ADMIN_WEB_ORIGIN" =~ ^https://[A-Za-z0-9.-]+(:[0-9]+)?$ || "$MALL4J_ADMIN_WEB_ORIGIN" == *example.com* ]]; then
  echo "MALL4J_ADMIN_WEB_ORIGIN must be the real HTTPS admin website origin without a path." >&2
  exit 1
fi

if [[ "$MYSQL_USER" != "mall4j_app" ]]; then
  echo "MYSQL_USER must remain mall4j_app because the XXL-JOB schema grants privileges to this account." >&2
  exit 1
fi

python3 "$ROOT_DIR/infra/configure-upstream.py" "$SOURCE_DIR" "$MALL4J_RESOURCES_BASE_URL" "$SHOP_TOKEN_AES_KEY" "$MALL4J_ADMIN_WEB_ORIGIN"

echo "Building Mall4j management frontend with Node.js 20.19 and pnpm..."
docker run --rm \
  -e VITE_APP_BASE_API="$MALL4J_ADMIN_API_BASE_URL" \
  -e VITE_APP_RESOURCES_URL="$MALL4J_RESOURCES_BASE_URL" \
  -v "$SOURCE_DIR/front-end/mall4v:/workspace" \
  -w /workspace \
  node:20.19-bookworm-slim \
  sh -lc 'corepack enable && corepack prepare pnpm@9 --activate && pnpm install --no-frozen-lockfile && pnpm run build'

echo "Building Mall4j backend modules with Java 17 in a Maven container..."
docker run --rm \
  -v "$SOURCE_DIR:/workspace" \
  -w /workspace \
  maven:3.9-eclipse-temurin-17 \
  mvn -B -DskipTests package

echo "Validating Compose configuration..."
MALL4J_SOURCE_DIR="$SOURCE_DIR" docker compose \
  --env-file "$ENV_FILE" \
  -f "$COMPOSE_FILE" \
  config --quiet

echo "Starting database, Redis, scheduler, APIs and management web..."
MALL4J_SOURCE_DIR="$SOURCE_DIR" docker compose \
  --env-file "$ENV_FILE" \
  -f "$COMPOSE_FILE" \
  up -d --build --wait --wait-timeout 600

echo "Deployment command completed. Review container health and logs:"
MALL4J_SOURCE_DIR="$SOURCE_DIR" docker compose \
  --env-file "$ENV_FILE" \
  -f "$COMPOSE_FILE" \
  ps

echo "Services are bound to loopback; configure infra/nginx-api.conf, infra/nginx-admin-api.conf and infra/nginx-admin-web.conf with HTTPS before public use."
