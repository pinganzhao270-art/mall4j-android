# Mall4j Android

Android client build workspace for Mall4j.

- Android only; no iOS or app-store publication.
- Upstream client: `gz-yami/mall4j/front-end/mall4uni`.
- Backend: Mall4j Java API with MySQL and Redis.
- Build workflow: [Build Mall4j Android APK](.github/workflows/android-apk.yml).

Read [mobile/README.md](mobile/README.md) for backend prerequisites and build steps.

**Important:** A real APK requires a deployed HTTPS Mall4j API. The build workflow will
not silently package a production app with a localhost API address. Review upstream
AGPL-3.0 obligations and obtain any commercial authorization required by the upstream
project before commercial use.
