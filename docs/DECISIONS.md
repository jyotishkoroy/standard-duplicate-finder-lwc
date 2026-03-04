# Design decisions

This file captures small but practical decisions made to keep the tool stable across orgs.

## Why no async jobs?

Without a persistent storage object, async processing would finish without a reliable place to store results.
A synchronous scan with explicit scope + limits is more predictable and avoids partial experiences.

## Why these heuristics?

Email/phone/name are widely available on standard objects and reasonably effective in practice.
The normalization is conservative to reduce false positives.

## Why phone last N digits?

Country codes and formatting vary. Matching the last 7 digits catches many duplicates while staying lightweight.
The UI allows adjusting N if your data requires it.

## Why no writes?

This repo is intended to be safe to install everywhere. Any merges/updates should be explicit admin actions.
