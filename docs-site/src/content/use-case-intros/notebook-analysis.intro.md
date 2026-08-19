The notebook runs against a kernel the platform provisions for your workspace.
Two consequences worth knowing before you start:

- **You do not put credentials in the notebook.** The kernel is wired to the
  platform already, so a notebook that reads a table does it as you, with your
  grants — the same decision the query editor gets.
- **The ML experiment template arrives with tracking configured.** Runs you log
  land in MLflow without any setup, which is the difference between the template
  and an empty notebook.

:::note
A kernel is started when you open the notebook, not when you create it, so the
first cell can wait a few seconds on a cold kernel. If the platform reports that
the kernel failed to start, opening it again is a reasonable first response — the
second attempt starts a fresh one.
:::
