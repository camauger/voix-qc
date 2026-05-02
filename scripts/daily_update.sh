#!/usr/bin/env bash
# Cycle quotidien : scrape, analytics, rebuild statique (à compléter).
set -euo pipefail
cd "$(dirname "$0")/.."
# shellcheck source=/dev/null
source .venv/bin/activate
# python -m voix.cli scrape deputes
# python -m voix.cli scrape votes --since yesterday
# python -m voix.cli scrape journal --since yesterday
# python -m voix.cli analytics rebuild
# python scripts/rebuild_static.py
echo "daily_update : commandes commentées jusqu'à implémentation du CLI scrape."
