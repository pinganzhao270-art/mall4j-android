# Production integrations and release prerequisites

The upstream Mall4j source already contains storefront, order, member, product and
management modules. The deployment workspace now configures Java services, MySQL,
Redis, XXL-JOB, local media storage, management website, HTTPS routing templates,
CORS allowlist and backup script.

The following integrations cannot be completed with source code alone because they
require merchant-owned accounts, verified domains or legal business information.

## 1. Payment collection

The upstream client defines WeChat Pay and Alipay payment modes, including Android
app payment modes. Before accepting real payments, the merchant must obtain and
configure the relevant provider account credentials, app identifiers, merchant
identifiers, API keys/private keys, certificates and callback URLs.

- Use the merchant's own WeChat Pay and Alipay accounts. Do not reuse upstream demo
  credentials or certificates.
- Register the Android package identifier and signing certificate with each payment
  provider where required.
- Configure provider server callbacks to the deployed Mall4j HTTPS API.
- Test successful, cancelled, duplicated and delayed callbacks, refunds and order
  state reconciliation in sandbox/test mode first.
- Keep all private keys and API secrets on the backend. Never embed them in the APK,
  frontend build variables or GitHub source.

Until credentials and callbacks are configured and tested, keep real-money payment
channels disabled in the store.

## 2. SMS verification

The upstream backend sends SMS through Alibaba Cloud Dysmsapi. It reads
`shop.aLiDaYu.accessKeyId`, `shop.aLiDaYu.accessKeySecret` and `shop.aLiDaYu.signName`
from `yami-shop-common/src/main/resources/shop.properties`.

The upstream `SmsType` enum contains fixed template-code values and sample message
text. These must be replaced with templates approved in the merchant's own Alibaba
Cloud SMS account. At minimum, configure the phone verification template used by
registration/login. Configure notification templates too if order/shipping SMS is
enabled. Confirm template variables match the parameters sent by the backend.

SMS is not production-ready until credentials, sender signature, approved template
IDs, phone-number region and rate limits have been tested.

## 3. Product images and uploaded files

The deployment template switches Mall4j to local file storage and creates a persistent
Docker volume shared by the API and admin services. The production patch also fixes
the upstream nested-directory creation and local rich-text image URL behavior.

Set `MALL4J_RESOURCES_BASE_URL` to the public HTTPS image base ending in
`/mall4j/img/`. Keep `infra/backup.sh` scheduled and copy its database/image backups
off-server. For multi-server or high-availability deployment, replace local volume
storage with a supported object-storage adapter and CDN before scaling horizontally.

## 4. Domains and TLS

Three HTTPS hostnames are required by the current deployment layout:

- Customer API: `api.your-domain`
- Admin API and image endpoint: `admin-api.your-domain`
- Admin website: `admin.your-domain`

Create DNS records, obtain valid TLS certificates, set the matching environment
variables in `infra/.env.production`, and adapt the three Nginx templates. Restrict
the admin website and scheduler console to trusted administrators (VPN or IP
allowlist). MySQL and Redis must remain private.

## 5. Android release identity

Before public distribution, create a new Android application identity rather than
reusing an upstream developer's DCloud AppID or package/signing identity. Set the
final app display name, package identifier, version, app icon and splash artwork.
Generate a dedicated release signing key, store it outside GitHub source, back it up
securely and use GitHub Actions secrets if/when automated signing is enabled.

The current APK workflow is manual-only and is intentionally not part of backend
deployment or validation.

## 6. Store and legal settings

Before opening the store to customers, complete the store name, logo, contact details,
business address, customer-service channels, shipping rules, return/refund policy,
privacy policy, terms of service, tax and invoicing settings, and regional compliance
requirements in the Mall4j admin system.

The upstream repository is AGPL-3.0. Its project documentation also states that
commercial use requires authorization from the author. Obtain any required commercial
authorization and satisfy applicable source-disclosure and notice obligations before
public commercial use.
