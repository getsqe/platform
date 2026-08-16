The screenshots below use **service token** authentication, where callers present an
OAuth2 client-credentials token and the calling service principal must be bound to
this workspace. Two other modes exist:

- **Webhook secret** — Standard Webhooks HMAC signing, for senders that cannot
  fetch a token. The Connect dialog then also reveals and rotates a `whsec_`
  secret, which is why that mode is not pictured here.
- **No authentication** — available only where the platform sets
  `TRIGGERS_ALLOW_UNAUTHENTICATED`, which is off by default.

:::note
"Test fire" sends the event through the real path: a task is enqueued and the
statement runs as the trigger's owner. It works while the trigger is disabled, and
it appears in Monitoring like any other firing — so a test is visible in the
history rather than hidden from it.
:::
