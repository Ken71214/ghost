# Ghost

**Commit intentions, not code.**

Ghost is a CLI wrapper around Claude Code that flips the git workflow: instead of committing code, you commit *prompts*. Claude generates the artifacts; the commit captures both the intent and the output. Your git history becomes a chain of prompts + their results.

## The Idea

Code is ephemeral. Intent is permanent.

Every `ghost commit` answers: *what did I want to happen here?* Not *what bytes changed*. Each commit is reproducible from its prompt — if the code breaks, you have the exact instruction that generated it. The git log reads like a design document, not a diff summary.

```
git log --oneline

a3f2c1b  add JWT authentication middleware
7e91d4a  create user registration endpoint with email validation
2bc0f88  scaffold Express app with TypeScript and Prettier
```

Each of those is a ghost commit. Behind each message is an AI that turned words into working code, and a session ID that ties the output back to the generation.

## How It Works

```
you: ghost commit -m "add user auth with JWT"
     ↓
claude generates code → files written to working tree
     ↓
ghost detects changes → stages only new/modified files
     ↓
git commit with enriched message (prompt + model + session + file list)
```

Ghost snapshots the working tree before and after Claude runs, diffs the two, and stages only what changed. Unrelated files are never touched.

## Quick Start

```bash
git clone <this-repo>
export PATH="/path/to/ghost/bin:$PATH"

cd your-project
ghost init
ghost commit -m "create a REST API endpoint for user registration"
```

## Commands

| Command | Description |
|---|---|
| `ghost init` | Init git repo (if needed), install hook, create `.ghost/` dir |
| `ghost commit -m "prompt"` | Generate code from prompt, stage changed files, commit |
| `ghost commit --dry-run -m "prompt"` | Generate code, show what changed, don't commit |
| `ghost log` | Pretty-print ghost commit history (prompt, model, session, files) |
| `GHOST_SKIP=1 ghost commit -m "..."` | Pass-through to plain `git commit` |

### Examples

```bash
# New feature
ghost commit -m "add a login page with email/password form and client-side validation"

# Refactor
ghost commit -m "refactor the database layer to use connection pooling"

# Bug fix
ghost commit -m "fix the race condition in the payment processing queue"

# With a specific model
ghost commit --model claude-opus-4-6 -m "architect a microservices migration plan as code comments"

# Preview without committing
ghost commit --dry-run -m "add OpenAPI documentation for all endpoints"

# Manual commit (bypass ghost entirely)
GHOST_SKIP=1 ghost commit -m "bump version to 1.2.0"
```

## Commit Message Format

Every ghost commit has an enriched message body:

```
add a login page

ghost-meta
ghost-prompt: add a login page
ghost-model: claude-sonnet-4-6
ghost-session: 7f3a2b1c-4d5e-6f7a-8b9c-0d1e2f3a4b5c
ghost-files: src/pages/login.tsx,src/hooks/useAuth.ts,src/api/auth.ts
```

| Field | Description |
|---|---|
| `ghost-meta` | Marker that identifies this as a ghost commit |
| `ghost-prompt` | The exact prompt passed to Claude |
| `ghost-model` | The Claude model that generated the code |
| `ghost-session` | UUID for this generation session |
| `ghost-files` | Comma-separated list of files created or modified |

## Configuration

| Variable | Description |
|---|---|
| `GHOST_SKIP=1` | Pass-through to plain `git commit`, no Claude invocation |
| `GHOST_MODEL=<model>` | Default model (overridden by `--model`) |

| Flag | Description |
|---|---|
| `--model MODEL` | Claude model for this commit |
| `--dry-run` | Generate code but do not stage or commit |

## Requirements

- `git` 2.x+
- [`claude`](https://docs.anthropic.com/en/docs/claude-code) CLI with API access configured
- `bash` 4+
- `uuidgen` (available on macOS and most Linux distros)

## Why Intent-Based Commits?

**Code is the artifact, intent is the source of truth.**

When you read a traditional git log, you see *what* changed. With ghost, you see *why* — the actual human decision that triggered the change. A year from now, "refactor auth middleware to use dependency injection" tells you more than a diff ever will.

**Every commit is reproducible.** The prompt is preserved exactly. You can re-run any commit against a fresh checkout to see what Claude generates from the same instruction.

**The log becomes a design document.** Read `ghost log` top-to-bottom and you'll see the intent behind every architectural decision, not just the code that resulted from it.

**Diffs show what the AI decided; messages show what you asked for.** The two together give you full context: the goal and the implementation, inseparably linked.

## Running Tests

```bash
bash test/integration.sh
```

The integration test spins up a temp git repo, runs a full ghost workflow including generating and compiling a C program, and verifies all metadata fields.
