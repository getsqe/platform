A catalog belongs to exactly one workspace, so what you see here is your
workspace's data — not the platform's. The path narrows in the same order
everywhere: catalog, then namespace (a schema), then table.

The table page reads Iceberg metadata rather than the data itself, which is why
it is fast and why it can tell you things a `SELECT` cannot: the current schema,
the partitioning, and the snapshot history. Snapshots are a record of how the
table changed, not a backup — see
[storage and tables](/docs/concepts/storage-and-tables/).

:::caution[An empty namespace is not proof it is empty]
Access is decided per user, and a denied read is not an error — a namespace whose
tables you have no grant on renders as "no tables", with nothing to indicate why.
If you expect something to be there, treat it as an
[access](/docs/concepts/access-control/) question first, not a missing-data one.
:::
