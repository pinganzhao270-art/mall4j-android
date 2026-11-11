# Mall4j backend deployment checklist

The upstream Mall4j backend is a Java/Spring Boot service backed by MySQL and Redis.
It is not a Supabase backend. Deploy these services before producing a production APK.

## Important upstream configuration findings

- The upstream Docker Compose example uses MySQL 5.7 and Redis 5.0.4.
- The API production profile listens on container port **8112**, not 8086.
- The upstream sample production profile contains local database credentials and loopback
  host values. They must be overridden for deployment.
- The root application configuration defaults to the `dev` profile. Set
  `SPRING_PROFILES_ACTIVE=prod` explicitly in production.
- The mobile client's production API setting currently defaults to
  `http://127.0.0.1:8086`. The Android build workflow replaces this with the HTTPS
  URL stored in the `MALL4J_API_BASE_URL` repository variable.

## Required production settings

Configure the API container with values equivalent to:

- `SPRING_PROFILES_ACTIVE=prod`
- `SPRING_DATASOURCE_URL=jdbc:mysql://<mysql-host>:3306/yami_shops?...&serverTimezone=GMT%2B8`
- `SPRING_DATASOURCE_USERNAME=<dedicated database user>`
- `SPRING_DATASOURCE_PASSWORD=<strong unique password>`
- `SPRING_DATA_REDIS_HOST=<redis-host>`
- `SPRING_DATA_REDIS_PORT=6379`
- `SPRING_DATA_REDIS_PASSWORD=<strong unique password>`
- `REDIS_DATABASE=0`

Use private Docker networking for MySQL and Redis. Do not expose database or Redis ports
to the public internet. Terminate TLS at a reverse proxy and expose only HTTPS API traffic.
Set upload/storage paths to persistent volumes and configure backups and monitoring.

## Database initialization

Use the SQL scripts shipped in the upstream `db/` directory. Verify the exact schema
version and initialization order against the checked-out upstream revision before
running them on a production database. Do not point the app at an empty database and
assume it is ready.

## Android build gate

Set the GitHub repository variable `MALL4J_API_BASE_URL` to the public HTTPS API base
URL only after the API is deployed and its health/login endpoints have been tested.
Then run the GitHub Actions workflow named **Build Mall4j Android APK**.

## Credentials and release safety

Never commit production credentials, private keys, payment credentials, or database
dumps to this repository. Keep secrets in the hosting provider's secret manager.
The upstream code is AGPL-3.0 and its uni-app README says commercial use requires
author authorization. Resolve those terms before commercial launch.
