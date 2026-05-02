#!/usr/bin/env bash
# Crée l'environnement local et initialise la base (à compléter).
set -euo pipefail
cd "$(dirname "$0")/.."
python -m venv .venv
# shellcheck source=/dev/null
source .venv/bin/activate
pip install -e ".[dev]"
cp -n .env.example .env || true
python -m voix.cli db init
echo "Bootstrap terminé — éditer .env puis lancer les scrapes."
