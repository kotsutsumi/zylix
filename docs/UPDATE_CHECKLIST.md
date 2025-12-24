# Documentation Update Checklist

Use this checklist whenever a version, ABI, or platform status changes.

## 1. Core Version & ABI

- Update `docs/COMPATIBILITY.md` (version, ABI, Zig requirements, maturity matrix).
- Update `docs/ABI.md` if exports or ABI version changed.
- Update `docs/ROADMAP.md` and `docs/ROADMAP.ja.md` current version line.

## 2. Site Summary Pages

- Update `site/content/docs/_index.md` and `site/content/docs/_index.ja.md` version line.
- Update `site/content/docs/roadmap.md` and `site/content/docs/roadmap.ja.md` summary.
- Update top-level maturity tables to match `docs/COMPATIBILITY.md`.

## 3. API Docs

- Update `docs/API/README.md` version table and module version headers.
- Update `docs/API_REFERENCE.md` summary version if kept.
- Ensure `docs/API_REFERENCE.md` links to `docs/API/README.md` and matches the current release date.

## 4. Getting Started & Tutorials

- Confirm `site/content/docs/getting-started.*` commands match repo layout.
- Confirm `/tutorials/*` commands match platform README files.

## 5. Blog & Marketing Pages

- Verify maturity language matches `docs/COMPATIBILITY.md`.
- Update license statements if the LICENSE changes.

## 6. Consistency Audit

- Refresh `docs/CONSISTENCY_AUDIT.md` diff table.
- Ensure any watchOS references align with the maturity matrix.
