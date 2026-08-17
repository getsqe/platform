---
title: Bring up a stack
description: Start the local development stack and confirm it is actually healthy.
sidebar:
  order: 1
---

The `quickstart/sqe` stack runs the whole platform locally: Keycloak, Apache
Polaris, Apache Ranger, the query engine, the backend, the frontend, MLflow and
Langflow.

```sh frame="terminal"
cd quickstart/sqe
cp .env.example .env      # then fill in the required secrets
./dev.sh
```

First boot takes several minutes — Ranger runs its schema DDL, and the query
engine is built from source.

## Confirm it is healthy, not just running

Do this before concluding anything is broken. Several services report *running*
while being unusable, so check health rather than presence:

```sh frame="terminal"
docker ps --filter name=sqe- --format '{{.Names}}\t{{.Status}}' | grep -i unhealthy
```

No output is the answer you want.

Then open `https://chameleon.test` and sign in.

## If it does not come up

The two failures that account for most lost time:

**`ranger-setup` sits on "Waiting for Ranger Admin" forever.** The admin password
stored in the `ranger-db` volume does not match `RANGER_ADMIN_PASSWORD`. Ranger
only applies that password at *first* database init, so a re-used or
half-initialised volume keeps an older one and no amount of waiting fixes it. The
wait loop now fails fast and names this. The fix is to remove the `ranger-db`
volume and let it re-initialise.

**A container is `unhealthy` but the service answers.** Check whether the
healthcheck itself can run. The query-engine image is distroless — no shell, no
curl — so a `CMD-SHELL` probe cannot execute and the container never reports
healthy even though the process is fine.

## What next

- [Transform data with dbt](/docs/guides/dbt/) — the shortest path to something real
- [Identity](/docs/concepts/identity/) — read this before debugging any 401 or 403
