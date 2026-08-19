The overview answers "is the platform up?"; System Health answers "which part
isn't?". Each component reports for itself, so a single degraded dependency is
visible as that dependency rather than as a vague outage.

The one worth knowing by name is the **authorization** service. Access decisions
fail closed, which is the right default and an unhelpful symptom: when the decider
is unhealthy, reads are denied rather than erroring, so data looks *missing*
instead of unavailable. If several people report that tables have vanished, check
here before you go looking for the data.

The same logic applies to the catalog service. Tables live in your object storage
and the catalog is what makes them findable, so losing the catalog looks like
losing the data — while the files are exactly where they were. See
[storage and tables](/docs/concepts/storage-and-tables/).
