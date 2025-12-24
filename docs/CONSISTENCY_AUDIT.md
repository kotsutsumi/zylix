# Documentation Consistency Audit

## Scope

Cross-checks between `docs/` and `site/content/` for version, ABI, and platform maturity claims.

## Current Source of Truth

- Version / maturity / ABI baseline: `docs/COMPATIBILITY.md`
- Detailed roadmap: `docs/ROADMAP.md`, `docs/ROADMAP.ja.md`

## Diff Table (Action Required)

| Area | Source A | Source B | Mismatch | Recommended Action |
| --- | --- | --- | --- | --- |
| API reference version | `docs/API_REFERENCE.md` summary | `docs/API/README.md` canonical | Possible drift risk | Keep `docs/API_REFERENCE.md` as summary and update date/version on releases |

## Quick Wins

- ✅ Platform docs now link to `docs/COMPATIBILITY.md` for status definitions.
- ✅ `Last Synced` date added to `site/content/docs/roadmap.*`.

## Notes

This audit is intentionally conservative and lists mismatches only.
