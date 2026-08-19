Three different questions, three screens:

- **Audit log** — what was asked for, by whom, and what was decided. This is the
  record of authorization decisions, including the denials, which is what makes it
  the place to answer "could they have seen it?" rather than "did they open it?".
- **Security alerts** — what the platform noticed on its own. Nobody configures
  these per workspace; patterns like a burst of denials for one user are surfaced
  whether or not anyone was looking.
- **Audit digest** — a period summarised, for the review that happens on a
  calendar rather than in the moment.

:::caution[An empty audit log is a finding, not a clean result]
The trail is fed by the data plane. If queries are being served and nothing is
arriving, the honest reading is that the pipeline stopped delivering — not that
nothing happened. A silent audit trail is the one failure you cannot detect by
looking at the audit trail, so treat "no records in a busy period" as something to
investigate.
:::
