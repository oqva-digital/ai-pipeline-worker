# AI Pipeline Worker

Worker that consumes jobs from a Redis queue and runs skills with Claude Code CLI in Docker containers.

**Versioning:** use the files in this repository (versioned). Do not use scripts that embed source code (e.g. a `worker.sh` that generates `worker.js`/Docker on the fly) — they get outdated. Here `setup.sh` and `install-deps.sh` handle dependencies, `.env`, and Docker Compose; the code lives in the repo files.

**Supported:** macOS (including Apple Silicon) and Linux (e.g. Ubuntu/Debian).

## Prerequisites (installed/set up by `install-deps.sh` if missing)

- Docker and Docker Compose
- GitHub CLI (`gh`) — used inside the container with `GITHUB_TOKEN`
- Node.js — used on host to install Claude CLI for `claude auth login`
- **Claude login:** the script runs `claude auth login` and creates `~/.claude/.credentials.json` (mounted into the container)
- **GitHub SSH:** the script creates `~/.ssh/ai_pipeline` and asks you to add the public key at https://github.com/settings/keys

## Setup

1. **Clone the repository** (or use this folder as the project root).

2. **Run setup** — it will install Docker, Docker Compose, `gh`, Node, and Claude CLI if needed; **prompt for Claude login** (browser OAuth) and **GitHub SSH key** (create key and ask you to add it to GitHub); then create `.env` from `.env.example` if missing:
   ```bash
   chmod +x setup.sh install-deps.sh
   ./setup.sh
   ```
   - **Claude:** if you are not logged in, the script runs `claude auth login` and opens the browser.
   - **GitHub:** if SSH is not set up, it creates `~/.ssh/ai_pipeline`, shows the public key, and asks you to add it at https://github.com/settings/keys.
   - **macOS:** if Docker was not installed, the script installs Docker Desktop and exits. Open Docker Desktop from Applications, wait for it to start, then run `./setup.sh` again.
   - If `.env` was created, edit it and set `REDIS_URL`, `GITHUB_TOKEN`, then run:
   ```bash
   ./setup.sh up -d
   ```

3. **Or do it step by step:**
   - Install dependencies only: `./setup.sh install` (or `./install-deps.sh`)
   - Create and edit `.env`: `cp .env.example .env` then set `REDIS_URL`, `GITHUB_TOKEN`, etc.
   - Start workers: `./setup.sh up -d`

   **Never commit `.env`** — it is in `.gitignore`.

## Using `setup.sh`

- **`./setup.sh`** — first-time: install Docker/gh if missing, ensure `.env`, then run `docker compose up -d`.
- **`./setup.sh install`** — only install dependencies (Docker, Docker Compose, `gh`).
- **`./setup.sh up -d`** — load `.env` and start containers in background.
- **`./setup.sh logs -f`** — follow logs.
- **`./setup.sh down`** — stop containers.
- **`./setup-claude.sh`** — only Claude login (when you want to re-auth or do just this step). Requires Claude CLI installed (run `./install-deps.sh` first if needed).
- **`./logout-claude.sh`** — remove Claude credentials (`~/.claude/.credentials.json` and `~/.claude.json`). Use `./logout-claude.sh --yes` to skip confirmation.

If `.env` is missing, the script copies `.env.example` to `.env` and asks you to edit and run `./setup.sh up -d` again.

## Migrating from worker.sh (script with embedded code)

If you used a single script (e.g. `worker.sh`) that created `worker.js`, Dockerfile and docker-compose in the user folder:

1. **Clone this repository** (or use the existing `ai-pipeline-worker` folder).
2. **Configure `.env`**: `cp .env.example .env` and set `REDIS_URL`, `GITHUB_TOKEN`, etc.
3. **Use `setup.sh`** instead of worker.sh: it only loads variables and calls Docker Compose — no embedded code. E.g. `./setup.sh up -d`.

This way you version the code on GitHub and on any machine you only need to clone, configure `.env` and run `./setup.sh up -d`.

## Publishing to GitHub

After cloning or creating the repository locally:

```bash
git remote add origin https://github.com/YOUR_USERNAME/ai-pipeline-worker.git
git branch -M main
git push -u origin main
```

Replace `YOUR_USERNAME/ai-pipeline-worker` with your repository URL on GitHub.
