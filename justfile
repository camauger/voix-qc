# Voix.qc — task runner (https://github.com/casey/just)
#
# Recettes alignées sur AGENTS.md et README.md.
# Pointe directement sur .venv ; pas besoin d'activer le venv au préalable.
# `system_python` (pour créer le venv) reste surchargeable :
#   `just system_python=py -3.12 venv`

set shell := ["bash", "-cu"]
set dotenv-load := true

system_python := "python"
python := if os_family() == "windows" { ".venv/Scripts/python.exe" } else { ".venv/bin/python" }

# Liste les recettes (par défaut)
default:
    @just --list

# --- Environnement ---

# Crée .venv (Python ≥ 3.12). Utilise `system_python` (override possible).
venv:
    {{system_python}} -m venv .venv
    @echo "Venv créé. Les recettes pointent déjà sur {{python}} — pas besoin d'activer."
    @echo "Activation manuelle (optionnelle) : source .venv/Scripts/activate (bash) | .venv\\Scripts\\Activate.ps1 (pwsh)"

# Installe le projet en mode éditable + extras dev
install:
    {{python}} -m pip install -U pip
    {{python}} -m pip install -e ".[dev]"

# Ajoute l'extra Neon (psycopg)
install-neon:
    {{python}} -m pip install -e ".[neon]"

# --- Qualité ---

# Lance pytest
test:
    {{python}} -m pytest

# Ruff lint
lint:
    {{python}} -m ruff check .

# Ruff format (écrit)
fmt:
    {{python}} -m ruff format .

# Ruff format (vérifie sans écrire — équivalent CI)
fmt-check:
    {{python}} -m ruff format --check .

# Mypy strict sur le paquet voix
typecheck:
    {{python}} -m mypy voix

# Combo CI : lint + format check + typecheck + tests
check: lint fmt-check typecheck test

# --- Exécution ---

# API Flask en local (port défaut 8080)
serve:
    {{python}} -m voix.cli serve

# Frontend statique (port 8000) — Ctrl+C pour quitter
serve-frontend:
    cd frontend && {{python}} -m http.server 8000

# Initialise la BD locale (SQLite ou Neon selon VOIX_DATABASE_URL)
db-init:
    {{python}} -m voix.cli db init

# --- Nettoyage ---

# Supprime caches Python / ruff / mypy / pytest (laisse .venv et data/)
clean:
    rm -rf .pytest_cache .mypy_cache .ruff_cache
    find . -type d -name __pycache__ -prune -exec rm -rf {} +
    find . -type d -name "*.egg-info" -prune -exec rm -rf {} +
