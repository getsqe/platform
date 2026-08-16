---
title: Identity
description: How a caller is named at every hop, and what 401 / 403 / 404 each tell you.
sidebar:
  order: 1
---

Authorization — *what may this identity do* — is a separate question, covered in
[Access control](/concepts/access-control/). This page is about **identity**: what a caller is
*called*, and why that is where the expensive failures are. An identity that
authenticates perfectly but arrives under the wrong name is indistinguishable,
from the outside, from one that simply has no grant.

## The identity model

Identity comes from the IdP. The platform mirrors IdP objects onto the data plane
rather than inventing its own directory:

| In the IdP (Keycloak) | On the data plane | Preferred for |
|---|---|---|
| **user** | a catalog **principal** of the same name | **people — this is the default path** |
| **group** | a Ranger **role** of the same name | **teams — grant once, membership follows** |
| **client** (service account) | a catalog **principal** of the same name | systems only |

**User principals and group roles are the preferred model.** Service principals
are fully supported — they can be created and granted like any other identity, and
an existing IdP client can be granted directly — but they are the second choice,
for the case where no person is present. See [System access with service
principals](/guides/service-principals/).

The reason for the preference is that only the user path keeps the end user's
identity intact all the way to Ranger, which is what makes grants, row filters and
audit name an actual person.

### Groups carry a synced user list, not a group reference

Worth knowing because it changes how a group grant fails. A Ranger role does not
point at the Keycloak group; it holds a **list of users** synced from it. Verified
on a running stack — 41 roles, named exactly after their groups
(`SG-Platform-Admins`, `SG-DataAnalysts`, `ws-<slug>-admins`, `ws-<slug>-members`),
each carrying a user list.

So a group grant has two independent halves:

1. the role exists and holds the grant, and
2. the role's membership has been synced.

With the first but not the second, the role matches nobody and every member is
denied — with no error anywhere to explain it. On the stack this was checked
against, `platform-admin` had two members while `SG-Platform-Admins` had none, so
this is not a hypothetical. **If a group grant appears to do nothing, check
membership before anything else.**

## The rule

> Every plane keys on **`preferred_username`**, so that claim must be identical in
> Keycloak, as a catalog principal, and as a Ranger grantee — for human users and
> service principals alike.

Nothing propagates a rename. The three planes look the name up independently.

## Reading the failure

| Symptom | Which plane | Meaning |
|---|---|---|
| **401** | Keycloak ↔ catalog | The token is valid, but no principal matches its `preferred_username`. The catalog logs the name it looked for — read it. |
| **403** | catalog ↔ Ranger | The principal resolved, but no policy grants it. Either the grantee name differs, the grant is genuinely absent, or Ranger's plugin has not polled yet (~5s). |
| **404** | neither | The object does not exist — *usually*. See below. |

**A 404 can be a denial.** Under a fail-closed catalog an unauthorized read can
surface as *table not found* rather than 403. Confirm the object exists as an
admin before drawing conclusions from a 404.

## Service principals carry two names

Service principals exist for **systems**. They are not a way to give a person
access — see [System access with service
principals](/guides/service-principals/) for why that trade is a bad one.

A `client_credentials` token has both, and they are not the same:

```
azp                = my-service                   ← the client id
preferred_username = service-account-my-service   ← Keycloak's service-account user
```

The catalog resolves on `preferred_username`. Provisioning creates the principal
and the Ranger grantee under the *bare* name. Getting this wrong means the
service principal cannot authenticate at all — every call is a 401, with no grant
involved.

`azp` is still the right claim in one place: the trigger `/events` endpoint binds
on it, because it needs to know *which client called*, not *who*. Do not
substitute one for the other — pointing the catalog at `azp` would fix service
accounts and break every human user.

## Which identity reaches the catalog

This is the most important thing to know about the security model:

| Engine | Identity at the catalog | Consequence |
|---|---|---|
| **SQE** | the end user's JWT, forwarded | authorization is genuinely per-end-user |
| **Spark via Kyuubi** | a service principal | per-user enforcement happens in Kyuubi's own Ranger check, not at the catalog |
| **Trino** | a service principal | same shape as Spark |

A grant written only against the catalog plane therefore does **not** constrain
the Spark path. Coarse grants are dual-written to both Ranger services for this
reason.
