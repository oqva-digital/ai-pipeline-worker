#!/bin/bash
# AI Pipeline Worker - Setup script (apenas configuração e variáveis de ambiente).
# Não embute código fonte; usa os arquivos versionados do repositório.
# Uso: ./setup.sh [comando docker compose...]   ex: ./setup.sh up -d

set -e
cd "$(dirname "$0")"

if [ ! -f .env ]; then
  echo "Arquivo .env não encontrado."
  if [ -f .env.example ]; then
    cp .env.example .env
    echo "Criei .env a partir de .env.example. Edite .env com suas variáveis e execute novamente."
  else
    echo "Crie um arquivo .env com REDIS_URL, GITHUB_TOKEN e demais variáveis necessárias."
  fi
  exit 1
fi

# Carrega variáveis do .env no shell (docker compose usa o ambiente)
set -a
. ./.env
set +a

exec docker compose "$@"
