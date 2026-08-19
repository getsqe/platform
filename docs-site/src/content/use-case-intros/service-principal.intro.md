A service principal is an identity for something that is not a person: a pipeline,
an external engine, a job in another system. It authenticates with OAuth2 client
credentials, and it is authorized exactly like a human identity — by grants, per
resource.

:::caution[The secret is shown once]
The client secret appears once, when you create the principal, and cannot be
retrieved afterwards — the platform stores only a fingerprint of it. Copy it then.
If it is lost, rotate: rotating issues a new secret and invalidates the old one,
so anything still using the old one stops working.
:::

Two habits that save trouble later:

- **Grant it the least it needs.** A service principal outlives the person who
  created it, and nothing prompts it to re-justify its access. Read-only unless
  something genuinely writes.
- **Bind it to a workspace when it will call a trigger.** A trigger's event
  endpoint checks that the calling principal belongs to the trigger's workspace,
  and refuses the call when it does not.
