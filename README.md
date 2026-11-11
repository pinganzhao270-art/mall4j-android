# Mall4j Android

Android storefront and production deployment workspace for the upstream Mall4j project.

- Android storefront source: upstream `front-end/mall4uni`.
- Management console: upstream `front-end/mall4v`.
- Backend: Java/Spring Boot, MySQL and Redis.
- Scheduler: XXL-JOB 2.4.2.
- Deployment: Docker Compose with Nginx HTTPS reverse proxies.
- Android only; no iOS packaging or app-store publication.

Start with [the full backend and management deployment guide](mobile/BACKEND_DEPLOYMENT.md).
The `infra/` directory contains production templates and a deployment script.

The APK workflow is separate and is not required during backend/client preparation.
A production Android build requires the deployed customer API over HTTPS.

**License:** upstream Mall4j is AGPL-3.0. Review all license obligations and obtain
commercial authorization if required before operating a public commercial store.
