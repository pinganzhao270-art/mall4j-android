# Mall4j Android

Android client build workspace for Mall4j.

- Android only; no iOS or app-store publication.
- Upstream client: `gz-yami/mall4j/front-end/mall4uni`.
- Backend: Mall4j Java API with MySQL and Redis.
- Backend deployment template: [infra/docker-compose.production.yml](infra/docker-compose.production.yml).
- Backend setup and security checklist: [mobile/BACKEND_DEPLOYMENT.md](mobile/BACKEND_DEPLOYMENT.md).
- Build workflow: [Build Mall4j Android APK](.github/workflows/android-apk.yml).

Read [mobile/README.md](mobile/README.md) for client configuration and build details.

**Important:** A real production APK requires a deployed Mall4j API reachable over HTTPS.
The build workflow will not silently package a production app with a localhost API
address. Review upstream AGPL-3.0 obligations and obtain any commercial authorization
required by the upstream project before commercial use.
