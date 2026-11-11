# Mall4j Android application

This repository builds the Android client from the upstream Mall4j uni-app application at
`gz-yami/mall4j/front-end/mall4uni`. The upstream project already defines the
`build:app-android` command. This repository keeps the build configuration separate
from the upstream source and does not modify the upstream repository.

## Backend requirement

The app requires a publicly reachable, production Mall4j API. Deploy the Java API,
MySQL and Redis services first, configure HTTPS and the production database credentials,
and initialize the Mall4j database using the upstream SQL scripts.

In GitHub repository settings, add a repository variable:

- Name: `MALL4J_API_BASE_URL`
- Value: your API base URL, for example `https://api.example.com`

Do not use localhost or a private LAN address. Do not put database passwords,
JWT signing keys, payment secrets or other credentials in this variable or in app code.

## Build

Open Actions -> Build Mall4j Android APK -> Run workflow. The workflow checks out the
upstream uni-app client, installs its pinned dependencies, injects the HTTPS API URL,
and invokes the upstream Android build command. A successful run uploads
`mall4j-android-apk` as a downloadable workflow artifact.

The workflow deliberately stops if the production HTTPS API URL is missing. A package
that cannot connect to a real backend must not be presented as a working store.

## Scope

Android only. iOS packaging and app-store publication are out of scope.

## License and commercial-use notice

The upstream repository is distributed under AGPL-3.0. Its uni-app README also states
that commercial use requires authorization from the author. Review the license and obtain
any required commercial authorization before public commercial deployment. Preserve
copyright and license notices and make corresponding source available as required by
AGPL-3.0.
