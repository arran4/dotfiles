---
name: header-metadata
description: Use the arran4/header CLI to inspect web metadata, run named lint rule lists or selected checks, verify URL/image references, trace redirects, edit head/meta tags, output JSON or create social cards. Prefer concrete header commands to manual scraping.
---
# header — website metadata and diagnostics

**Tool:** https://github.com/arran4/header; `header help` and the CLI `--help` show the installed revision. Suitable for URL previews, OpenGraph/Twitter/JSON-LD auditing, link unfurling, content investigations and creating social-card inputs.

## Choose the right operation

| Need | Command |
| --- | --- |
| Human readable basic metadata | `header extract https://example.com` |
| Machine-readable metadata | `header extract --style json https://example.com` |
| Inspect OG, Twitter or JSON-LD specifically | `header extract --style opengraph https://example.com`; `--style twitter`; `--style jsonld` |
| Inspect every field | `header extract --style all_fields_plain https://example.com` |
| List lint rule lists | `header lint-rule-lists` |
| List available individual rules | `header lint-rules` |
| Run a recommended or entire lint set | `header lint --list recommended https://example.com`; `header lint --list all https://example.com` |
| Narrow checks to known rule identifiers | `header lint --rule twitter,opengraph https://example.com` (inspect names first) |
| Inspect URL/media reachability | `header verify https://example.com` |
| Trace HTTP and meta-refresh redirects | `header trace-redirects https://example.com` |
| Debug fetched HTTP traffic | `header lint --httpretty https://example.com` or `header httpretty https://example.com` |
| Render a social image | `header card file --out /tmp/preview.png https://example.com` |
| Inspect image/favicon | `header view image https://example.com/image.png`; `header view icon https://example.com` |

**Lint and verify are different:** `lint` runs metadata quality rules, selected by named `--list` and/or comma-separated `--rule`; `verify` runs the URL/image verification rule list. Use `header lint-rule-lists`/`lint-rules` for the current registered checks instead of inventing identifiers. The lists `recommended` and `all` are wired into `internal/cli/lint.go`; the `verify` list into `internal/cli/verify.go`. Both currently call `lint.Run(...)` then return `nil` when fetching succeeds: **exit code zero does not prove zero lint findings**. Read and report the findings, and never assert it is a CI quality gate without a verified machine-readable/failing-status contract. Fetch failures return an error.

## Diagnosing a page

1. Fetch once with `header extract --style json URL` to inspect actual canonical, title, description, images and structured metadata.
2. Discover the rule lists/IDs, then `header lint --list recommended URL` (or `all` for full audit). Separate missing metadata from broken remote media and intentional warnings.
3. Use `header verify URL` for reachability and cover-image validity; trace redirects if the canonical or preview target differs.
4. If the page's HTML is editable, operate on a copy or on the **source template**, not a generated deployment artifact. `header edit head`/ `header edit meta` support `-s` (set), `-S` (append) and `-r` (replace one); `-n` selects replacement occurrence. Use `-` as input/output for pipe-based inspection where supported.
5. Re-extract and re-lint the deployed page after publishing; don't conflate local HTML changes with live server output, cache/redirect behavior or third-party card previews.
6. For a card, run `header card file --out /tmp/card.png URL` and review output before copying to public-relations material. Do not automatically publish a post, clipboard image or fetched remote asset.

## When modifying header itself

Code for the CLI lives under `internal/cli`; generated commands in `cmd` are refreshed via pinned `go generate ./...`. For new metadata, trace each supported output format and lint list with a positive and empty/malformed regression case. Run `go test -race ./...` and the configured golangci-lint; confirm tests rather than silently lowering lint severity. Avoid real accounts/cookies and report any remote-site instability.

**Deliverable:** commands and actual findings, selected lint lists/rules, verified versus merely reported checks, changed page/template path and any generated image path. No fictitious quality-pass status.
