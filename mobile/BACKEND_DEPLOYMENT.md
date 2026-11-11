# Mall4j backend and management deployment

Mall4j uses a Java/Spring Boot backend, MySQL and Redis. The customer Android app and
the management web console are separate clients and use separate backend ports. This
is not a Supabase backend.

## Production topology

| Component | Internal service | Host binding | Public access |
|---|---|---:|---|
| MySQL 5.7 | mysql:3306 | private only | never |
| Redis 5.0.4 | redis:6379 | private only | never |
| XXL-JOB 2.4.2 | xxl-job:8080 | 127.0.0.1:8087 | SSH tunnel only |
| Mall4j customer API | api:8086 | 127.0.0.1:8086 | HTTPS API domain |
| Mall4j admin API | admin:8085 | 127.0.0.1:8085 | HTTPS admin-API domain |
| Mall4j admin web | admin-web:80 | 127.0.0.1:8084 | HTTPS admin domain |

The upstream Dockerfiles explicitly launch Spring's `docker` profile. In that profile
the customer API listens on 8086 and admin API on 8085. The separate `prod` profile
uses 8112 and 8111; do not mix these ports with the supplied Dockerfiles.

## Files added in this repository

- `infra/docker-compose.production.yml`: private database, cache, scheduler, customer
  API, admin API and management frontend services.
- `infra/xxl-job-schema.sql`: XXL-JOB 2.4.2 schema and database grant.
- `infra/bootstrap-ubuntu.sh`: installs Docker Engine/Compose, Nginx and Certbot.
- `infra/configure-upstream.py`: repeatable production patch for CORS, token key,
  local media storage and image-upload fixes.
- `infra/deploy.sh`: builds the admin frontend, compiles Java modules and deploys
  the complete Compose stack.
- `infra/backup.sh`: backs up MySQL/XXL-JOB databases and uploaded images.
- `infra/.env.production.example`: deployment secrets and real-domain settings.
- `infra/nginx-api.conf`, `nginx-admin-api.conf`, `nginx-admin-web.conf`: HTTPS
  reverse-proxy templates for the customer API, admin API and admin website.
- `infra/nginx-admin-static.conf`: static SPA server configuration inside its
  container.

## Server deployment

1. Prepare an Ubuntu server. A practical starting point is 4 vCPU, 8 GB RAM and
   80 GB SSD; increase capacity for a large catalogue, heavy traffic or frequent
   media uploads. Run `sudo bash infra/bootstrap-ubuntu.sh` to install Docker Engine,
   Compose, Nginx and Certbot, or install equivalent supported versions manually.
2. Check out this repository and the pinned upstream `gz-yami/mall4j` source into
   sibling directories. The verified source revision is
   `c69b6793ef2c7f528c5e7364aecd22f0b9f7209f`:
   
   ```bash
   git clone https://github.com/gz-yami/mall4j.git ../mall4j-upstream
   git -C ../mall4j-upstream checkout c69b6793ef2c7f528c5e7364aecd22f0b9f7209f
   ```

   By default the upstream checkout is expected at `../mall4j-upstream`; otherwise
   set `MALL4J_SOURCE_DIR` to its absolute path. The deployment script rejects a
   different source revision so builds remain reproducible.
3. Create DNS records and valid TLS certificates for three separate hostnames:
   - `api.your-domain` for the customer API on port 8086
   - `admin-api.your-domain` for the management API on port 8085
   - `admin.your-domain` for the management website on port 8084
4. Copy `infra/.env.production.example` to `infra/.env.production`. Replace every
   example domain and secret. Generate shell-safe secrets with `openssl rand -hex 32`
   (use `openssl rand -hex 16` for the 32-character AES key). Keep
   `MYSQL_USER=mall4j_app`, because the scheduler schema grants this database account
   access to its own database. Never commit the real env file.
5. Run `bash infra/deploy.sh` from the repository root. It applies the production
   patch to the pinned upstream checkout, builds the Vue admin frontend with
   Node 20.19/pnpm, builds Java modules with Java 17/Maven, validates Compose and
   starts MySQL, Redis, XXL-JOB, both APIs and the admin web container. The patch
   restricts CORS to `MALL4J_ADMIN_WEB_ORIGIN`, switches uploads to persistent local
   storage, replaces the default token AES key and fixes nested image upload paths.
6. Configure host Nginx using the three HTTPS templates. Replace the example
   hostnames and certificate paths in each file before enabling it:
   - `infra/nginx-api.conf` -> `127.0.0.1:8086`
   - `infra/nginx-admin-api.conf` -> `127.0.0.1:8085`
   - `infra/nginx-admin-web.conf` -> `127.0.0.1:8084`
7. Keep the admin website restricted by IP allowlist or VPN if this is an internal
   management system. Do not expose MySQL, Redis or XXL-JOB publicly. Access XXL-JOB
   through an SSH tunnel to localhost port 8087.
8. Check containers and logs:
   ```bash
   docker compose --env-file infra/.env.production -f infra/docker-compose.production.yml ps
   docker compose --env-file infra/.env.production -f infra/docker-compose.production.yml logs --tail=200 mysql redis xxl-job api admin admin-web
   ```

## Database initialization and persistence

Uploaded images are stored in the persistent `mall4j_uploads` Docker volume and served
through the admin API under `/mall4j/img/`. The mobile app and admin frontend must both
use the configured `MALL4J_RESOURCES_BASE_URL` value.

The SQL files are mounted into MySQL's first-run initialization directory. MySQL only
executes them when its data directory is empty. The Mall4j SQL dump contains table
drops and is destructive if manually re-run against a live store. Never delete the
database volume to reset a live service. Run `bash infra/backup.sh` to create a database dump and image archive in `backups/`.
Schedule this script with cron or a system scheduler, copy backups off-server, and
test restoration before taking real orders.

The template currently pins MySQL 5.7 and Redis 5.0.4 to match the upstream project's
original deployment assumptions. These are legacy versions; validate compatibility
and a supported upgrade path before a public production launch.

## First-login security

The upstream XXL-JOB schema seeds the scheduler console with `admin / 123456`.
Change this password immediately after first login. The scheduler access token in
`XXL_JOB_ACCESS_TOKEN` must be a long random secret and must match the token used by
the Mall4j admin executor.

The Mall4j admin account is seeded by the upstream SQL dump; inspect the upstream
initialization data and change any default credentials immediately. Do not assume a
default password is safe for public deployment.

## Android client API

After the customer API and image endpoint respond correctly over HTTPS, set these
GitHub repository variables before a future manual Android build:

- `MALL4J_API_BASE_URL`: customer API base URL.
- `MALL4J_RESOURCES_BASE_URL`: image base URL ending in `/mall4j/img/`.

Use the same values as `infra/.env.production`. The Android workflow refuses
localhost, private-network, example or HTTP URLs.

## External integrations still requiring merchant credentials

The code and infrastructure do not create third-party merchant accounts or secrets.
Before real transactions, configure and test payment provider credentials and callback
URLs, SMS/email providers, object storage/media CDN, shipping/logistics provider,
domain ownership, privacy policy and customer support contacts. Keep all provider
secrets on the backend, never in the Android app or frontend build variables.

For payment, SMS, app signing, store identity and other merchant-owned prerequisites,
see [PRODUCTION_INTEGRATIONS.md](PRODUCTION_INTEGRATIONS.md).

## License

The upstream Mall4j project is AGPL-3.0 and its README states that commercial use
requires authorization from the author. Resolve the applicable license obligations
and obtain required commercial authorization before public commercial operation.
