# Standard Duplicate Finder (Contacts & Leads)

Lightweight, **read-only** duplicate discovery for **Contacts** and **Leads** using simple heuristics (**Email**, **Phone**, **Name**).
Designed for admins and developers who need a fast, no-surprises way to surface likely duplicates without installing managed packages or creating custom objects.

- ✅ Works in any org (no custom objects, no dependencies)
- ✅ Read-only scanning (no writes unless you export and act outside Salesforce)
- ✅ Clear grouping + drill-down + CSV export
- ✅ Guardrails for large datasets (scope + record limits)
- ✅ Clean UI with SLDS + scoped CSS

**Public credit:** Built by [Jyotishko Roy](https://orcid.org/0009-0000-2837-4731)

## What it does

The app scans a configurable slice of Contact/Lead data and groups records that share:

- **Email match:** normalized email (trim + lowercase)
- **Phone match:** normalized phone digits (compares last N digits to avoid formatting noise)
- **Name match:** normalized name (lowercase + punctuation removal + whitespace folding)

This is intentionally **heuristic**, not ML-based and not a replacement for Salesforce Duplicate Rules.

## Install (SFDX)

```bash
sf org login web
sf project deploy start
sf org assign permset --name Standard_Duplicate_Finder
```

Then open **App Launcher → “Standard Duplicate Finder”** (custom tab).

## Permissions

The included permission set grants:

- Access to the LWC tab
- Apex class access
- **Read** access to Contact/Lead and the fields used for matching

If a user lacks object/field permissions, the UI remains stable and shows a descriptive error message.

## Usage

1. Choose **Object**: Contact or Lead
2. Choose **Match signals** (Email/Phone/Name)
3. Choose a **Scope** (Last 30/90/365 days) + **Record limit**
4. Click **Scan**
5. Expand groups and **Export CSV** if needed

## Guardrails & limits

This tool intentionally avoids long-running jobs and data writes:

- Scans are synchronous and limited by scope + record limit.
- For very large orgs, choose a narrower scope (e.g., 30–90 days) and scan iteratively.

## Architecture

- **LWC**: `standardDuplicateFinder`
- **Apex**: `StandardDuplicateFinderController` + `DupFinderNormalize`
- No custom objects, no platform events, no external services

## License

Licensed under the **Apache License 2.0**. See `LICENSE`, `NOTICE`.

## Citation

If you use this in academic work or documentation, see `CITATION.cff`.

## Contributing

See `CONTRIBUTING.md`. Please follow the Code of Conduct in `CODE_OF_CONDUCT.md`.

## Security

See `SECURITY.md` for reporting guidelines.
