---
name: gosubc
description: Operate the gosubc CLI from arran4/go-subcommand to generate standalone Go command trees, validate and format command definitions, export templates/man pages, or install agent skills. Use for Go programs adopting gosubc, not only for developing the generator.
---
# gosubc — Go CLI generation toolkit

**What it does:** `gosubc` reads command declarations from Go comments or a native `.mdc`/`.mdconf` file and generates dependency-free Go CLI code, usage, parser and optional man pages. No go-subcommand runtime dependency is needed in the generated application. Source: https://github.com/arran4/go-subcommand.

## Decide which command to use

| Intent | Command in a consuming Go module |
| --- | --- |
| Discover command declarations | `gosubc list --dir .` |
| Check aliases, flags, argument bindings and conflicting declarations | `gosubc validate --dir .` |
| Preview canonical source comments (no files changed) | `gosubc format --dir .` |
| Rewrite source comments after reviewing preview | `gosubc format --dir . --inplace` |
| Generate commands from annotated Go source | `gosubc generate --dir .` or the module's pinned `go generate ./...` |
| Generate from declarative metadata | `gosubc generate --config gosubc.mdc --man-dir man` |
| Inspect exported template layout | `gosubc template layout` |
| Export editable templates | `gosubc template export --output /tmp/gosubc-templates` |
| Export templates as TXTAR | `gosubc template export --output /tmp/gosubc-templates.txtar --as-txtar` |
| Generate GoReleaser config/workflow | `gosubc goreleaser --dir . --go-releaser-github-workflow` (inspect changes first) |

**Version first:** use the target repo's `go:generate` or Go tool pin; `gosubc` is pre-v1 and newer syntax can be incompatible. In the generator's own checkout use `go run ./cmd/gosubc ...`. Confirm `gosubc help generate` and `gosubc help skill` in the installed revision; do not guess flags.

## Build a command

Declare executable functions with backtick-enclosed canonical paths:

```go
// Greet is a subcommand `greeter greet` -- Say hello.
// Aliases: hello
//
// Flags:
//   name: --name -n (default: "world") Recipient to greet
func Greet(name string) error {
    fmt.Println("Hello, " + name)
    return nil
}
```

Then run `gosubc validate --dir .`, the pinned generator, `go test ./...` and `go run ./cmd/greeter greet --name Ada`. Read actual generated paths in the consuming module; output is not necessarily `cmd/greeter` if configured otherwise. A metadata-only root uses `is a command` on a package/comment declaration; an executable root uses `is a subcommand` on a real function. Do not create a dummy root action for metadata.

Flag annotations support aliases, `required`, `default:`, `(from parent)`, `parser:`, `generator:`, positional `@1`, variadic `...`, and `(flag presence)` map parameters. Test command-parent inheritance, flag presence (zero/false versus absent), provider dependency/close order and `--` escaping when those features are used. Choose the runtime parser with `--cli-parser gnu` (default) or `--cli-parser go-flag` and optional per-command `CLI-Parser:`. Do **not** claim `plus-minus` is implemented; it is reserved/future work.

## Use the skill-management API

```sh
gosubc skill list
gosubc skill inspect gosubc
gosubc skill install --scope project ./local-skill
gosubc skill update gosubc
gosubc skill remove gosubc
```

Flags must precede the first positional argument in the generated command parser. The installer accepts a skill directory; a Git repository containing nested `skills/.../SKILL.md` is **not** the same as a root-level skill directory. Review existing files and install paths before changes. Current remote install/update and agent-specific paths have known limitations; don't treat `gosubc skill` as equivalent to the container-managed Codex/`agy` installation in dotfiles #491.

## Source, output and regression boundaries

- Never hand-edit `Code generated ... DO NOT EDIT` files. Modify annotated actions, `.mdc` declarations or generator templates, regenerate, then inspect command output and `git diff`.
- `--clean` removes stale generator-owned outputs; only use after verifying its source/version markers and intended output paths.
- Templates and man-page appendices must be generated from declarations. Do not confuse parser name (source `commentv1`) with runtime parser (GNU or Go flag).
- In go-subcommand development, add full `templates/testdata` TXTAR input/expected scenarios for generator changes, then check generated application compilation and execution, including nested help and error exits.
- Run tests in the consuming module and, when changing gosubc, `go test ./...` in the generator plus its independent examples. Provide the exact CLI revision and commands used.

The skill is a **tool dispatch guide**; repository contribution policy remains in each repo's `AGENTS.md`.
