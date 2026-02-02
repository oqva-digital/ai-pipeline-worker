# AI Pipeline Worker

Worker que consome jobs da fila Redis e executa skills com Claude Code CLI, em containers Docker.

## Pré-requisitos

- Docker e Docker Compose
- Chave SSH para GitHub (ex.: `~/.ssh/ai_pipeline`) e credenciais Claude em `~/.claude/.credentials.json`

## Configuração

1. **Clone o repositório** (ou use esta pasta como raiz do projeto).

2. **Crie o arquivo `.env`** a partir do exemplo:
   ```bash
   cp .env.example .env
   ```
   Edite `.env` e preencha:
   - `REDIS_URL` – URL do Redis (ex.: `redis://:senha@host:6379`)
   - `GITHUB_TOKEN` – token do GitHub (para `gh auth`)
   - Opcional: `CLAUDE_CODE_OAUTH_TOKEN`, `GOOGLE_API_KEY` se o worker usar

   **Nunca commite `.env`** – ele está no `.gitignore`.

3. **Suba os workers** usando o script de setup (carrega `.env` e repassa ao Docker Compose):
   ```bash
   chmod +x setup.sh
   ./setup.sh up -d
   ```
   Ou, se preferir, carregue o `.env` manualmente e rode:
   ```bash
   docker compose up -d
   ```

## Uso do `setup.sh`

O `setup.sh` só lida com variáveis de ambiente e repassa comandos ao Docker Compose. Não embute código fonte; todo o código está nos arquivos versionados.

- Primeira execução sem `.env`: o script copia `.env.example` para `.env` e pede para você editar e rodar de novo.
- Com `.env` existente: carrega as variáveis e executa `docker compose` com os argumentos passados.

Exemplos:
- `./setup.sh up -d` – sobe em background
- `./setup.sh logs -f` – acompanha os logs
- `./setup.sh down` – derruba os containers

## Publicar no GitHub

Depois de clonar ou criar o repositório localmente:

```bash
git remote add origin https://github.com/SEU_USUARIO/ai-pipeline-worker.git
git branch -M main
git push -u origin main
```

Substitua `SEU_USUARIO/ai-pipeline-worker` pela URL do seu repositório no GitHub.
