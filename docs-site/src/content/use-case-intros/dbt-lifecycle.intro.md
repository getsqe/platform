dbt runs against the platform the same way you do, so a model is built by an
identity with grants — not by a privileged pipeline account. The lifecycle below
is four things in order: connect the repository, create a project from it, run it,
then test it.

**The connection is a credential, not a URL.** It holds a token with read access
to the repository, so a project can be created from a private repo. Get this wrong
and the failure appears at project creation, not at connection time.

**Lineage is produced by the run, not parsed from the code.** The graph you see
after building is what actually executed, which is why it appears only once a run
has succeeded and why it changes when the models do. Running the tests then adds
their coverage to the same graph — so a model with no test is visible as such.

For the same lifecycle from the command line, and for scheduling it once it works,
see [making work happen](/docs/concepts/orchestration/).
