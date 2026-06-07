# CloudFront HTTPS Entry for Kong Dev

This module creates a temporary HTTPS entry for the existing Kong ALB by using
the default CloudFront domain name, for example `https://dxxxxx.cloudfront.net`.

It is intended for dev integration when no custom domain is available yet. The
main goal is to make browser APIs that require a secure context work correctly,
including Logto SPA sign-in with Authorization Code + PKCE.

## Topology

```text
Browser
  -> https://<cloudfront-domain>/hanzi/app
  -> CloudFront
  -> http://<kong-alb>
  -> Kong
  -> EKS services
```

The distribution uses:

- CloudFront default certificate.
- Viewer protocol policy: redirect HTTP to HTTPS.
- Origin protocol: HTTP only to Kong ALB.
- Managed caching disabled policy.
- Managed all-viewer-except-host-header origin request policy.

## Apply

```bash
cd infra/live/dev/cloudfront-kong
cp backend.tf.example backend.tf
cp terraform.tfvars.example terraform.tfvars
```

Confirm `origin_domain_name` is the current Kong ALB hostname:

```bash
kubectl get ingress -n kong kong-alb \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'; echo
```

Then apply:

```bash
tofu init
tofu plan
tofu apply
```

CloudFront deployment can take several minutes.

## Outputs

```bash
tofu output https_base_url
tofu output hanzi_frontend_url
tofu output hanzi_frontend_auth_url
tofu output hanzi_frontend_callback_url
tofu output hanzi_frontend_post_logout_url
```

## Logto Cloud Settings

In the Logto Cloud SPA app, add:

```text
Redirect URI:
<hanzi_frontend_callback_url>
```

```text
Post sign-out redirect URI:
<hanzi_frontend_post_logout_url>
```

The frontend GitHub variable remains:

```text
VITE_LOGTO_ENDPOINT=https://xlf5b2.logto.app
```

## Validate

Open the CloudFront auth URL:

```bash
open "$(tofu output -raw hanzi_frontend_auth_url)"
```

In browser console:

```js
window.isSecureContext
```

Expected:

```js
true
```

Then click `使用 Logto 登录`.

