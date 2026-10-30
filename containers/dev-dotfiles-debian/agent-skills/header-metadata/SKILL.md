---
name: header-metadata
description: Use arran4/header to extract, validate, edit or render web metadata and URL-based social cards; suitable for public-relations asset generation and deterministic metadata regression tests.
---
# Website metadata inspection and social cards

**Source:** https://github.com/arran4/header. Check `header help` and current README before running; local or released binary may not implement recent commands.

## Read-only metadata workflows
- `header extract --style json https://example.com` provides JSON; `--style all_fields_plain`, `opengraph`, `twitter` and `jsonld` target narrower views.
- `header lint https://example.com` or `header lint --rule twitter,opengraph https://example.com` inspects metadata; `header lint-rules` and `lint-rule-lists` discover rules. `header verify` checks URL and media validity; it can generate network traffic.
- `header trace-redirects` follows HTTP/meta refresh; check redirect limits and cookies. Do not send private/auth URLs to arbitrary services or store session cookies casually.
- Generate a social card only when requested, using `header card file --out card.png https://example.com`; review resulting image and upstream image rights before publishing. Card generated does not mean material was posted.

## Local file editing
- `header edit head` and `header edit meta` modify HTML. Review input/output first. `-s` sets all matching occurrences, `-S` adds, and `-r` replaces an existing entry. Preserve canonicals and supported metadata formats; don't edit a generated HTML output if a template/source owns it.

## When developing header
1. Source commands live under `internal/cli`; `cmd/` generated via pinned `go generate ./...`, never direct edits.
2. When adding a property, check each supported renderer/template and negative/empty cases. Preserve externally visible names and ordering unless a change explicitly defines a new contract.
3. Run `go test -race ./...` and configured golangci-lint; check tests for JSON-LD, OpenGraph, Twitter, redirect and URL failure paths.
4. When preparing posts in `arran4/public-relations`, keep generated assets and provenance distinct from actually published material; don't invent publication URLs or results.

## Evidence
Record source URLs, styles, test results, generated card artifact path and any permissions or licensing limitations.
