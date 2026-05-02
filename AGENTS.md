# AGENTS.md

Contexte pour assistants IA et contributeurs travaillant sur **Voix.qc**
(tracker législatif indépendant — Assemblée nationale du Québec).

## Aperçu du projet

Voix.qc structure des données publiques parlementaires (députés, votes,
Journal des débats), les rend consultables et les archive pour une usage
journaliste/chercheur/citoyen. **Pas d’opinion** : faits et sources.

**Stack :** Python 3.12+, Flask (API), SQLite + FTS5 en dev (README),
PostgreSQL **Neon** en production, frontend **HTML/CSS/JS vanilla** sans npm,
scraping `httpx` + `selectolax`, PDF `pdfplumber` / `pymupdf`. Qualité :
`pytest`, `ruff`, `mypy --strict`.

## Architecture (résumé)

```
assnat.qc.ca → voix/scrapers + voix/parsers → BD (SQLite local | Neon prod)
                    → Flask /api/* + JSON statiques → frontend/ (Netlify)
```

- **Source de vérité :** la base (fichier SQLite locale ou Neon). Pages et exports
  sont régénérables.
- **Neon :** Postgres managé ; utiliser `VOIX_DATABASE_URL` (voir `.env.example`)
  et le groupe optionnel `pip install -e ".[neon]"`. Le schéma Postgres sera
  dérivé de `migrations/` : **ne pas** supposer une parité stricte FTS5 sans
  adaptation (ex. `tsvector` / extension pg_trgm selon choix ultérieur).
- **Netlify :** héberge le dossier `frontend/` comme site statique (`netlify.toml`).
  Netlify **ne** exécute pas Flask ni le cron de scrape ; prévoir un hôte séparé
  pour l’API et les jobs (VPS, Render, Fly, GitHub Actions + artefact, etc.) ou
  des fonctions serverless pour des endpoints limités.

### Hypothèse déploiement (Neon + Netlify)

| Composant | Où ça tourne |
|-----------|----------------|
| Pages + JS + CSS + JSON pré-générés | Netlify (`publish = frontend`) |
| Base relationnelle production | Neon (`VOIX_DATABASE_URL`) |
| Scrape, migrations lourdes, API Flask longue durée | Hors Netlify (à choisir : VPS, PaaS, CI) |

Corriger cette table dans ce fichier si tu standardises sur une autre cible
pour l’API.

## Arborescence utile (2 niveaux)

```
voix-qc/
├── voix/           # Paquet Python : config, db, scrapers, parsers, api, cli
├── frontend/       # Site statique Netlify
├── migrations/     # SQL SQLite indicatif ; Postgres Neon à versionner à part
├── scripts/        # bootstrap, daily_update, rebuild_static
├── tests/
├── docs/           # sources, méthodologie, architecture
├── pyproject.toml
├── netlify.toml
└── README.md
```

## Conventions de code

- **Français** pour commentaires et docs utilisateur quand le fichier l’est déjà ;
  noms de modules et API REST peuvent rester courts et ascii (`deputes`, `votes`).
- **Dataclasses** et **type hints** partout sur le nouveau code ; **`pathlib`**.
- **Pas de framework JS**, pas de bundler ; Chart.js en CDN avec SRI quand tu l’ajoutes.
- **Scraping :** respect `robots.txt`, délai configurable (`VOIX_RATE_LIMIT_SECONDS`),
  user-agent contact réel ; cache obligatoire avant re-parse (README).
- Éviter les dépendances nouvelles sans besoin clair ; aligner `pyproject.toml`.

## Fichiers clés

| Fichier | Rôle |
|---------|------|
| `voix/config.py` | `pydantic-settings`, préfixe `VOIX_` |
| `voix/db.py` | Connexion / migrations — brancher SQLite vs Neon |
| `voix/cli.py` | Typer : `serve`, `db init`, futurs `scrape`, `analytics` |
| `voix/api/app.py` | Factory Flask |
| `migrations/001_initial.sql` | Schéma SQLite de départ |
| `netlify.toml` | Publication statique |
| `.env.example` | Variables incluant Neon et URL API publique |

## Développement

```bash
python -m venv .venv
source .venv/bin/activate   # ou .venv\Scripts\activate sous Windows
pip install -e ".[dev]"
cp .env.example .env
pytest
ruff check . && ruff format --check .
mypy voix
python -m voix.cli serve --port 8080
```

Frontend local :

```bash
cd frontend && python -m http.server 8000
```

## Tâches fréquentes

**Ajouter une route API**

1. Étendre `voix/api/app.py` ou créer `routes_*.py` et enregistrer le blueprint.
2. Documenter dans README section API si contrat public.
3. Tester avec `app.test_client()` dans `tests/`.

**Préparer un déploiement Netlify**

1. Vérifier que `frontend/` sert correctement avec des chemins relatifs.
2. Définir `VOIX_PUBLIC_API_BASE_URL` côté build ou injecter `window.__VOIX_API_BASE__`
   si besoin d’un domaine API distinct.
3. Activer les redirections proxy dans `netlify.toml` une fois l’URL API connue.

**Brancher Neon**

1. Créer le projet sur Neon, copier l’URL (`sslmode=require`).
2. `pip install -e ".[neon]"` sur l’environnement qui applique les migrations.
3. Ajouter/appliquer les migrations Postgres ; faire pointer `VOIX_DATABASE_URL`.
4. Adapter `voix/db.py` et les requêtes (FTS, types) — ne pas casser le chemin SQLite dev sans fallback clair.

## Contraintes et pièges

- Le README dit explicitement **pas de scraping concurrent** : un flux séquentiel.
- **Ne pas commit** `data/voix.db`, `data/cache/`, `.env` (voir `.gitignore`).
- L’API Flask en `debug=True` est pour le dev uniquement ; production : gunicorn
  ou équivalent sur l’hôte choisi.
- Netlify seul ne remplace pas un serveur d’API pour tout le périmètre README ;
  si tu restes 100 % Netlify, il faudra limiter les fonctionnalités dynamiques ou
  utiliser des fonctions serverless + Neon pour les endpoints concernés.

## Directives pour assistants IA

- Lire `README.md` et ce fichier avant des changements larges.
- Ne pas introduire React, npm, ou FastAPI sauf décision explicite du mainteneur.
- Pour toute modification du schéma : mettre à jour `migrations/` **et** prévoir
  l’équivalent Neon / notes dans `docs/`.
- Après une feature : `pytest`, `ruff`, `mypy` doivent passer.
- Les fichiers `docs/sources/*.md` doivent refléter les URL et fixtures réelles ;
  ne pas inventer d’endpoints assnat.qc.ca sans vérification humaine.
