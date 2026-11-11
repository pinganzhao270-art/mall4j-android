# Mall4j backend deployment

The Mall4j backend is a Java/Spring Boot application backed by MySQL and Redis. It is
not a Supabase backend. The Android client must connect to the API over a public HTTPS
domain; MySQL and Redis stay on a private Docker network.

## Verified upstream configuration

- The supplied Dockerfiles launch the `docker` Spring profile.
- In that profile, the API listens on **8086** and the admin service on **8085**.
- The separate `prod` profile uses API port **8112** and admin port **8111**. Do not
  mix the `prod` ports with the supplied Dockerfiles, which explicitly activate
  `docker`.
- The Docker profile accepts `MYSQL_HOST`, `MYSQL_PORT`, `MYSQL_DATABASE`,
  `MYSQL_USERNAME`, `MYSQL_PASSWORD`, `REDIS_HOST`, `REDIS_PORT`, and
  `REDIS_DATABASE`. Spring Redis password can be supplied as
  `SPRING_DATA_REDIS_PASSWORD`.
- The upstream SQL dump creates the `yami_shops` database and contains table/data
  initialization. The deployment template mounts it into MySQL's first-run init
  directory. MySQL only runs these scripts when its data directory is empty.

## Included deployment template

Files in `infra/` provide a starting point:

- `docker-compose.production.yml`: MySQL 5.7, Redis 5.0.4, XXL-JOB 2.4.2, Mall4j API and admin.
- `xxl-job-schema.sql`: scheduler database schema and limited application-user grant.
- `deploy.sh`: Maven build followed by Compose deployment.
- `.env.production.example`: required secrets and deployment paths.
- `nginx-api.conf`: HTTPS reverse-proxy template for the public API hostname.
- `.gitignore`: prevents local secrets and backups from being committed.

The database and Redis have no public host ports. API and admin are bound to
`127.0.0.1` only, so a host-level reverse proxy can reach them without exposing
them directly to the internet.

## Deployment host preparation

1. Use a Linux server with Docker Engine and the Docker Compose plugin.
2. Check out this repository and the matching upstream `gz-yami/mall4j` source into
   sibling directories, unless you set `MALL4J_SOURCE_DIR` to another path.
3. Copy `infra/.env.production.example` to `infra/.env.production`. Replace every
   placeholder with unique, strong secrets. Never upload the real file to GitHub.
4. From the repository root, run the deployment script. It compiles the upstream
   Maven modules with Java 17, then starts the database, Redis, scheduler, API and
   management services:

   ```bash
   bash infra/deploy.sh
   ```

5. Check service state and logs:

   ```bash
   docker compose --env-file infra/.env.production -f infra/docker-compose.production.yml ps
   docker compose --env-file infra/.env.production -f infra/docker-compose.production.yml logs --tail=200 api admin
   ```

6. Adapt `infra/nginx-api.conf` with the real API domain and certificate paths, then
   enable it in Nginx. Route the public API hostname to `http://127.0.0.1:8086`.
   Keep the admin panel restricted (VPN, allowlisted IPs, or another access-control
   layer); do not publish it openly.
7. Test API reachability, login, product/category reads, image uploads, cart, order
   creation, and admin operations before configuring the Android build.

## Important operational checks

- The included upstream database image is MySQL 5.7 and Redis is pinned to 5.0.4 for
  compatibility with the original Compose setup. Both are legacy versions; assess
  supported upgrades and security maintenance before a public production launch.
- The SQL import is destructive on a fresh schema because it contains table drops.
  It is mounted only as a first-initialization script. Never delete the database
  volume to "reset" a live store.
- Back up MySQL and persistent uploads regularly; test restore procedures.
- XXL-JOB 2.4.2 is included as a private service on port 8087 (loopback only). The
  default scheduler login is `admin / 123456`; change it immediately after first
  login. Access the panel through an SSH tunnel rather than publishing it publicly.
  The scheduler access token must be a unique secret and must match the Mall4j admin
  executor token.
- Review payment provider integration, callback URLs, email/SMS credentials,
  object storage, shipping providers, privacy policy, and applicable local laws
  before taking real orders or money.
- Never expose MySQL or Redis ports publicly. Keep secrets out of source control.

## Android API endpoint

After the API is reachable through HTTPS, set the GitHub repository variable
`MALL4J_API_BASE_URL` to the API base URL, for example `https://api.example.com`.
Do not use localhost, an IP-only HTTP endpoint, or a private LAN address in the app.

## License

The upstream repository is AGPL-3.0. Its uni-app README also states that commercial
use requires authorization from the author. Resolve the applicable license and
commercial authorization before public commercial operation.
