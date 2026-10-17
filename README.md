# cc-switch

Generate `~/.claude/settings.json` from saved provider/model configs —
a small CLI that mirrors the [credstore](https://github.com/juzcn/credstore) pattern.

Non-secret provider *shape* lives in `~/.claude/cc-switch.json`.  API
keys are **never** stored there — the config keeps the key's *name*,
and the value is read from credstore at activate time and injected into
the system environment as `ANTHROPIC_AUTH_TOKEN`.  The generated
`settings.json` contains no credential line.

## Install

cc-switch is a standalone PyPI package, installed independently of
[Slife](https://github.com/juzcn/slife) — it was originally extracted from that
repository, but neither package pulls in the other.  It depends on
[credstore](https://github.com/juzcn/credstore), which is pulled in
automatically.

```bash
uv tool install --force --python '>=3.13' cc-switch
# or, in this repo (dev):
uv sync
```

> `--python '>=3.13'` is not optional. Without it `uv` builds the tool
> environment on whichever interpreter it prefers; cc-switch needs ≥ 3.13, so
> an older environment has no compatible release to install at all. With the
> constraint, uv fetches a suitable interpreter or fails loudly.

One-click installers (install `uv` if needed, then `uv tool install --force
--python '>=3.13' cc-switch`):

```bash
# macOS / Linux / WSL
curl -fsSL https://raw.githubusercontent.com/juzcn/cc-switch/main/install.sh | bash

# Windows PowerShell
powershell -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/juzcn/cc-switch/main/install.ps1 | iex"
```

The installers and the `--force` form are **idempotent** — the first run
installs, re-running **updates** to the latest PyPI release.  A plain
`uv tool install cc-switch` no-ops when the tool is already installed.

Uninstall with `uninstall.sh` / `uninstall.ps1`.  The uninstaller also
removes the `ANTHROPIC_AUTH_TOKEN` that `activate` injected into the
system environment (before dropping the tool, since `credstore`'s CLI
lives inside the cc-switch environment); config under
`~/.claude/cc-switch.json` and the generated `~/.claude/settings.json`
are left in place.

## Commands

### `cc-switch set <provider-name>`

Create or edit a provider.  Prompts for:

- **Base URL** (required)
- **API key name** — the credstore key holding the secret (required)
- **Supported models** (optional; comma, space, or semicolon separated)

If the provider already exists this *edits* it; otherwise it *adds* it.
When editing, a blank answer keeps the current value.  The models prompt
**toggles** against the provider's current list: a model you type that is
already listed is removed, one that isn't is added (symmetric
difference).  A blank answer leaves the list unchanged, and typing the
same list again undoes the change.

```bash
cc-switch set deepseek
# Base URL [..]: https://api.deepseek.com/anthropic
# API key name (credstore key): DEEPSEEK_API_KEY
# Supported models (comma, space, or semicolon separated; toggles against the current list): deepseek-chat,deepseek-reasoner
```

No secret value is ever asked for or written — store it first with:

```bash
credstore set DEEPSEEK_API_KEY
```

### `cc-switch activate <provider-name/model-name>`

Writes `~/.claude/settings.json` with stock Claude Code defaults, and
injects the API key from credstore into the system environment as
`ANTHROPIC_AUTH_TOKEN` (mirroring `credstore inject` — registry on
Windows, shell profile on Unix), so a freshly launched Claude Code
session inherits it.  The settings file contains **no** credential.

> `activate` **replaces** `~/.claude/settings.json` wholesale — it is not
> a merge.  Any hand-written settings in that file are overwritten with
> the generated template (the env block plus `autoUpdatesChannel`).  Keep
> customisations in a different settings file, or re-apply them after
> activating.

`settings.json` is written first, then the secret is resolved from
credstore.  If the key is missing — or credstore itself is not
installed — `activate` fails loudly with the appropriate hint, leaving
the generated settings file on disk but **not** injecting a token.

On success, the activated `provider/model` is recorded in the top-level
`active` field of `~/.claude/cc-switch.json`, so the list view can show
which model is currently active.

```bash
cc-switch activate deepseek/deepseek-chat
```

If the model is omitted and the provider has exactly one model, it is
used; if several, you are prompted to pick one.

Because the env injection only affects *new* processes, activating in the
current shell uses the export line instead:

```bash
eval "$(cc-switch activate deepseek/deepseek-chat)"
```

When stdout is piped, cc-switch writes **only** that line to stdout and
sends its status report to stderr — so the `eval` above is safe.  On a
terminal, the human-readable report is printed as usual.

### `cc-switch activate <provider-name/model-name> --custom`

Like `activate`, but lets you override each model slot first —
`ANTHROPIC_DEFAULT_HAIKU_MODEL`, `ANTHROPIC_DEFAULT_SONNET_MODEL`,
`ANTHROPIC_DEFAULT_OPUS_MODEL`, `CLAUDE_CODE_SUBAGENT_MODEL`, and
`CLAUDE_CODE_EFFORT_LEVEL` — one at a time.  Enter a value to override,
or Enter to keep the default; `-` clears a slot to an empty string.  The
main model slot (`ANTHROPIC_MODEL`) is chosen on the command line, not
here.  Overrides are one-shot: they never touch the stored provider
config.  The effort prompt accepts `low`, `medium`, `high`, `xhigh`,
`max`, or `auto`.

#### Environment variables written

| Variable | Value |
|----------|-------|
| `ANTHROPIC_BASE_URL` | The provider's base URL |
| `ANTHROPIC_MODEL` | The model chosen on the command line |
| `ANTHROPIC_DEFAULT_HAIKU_MODEL` / `_SONNET_` / `_OPUS_` | The main model (overridable with `--custom`) |
| `CLAUDE_CODE_SUBAGENT_MODEL` | The main model (overridable with `--custom`) |
| `CLAUDE_CODE_EFFORT_LEVEL` | `max` (overridable with `--custom`) |

Watch the prefix: `ANTHROPIC_` marks provider/endpoint and model-slot
variables, while harness-behaviour variables use a bare `CLAUDE_CODE_`.
There is no `ANTHROPIC_CLAUDE_CODE_*` namespace — Claude Code ignores an
unrecognised key **without warning**, so a misspelled slot is silently
inert rather than an error.  See the
[environment variables reference](https://code.claude.com/docs/en/env-vars).

### `cc-switch`

With no command, lists every configured provider/model pair, one per
line.  The currently active model is marked `(active)`:

```
deepseek/deepseek-chat
deepseek/deepseek-reasoner
scnet/scnet-1m  (active)
```

### `cc-switch list`

Shows provider metadata (base URL, API key name, models) — one block
per provider.

### `cc-switch remove <provider-name>`

Deletes a provider config.  Does not touch credstore or settings.json.

## Files

| Path | Purpose |
|------|---------|
| `~/.claude/cc-switch.json` | Provider/model shapes + the `active` spec (no secrets) |
| `~/.claude/settings.json` | Generated by `activate` |
| credstore (`DEEPSEEK_API_KEY`, …) | The actual API key values |

`CC_SWITCH_FILE` overrides the config path; the settings path can be
overridden for tests.

## Security notes

- The config file holds only metadata — the API key is referenced by name.
- `activate` reads the secret from credstore and injects it into the
  system environment as `ANTHROPIC_AUTH_TOKEN` (registry on Windows /
  shell profile on Unix), mirroring `credstore inject`; it is never
  written to settings.json.
- A provider's `extra_env` (settable via the Python API) may not contain
  `ANTHROPIC_MODEL`, `ANTHROPIC_BASE_URL`, or `ANTHROPIC_AUTH_TOKEN` —
  cc-switch owns those slots, and a secret must never reach the plaintext
  config.
- On a TTY, `activate` prints an activation hint without echoing the
  secret; when stdout is piped it emits the shell export line for `eval`,
  and every other line goes to stderr so the piped stream stays clean.
- `activate` replaces `~/.claude/settings.json` (it does not merge) — see
  the caveat in the `activate` section above.
- Restart your shell (or start a new terminal) after activating for the
  env change to take effect in the current session.
- Secrets are immutable Python `str` — cc-switch follows credstore's
  practice of `del`-ing the reference immediately after use.

## Development

Requires [uv](https://docs.astral.sh/uv/).

```bash
uv sync --locked     # create .venv with runtime + dev dependencies
uv run pytest        # run the test suite
uv run ruff check    # lint
uv run ruff format   # format
uv run pyright       # type-check
```

CI runs the suite on Windows, macOS, and Linux (`.github/workflows/ci.yml`), plus lint and type-check jobs.

### Releasing

Bump `version` in `pyproject.toml`, commit, then push a tag with the same
version:

```bash
git tag -a v0.9.13 -m "cc-switch 0.9.13" && git push origin v0.9.13
```

`.github/workflows/publish.yml` fails unless the tag matches the package
version exactly, then uploads to PyPI via trusted publishing.

## License

MIT

