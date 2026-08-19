A grant answers three questions: **who**, **what**, and **on which object**.

**Who** is a user, a group or a role. Prefer a group: a person's access then
follows their membership, and you are not editing grants every time someone joins
or leaves.

**What** is a privilege, grouped by what it lets someone do:

| Group | Privileges | What they mean |
|---|---|---|
| Read | `SELECT`, `MONITOR`, `USE`, `SELECT VIEW` | read rows; list and describe without rows; traverse and list; read one view |
| Write | `INSERT`, `MODIFY`, `ALTER` | change rows; write and relocate a table; change schema but not rows |
| Create & drop | `CREATE`, `CREATE NAMESPACE`, `CREATE VIEW`, `DROP`, `DROP VIEW` | create or drop tables, schemas and views |
| Administrative | `APPLY POLICY`, `MANAGE`, `ALL` | attach policies; everything on the catalog |

`MANAGE` and `ALL` are catalog-wide by nature. If what you want is broad access to
one namespace, name the namespace rather than reaching for `ALL`.

**On which object** is the securable: a catalog, a namespace, or a single table.
Granting at catalog level requires ticking *"I understand this grants access
across a broad securable scope"* — a deliberate speed bump, because a catalog
grant covers every table added to it later, including ones that do not exist yet.

The screenshot shows the dialog part-filled: this flow deliberately stops short of
submitting, because a grant left behind on a shared platform changes what everyone
else sees. What happens after you submit — how a grant becomes an enforced
decision — is [access control](/docs/concepts/access-control/).
