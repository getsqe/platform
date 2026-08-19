The statement runs as **you**. There is no shared service identity behind the
editor, so a query returns what your own grants allow and the same SQL can
legitimately return different rows for two people.

Name tables in full — `catalog.namespace.table` — whenever you are not sure what
the session default is. A workspace's queries default to that workspace's own
catalog, so an unqualified name is resolved there, and a query that "works for
them but not for me" is usually a different default rather than a different
permission.

The engine is shown next to the editor. Which engines exist is a platform
decision; choosing between the ones that are enabled is yours — the control is a
plain label when only one is available and a picker when more than one is, offering
SQE (Flight), SQE (Trino) and Spark. The authorization outcome is meant to be the
same whichever you pick. Where the engine changes *where* the decision is made —
and why that matters when debugging — is in [engines](/docs/concepts/engines/).

:::note
A failed query reports the engine's own error. That is deliberate: a truncated or
prettified message is the difference between "table not found" (wrong name) and
"access denied" (right name, no grant), and those need different fixes.
:::
