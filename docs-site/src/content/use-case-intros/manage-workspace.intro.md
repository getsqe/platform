Creating a workspace is not just a row in a list. The slug you choose becomes the
name of everything the workspace gets: its own catalog, its storage (a warehouse
bucket and a staging bucket), and two groups — `ws-<slug>-admins` and
`ws-<slug>-members` — which are what membership actually means.

That is why the slug is worth a moment's thought: it is visible in table names,
in storage paths and in group names afterwards.

The split between the two groups is the one to understand. A **member** can use
the workspace. An **admin** can manage its members and grant access on its own
catalog — and only on its own catalog. What that does and does not isolate is in
[tenancy and isolation](/docs/concepts/multi-tenancy/).
