---
name: arran-linux-debugging
description: Diagnose Linux desktop, KDE/Akonadi, Hyprland, systemd, mounting or kernel integration defects with scoped instrumentation and reproducible tests.
---

# Linux systems debugging

1. Confirm host versus guest, distro, kernel, desktop session (Wayland/X11), app versions and user impact before collecting logs.
2. Reproduce the smallest problem with an explicit control case. For KDE/Akonadi, distinguish disk/cache notifications from IMAP/server fetching; for Hyprland, scope changes to the affected host unless asked otherwise.
3. Collect focused `journalctl`, service status, `strace`, DBus and application logs as applicable. Write transient artifacts under /tmp; use ~/tmp only when logs must persist. Scrub emails, tokens and private paths before sharing.
4. Prefer isolated builds or copy-on-write snapshots for risky tests. Do not mount or replace the host user's live home or interfere with concurrent applications.
5. Compare current version with newer/upstream version under equivalent data, watching for stale caches, watcher events and asynchronous races.
6. Propose a minimal fix and a regression test. For systemd mounts, verify fstab/systemd semantics, shutdown and failure recovery rather than relying on a simple successful mount.
7. Record exact commands, versions, kernel capabilities, reproduction result, observed evidence and any tests that could not run.

Do not run potentially destructive file-system repair, recursive ownership changes, or host service reconfiguration without explicit authorization.
