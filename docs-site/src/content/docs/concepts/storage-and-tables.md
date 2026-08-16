---
title: Storage and tables
description: Why the table format matters, and what it means that your data stays in your own object storage.
sidebar:
  order: 6
---

Your data sits in **object storage you own**, in an **open format**. Everything
else the platform does is built around that, and it is the single most consequential
property of the product — so it is worth understanding rather than taking on
faith.

## Iceberg, in one page

A table here is an [Apache Iceberg](https://iceberg.apache.org/) table. Iceberg
is a *table format*: a specification for how a set of data files in object storage
adds up to a table with a schema, a history and transactional behaviour.

What that buys you, concretely:

- **Any engine can read it.** The platform's own engine, Trino and Spark all read
  the same table. So can anything else that speaks Iceberg, including tools the
  platform has never heard of.
- **Schemas can change without rewriting the data.** Adding, renaming or
  reordering a column is a metadata operation.
- **History is kept.** Each write produces a **snapshot**, so a table has a past
  you can inspect rather than only a present.
- **Writes are atomic.** A reader sees the table before a write or after it,
  never halfway through.

## Why "storage you own" is the important part

The alternative — the normal arrangement in this market — is that your data lives
inside a vendor's proprietary storage, and getting it out is a project.

Here, the object storage is yours. The platform holds *metadata* about your
tables and decides who may read them; it does not hold the tables hostage. If you
stopped using the platform tomorrow, the files and their Iceberg metadata would
still be sitting in your bucket, still readable by any Iceberg-capable engine.

That is worth checking when you compare platforms. Every vendor has a query
editor. Not every vendor leaves you able to walk away.

## How storage is laid out

Each workspace gets its own buckets — a **warehouse** bucket for table data, and a
**staging** bucket for work in progress. Because a catalog belongs to exactly one
workspace, a table's storage location follows from where it lives in the
hierarchy rather than being configured per table.

Engines are given **scoped, temporary credentials** for the specific storage a
query needs, rather than a standing key with broad access.

## Snapshots, and what they are not

A snapshot is a consistent view of a table at a point in time. They make
time-travel queries and rollback possible.

They are not backups. They live in the same storage as the table, and table
maintenance can expire old ones. Treat them as history, and back up storage the
way you would back up any storage.

## Where to go next

- [The platform model](/concepts/platform-model/) — how a table's place in the
  hierarchy decides where it is stored.
- [Query engines](/concepts/engines/) — three engines over this one copy.
- [Browse the data catalog](/guides/use-cases/browse-catalog/) — reading a
  table's schema and metadata in the portal.
