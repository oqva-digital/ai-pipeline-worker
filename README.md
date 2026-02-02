# AI Pipeline Worker

Worker that consumes jobs from a Redis queue and runs skills with Claude Code CLI in Docker containers.

**Versioning:** use the files in this repository (versioned). Do not use scripts that embed source code (e.g. a `worker.sh` that generates `worker.js`/Docker on the fly) — they get outdated. Here `setup.sh` only handles environment variables and Docker Compose; the code lives in the repo files.

## Prerequisites

- Docker and Docker Compose
- SSH key for GitHub (e.g. `~/.ssh/ai_pipeline`) and Claude credentials at `~/.claude/.credentials.json`

## Setup

1. **Clone the repository** (or use this folder as the project root).

2. **Create the `.env` file** from the example:
   ```bash
   cp .env.example .env
   ```
   Edit `.env` and set:
   - `REDIS_URL` – Redis URL (e.g. `redis://:password@host:6379`)
   - `GITHUB_TOKEN` – GitHub token (for `gh auth`)
   - Optional: `CLAUDE_CODE_OAUTH_TOKEN`, `GOOGLE_API_KEY` if the worker needs them

   **Never commit `.env`** — it is in `.gitignore`.

3. **Start the workers** using the setup script (loads `.env` and forwards to Docker Compose):
   ```bash
   chmod +x setup.sh
   ./setup.sh up -d
   ```
   Or, if you prefer, load `.env` manually and run:
   ```bash
   docker compose up -d
   ```

## Using `setup.sh`

`setup.sh` only loads environment variables and forwards commands to Docker Compose. It does not embed source code; all code is in the versioned files.

- First run without `.env`: the script copies `.env.example` to `.env` and asks you to edit and run again.
- With existing `.env`: loads variables and runs `docker compose` with the arguments you pass.

Examples:
- `./setup.sh up -d` – start in background
- `./setup.sh logs -f` – follow logs
- `./setup.sh down` – stop containers

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
