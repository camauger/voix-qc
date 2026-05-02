# Voix.qc

> Tracker législatif indépendant de l'Assemblée nationale du Québec.
> Votes, interventions, présences et dissidences des 125 députés —
> consultables, comparables, archivés.

**Statut :** pré-alpha — squelette Python (`voix/`), frontend minimal et CI en place ;
scrapers, parsers et routes API complètes à implémenter.
Ce README décrit l'architecture cible et la stratégie de mise en place
pour un développeur solo.

**Inspirations :** [NosDéputés.fr](https://www.nosdeputes.fr),
[OpenParliament.ca](https://openparliament.ca),
[TheyWorkForYou](https://www.theyworkforyou.com).

---

## Table des matières

1. [Vision](#vision)
2. [Périmètre Phase 1](#périmètre-phase-1)
3. [Stack technique](#stack-technique)
4. [Architecture](#architecture)
5. [Sources de données](#sources-de-données)
6. [Structure du projet](#structure-du-projet)
7. [Prérequis](#prérequis)
8. [Installation](#installation)
9. [Pipeline de données](#pipeline-de-données)
10. [Schéma de base de données](#schéma-de-base-de-données)
11. [API interne](#api-interne)
12. [Frontend](#frontend)
13. [Déploiement](#déploiement)
14. [Considérations éthiques et légales](#considérations-éthiques-et-légales)
15. [Roadmap](#roadmap)
16. [Licence](#licence)

---

## Vision

L'Assemblée nationale du Québec publie sur `assnat.qc.ca` l'intégralité
de ses débats, votes et travaux de commissions. Cette information est
techniquement accessible mais pratiquement opaque : aucune couche analytique,
aucun moteur de recherche transversal, aucun profil consolidé par député,
aucune alerte par sujet.

Voix.qc comble cette lacune avec un parti pris :

- **Faits, pas opinions.** Le site rapporte ce qui s'est dit et voté,
  jamais ce que ça « signifie ».
- **Archive longitudinale.** Chaque session conservée définitivement,
  même quand `assnat.qc.ca` change de format.
- **Format machine-friendly.** Tout ce qui s'affiche est aussi
  téléchargeable en CSV/JSON pour journalistes et chercheurs.
- **Pérennité avant fonctionnalités.** Mieux vaut un sous-ensemble
  petit qui fonctionne 10 ans qu'un grand site qui meurt en deux.

## Périmètre Phase 1

**Inclus (3 mois) :**

- Liste des 125 députés actuels avec fiches (parti, circonscription,
  commissions, dates de mandat).
- Capture des votes nominaux de la législature en cours.
- Capture du Journal des débats de la législature en cours
  (texte intégral, indexé par intervenant).
- Recherche plein-texte avec filtres (député, parti, date, type).
- Pages de profil député : présences aux votes, taux de dissidence
  par rapport au caucus, sujets dominants des interventions.

**Exclu Phase 1 :**

- Archive historique au-delà de la législature courante.
- Travaux des commissions et mémoires déposés.
- Suivi de cheminement de projets de loi.
- Alertes courriel/RSS personnalisées.
- Classification thématique automatique.

Voir [Roadmap](#roadmap) pour les phases ultérieures.

## Stack technique

Choix dictés par trois contraintes : développeur solo, pérennité
décennale, déploiement à coût marginal.

| Couche | Choix | Justification |
|---|---|---|
| Langage backend | **Python 3.12+** | Stack maîtrisée, écosystème scraping/PDF mature. |
| Scraping | `httpx` + `selectolax` | `httpx` async-ready, `selectolax` ~10× plus rapide que BeautifulSoup. |
| Parsing PDF | `pdfplumber` (fallback `pymupdf`) | `pdfplumber` pour mise en page tabulaire, `pymupdf` pour texte volumineux. |
| Stockage | **SQLite + FTS5** | Fichier unique, sauvegarde triviale, FTS5 suffit jusqu'à plusieurs Go. Pas de Postgres tant qu'il n'est pas justifié. |
| Recherche sémantique (Phase 2) | `sqlite-vec` + `sentence-transformers` | Embeddings stockés dans la même BD, modèle `paraphrase-multilingual-MiniLM-L12-v2` pour FR. |
| API | **Flask** + `flask-caching` | Plus simple que FastAPI pour un solo, async non requis ici. |
| Frontend | **HTML + CSS + JS vanilla** | Pas de build step, pas de framework, déchiffrable dans 10 ans. Chart.js pour les graphiques. |
| Tâches périodiques | `cron` + scripts CLI | Pas de Celery, pas d'Airflow. Un script idempotent + un cron. |
| Tests | `pytest` | Standard. |
| Qualité | `ruff` + `mypy --strict` | Conforme au standard du projet. |
| Doc API | OpenAPI généré statiquement | À partir des routes Flask. |

**Aucun framework JavaScript.** Aucun bundler. Aucune dépendance npm.
Le frontend doit fonctionner avec `python -m http.server` en local et
en fichiers statiques en production.

## Architecture

```
┌──────────────────────────┐
│   assnat.qc.ca           │
│   (HTML, PDF, XML)       │
└─────────────┬────────────┘
              │
              ▼  (cron quotidien)
┌──────────────────────────┐
│  voix/scrapers/          │  Récupère + cache HTML/PDF brut
│  voix/parsers/           │  Extrait structures (votes, débats)
│  voix/models/            │  Dataclasses + ORM léger
└─────────────┬────────────┘
              │
              ▼
┌──────────────────────────┐
│  voix.db                 │  SQLite + FTS5
└─────────────┬────────────┘
              │
       ┌──────┴──────┐
       ▼             ▼
┌───────────┐  ┌───────────────┐
│ Flask API │  │ Build statique │
│ /api/*    │  │ JSON snapshots │
└─────┬─────┘  └───────┬───────┘
      │                │
      └────────┬───────┘
               ▼
       ┌──────────────┐
       │  Frontend    │
       │  vanilla JS  │
       └──────────────┘
```

**Principe :** la base SQLite est le **seul** point de vérité.
Tout le reste — pages, JSON, exports CSV — est régénérable depuis
elle en quelques minutes. Si le serveur brûle, restaurer la BD
suffit.

## Sources de données

**Avertissement :** les URLs et structures de `assnat.qc.ca` doivent être
auditées avant le démarrage du code. Les patterns ci-dessous reflètent
l'état observable mais peuvent évoluer. Documente chaque endpoint
réellement utilisé dans `docs/sources.md`.

### 1. Liste des députés

- **Source :** page officielle des députés (`assnat.qc.ca`, section députés).
- **Format :** HTML (potentiellement aussi un export structuré à valider).
- **Fraîcheur :** mise à jour à chaque modification (élections partielles,
  changements de caucus).
- **Limite :** structure HTML susceptible de changer à chaque législature.

### 2. Votes nominaux

- **Source :** procès-verbaux des séances de l'Assemblée.
- **Format :** PDF par séance (à confirmer — certains contenus disponibles
  en HTML).
- **Fraîcheur :** publié 24-48h après la séance.
- **Limite :** parsing PDF fragile, exige une couche de validation
  (somme des Pour + Contre + Abstentions = membres présents).

### 3. Journal des débats

- **Source :** Journal des débats de l'Assemblée (séances plénières).
- **Format :** HTML par séance, archives complètes.
- **Fraîcheur :** version préliminaire le lendemain, version finale
  ~2 semaines après.
- **Limite :** distinguer version préliminaire vs finale ; conserver
  les deux et marquer le statut. Le format HTML a déjà changé entre
  législatures — versionner les parsers.

### 4. Calendrier et présences

- **Source :** calendrier officiel des séances + listes de présence
  publiées dans les procès-verbaux.
- **Format :** mixte HTML/PDF.
- **Limite :** la « présence » au Québec a une définition floue —
  documenter explicitement la métrique utilisée (présent au moins
  un vote dans la séance vs présent au début de séance).

### 5. Données dérivées (à construire)

- **Caucus de référence** par parti et par vote (calculé : majorité
  des élus du parti ayant voté).
- **Dissidence** : un député dissidente quand son vote diffère du
  caucus de son parti.
- **Sujets** : Phase 2, par classification automatique des
  interventions.

Chaque source doit avoir un fichier `docs/sources/<nom>.md` documentant :
URL exacte, robots.txt vérifié, fréquence de scraping, fixtures de test,
règles de re-crawl.

## Structure du projet

```
voix-qc/
├── README.md
├── LICENSE
├── pyproject.toml
├── .env.example
├── .gitignore
├── docs/
│   ├── architecture.md
│   ├── sources/
│   │   ├── deputes.md
│   │   ├── votes.md
│   │   └── journal.md
│   ├── methodologie.md      # Définitions présence, dissidence, etc.
│   └── changelog-sources.md # Trace les changements upstream
├── voix/
│   ├── __init__.py
│   ├── config.py            # Pydantic settings
│   ├── models.py            # Dataclasses : Depute, Vote, Intervention…
│   ├── db.py                # Connexion + migrations SQLite
│   ├── scrapers/
│   │   ├── __init__.py
│   │   ├── base.py          # HTTP client commun (rate limit, cache, UA)
│   │   ├── deputes.py
│   │   ├── votes.py
│   │   └── journal.py
│   ├── parsers/
│   │   ├── __init__.py
│   │   ├── votes_pdf.py
│   │   └── journal_html.py
│   ├── analytics/
│   │   ├── __init__.py
│   │   ├── presence.py
│   │   └── dissidence.py
│   ├── api/
│   │   ├── __init__.py
│   │   ├── app.py
│   │   ├── routes_deputes.py
│   │   ├── routes_votes.py
│   │   └── routes_search.py
│   └── cli.py               # Entrée principale (typer ou argparse)
├── frontend/
│   ├── index.html
│   ├── depute.html
│   ├── vote.html
│   ├── recherche.html
│   ├── css/
│   │   └── style.css
│   ├── js/
│   │   ├── api.js           # Wrapper fetch
│   │   ├── depute.js
│   │   └── recherche.js
│   └── data/                # JSON pré-calculés (Phase 1)
├── migrations/
│   └── 001_initial.sql
├── tests/
│   ├── fixtures/            # HTML/PDF d'exemple, jamais en prod
│   ├── test_parsers_votes.py
│   ├── test_parsers_journal.py
│   └── test_analytics.py
├── scripts/
│   ├── bootstrap.sh         # Crée la BD + données seed
│   ├── daily_update.sh      # Cron quotidien
│   └── rebuild_static.py    # Régénère JSON pour le frontend
└── data/
    ├── voix.db              # Pas en git
    ├── cache/               # HTML/PDF bruts, pas en git
    └── exports/             # CSV pour téléchargement public
```

## Prérequis

- Python 3.12 ou supérieur
- SQLite 3.38+ (pour FTS5 récent et JSON1)
- ~5 Go d'espace disque (cache HTML/PDF de la législature courante)
- Optionnel Phase 2 : 8 Go RAM minimum si embeddings locaux

## Installation

```bash
git clone https://github.com/<toi>/voix-qc.git
cd voix-qc

python -m venv .venv
source .venv/bin/activate    # Linux/macOS
# .venv\Scripts\activate     # Windows

pip install -e ".[dev]"

cp .env.example .env
# Éditer .env (User-Agent, chemin de la BD, etc.)

# Initialiser la BD
python -m voix.cli db init

# Premier scrape (peut prendre 30-60 min selon volume)
python -m voix.cli scrape deputes
python -m voix.cli scrape votes --since 2022-10-03
python -m voix.cli scrape journal --since 2022-10-03

# Calculs dérivés
python -m voix.cli analytics rebuild

# Servir l'API en local
python -m voix.cli serve --port 8080
```

Frontend en local (sans build) :

```bash
cd frontend
python -m http.server 8000
# Ouvrir http://localhost:8000
```

Variables d'environnement minimales (`.env`) :

```bash
VOIX_DB_PATH=./data/voix.db
VOIX_CACHE_DIR=./data/cache
VOIX_USER_AGENT="Voix.qc bot — contact: ton@courriel.qc.ca"
VOIX_RATE_LIMIT_SECONDS=2
VOIX_API_HOST=127.0.0.1
VOIX_API_PORT=8080
```

## Pipeline de données

Trois principes non négociables.

**1. Tout cacher localement.** Chaque réponse HTTP est sauvegardée
brute dans `data/cache/<source>/<date>/<url-hash>.html` ou `.pdf`.
Si `assnat.qc.ca` retire un contenu, on l'a encore. Si le parser
plante après 6 mois, on rejoue sur le cache sans re-télécharger.

**2. Idempotence.** Tous les scripts CLI peuvent être relancés sans
duplication. Insertions par `INSERT OR REPLACE` sur clés naturelles
(numéro de séance + numéro de vote, par exemple).

**3. Re-parser n'est pas re-scraper.** Bug dans le parser de votes ?
On relance `voix.cli reparse votes`, qui consomme uniquement le
cache local. Aucun appel réseau.

### Cycle quotidien (cron)

```cron
# Tous les jours à 06h00 — laisse le temps à l'AssNat de publier
0 6 * * * /home/voix/voix-qc/scripts/daily_update.sh >> /var/log/voix-qc.log 2>&1
```

`daily_update.sh` enchaîne : `scrape deputes` (rapide, détecte
changements de caucus), `scrape votes --since hier`,
`scrape journal --since hier`, `analytics rebuild`,
`rebuild_static`.

### Rate limiting

Strictement 2 secondes entre requêtes vers `assnat.qc.ca`. User-Agent
identifiable avec courriel de contact. Respect de `robots.txt`. Cache
HTTP avec `If-Modified-Since`. **Jamais** de scraping concurrent —
un seul thread, du début à la fin.

## Schéma de base de données

Schéma SQLite indicatif (à raffiner selon les sources réelles).

```sql
CREATE TABLE depute (
    id              INTEGER PRIMARY KEY,
    nom_complet     TEXT NOT NULL,
    nom_recherche   TEXT NOT NULL,        -- Normalisé (sans accents, lower)
    parti_actuel    TEXT,                 -- Code court : CAQ, PLQ, QS, PQ…
    circonscription TEXT NOT NULL,
    region          TEXT,
    debut_mandat    DATE NOT NULL,
    fin_mandat      DATE,                 -- NULL si en poste
    photo_url       TEXT,
    bio_assnat_url  TEXT
);

CREATE TABLE depute_parti_historique (
    depute_id  INTEGER REFERENCES depute(id),
    parti      TEXT NOT NULL,
    debut      DATE NOT NULL,
    fin        DATE,
    motif      TEXT,                      -- 'élection', 'expulsion', 'défection'…
    PRIMARY KEY (depute_id, debut)
);

CREATE TABLE seance (
    id          INTEGER PRIMARY KEY,
    date        DATE NOT NULL,
    legislature INTEGER NOT NULL,
    session     INTEGER NOT NULL,
    numero      INTEGER NOT NULL,         -- Numéro dans la session
    type        TEXT,                     -- 'pleniere', 'commission'
    UNIQUE (legislature, session, numero)
);

CREATE TABLE vote (
    id              INTEGER PRIMARY KEY,
    seance_id       INTEGER REFERENCES seance(id),
    sujet           TEXT NOT NULL,
    description     TEXT,
    type            TEXT,                 -- 'projet_loi', 'motion', 'amendement'…
    projet_loi_id   TEXT,                 -- Numéro de PL si applicable
    resultat        TEXT NOT NULL,        -- 'adopte', 'rejete'
    pour            INTEGER,
    contre          INTEGER,
    abstentions     INTEGER,
    timestamp       DATETIME,
    source_url      TEXT NOT NULL
);

CREATE TABLE vote_depute (
    vote_id    INTEGER REFERENCES vote(id),
    depute_id  INTEGER REFERENCES depute(id),
    position   TEXT NOT NULL,             -- 'pour', 'contre', 'abstention', 'absent', 'paire'
    PRIMARY KEY (vote_id, depute_id)
);

CREATE TABLE intervention (
    id              INTEGER PRIMARY KEY,
    seance_id       INTEGER REFERENCES seance(id),
    depute_id       INTEGER REFERENCES depute(id),
    ordre_seance    INTEGER NOT NULL,
    role            TEXT,                 -- 'depute', 'ministre', 'president'…
    texte           TEXT NOT NULL,
    nb_mots         INTEGER NOT NULL,
    source_url      TEXT NOT NULL,
    statut          TEXT NOT NULL         -- 'preliminaire', 'final'
);

-- Recherche plein-texte (FTS5)
CREATE VIRTUAL TABLE intervention_fts USING fts5(
    texte,
    content='intervention',
    content_rowid='id',
    tokenize='unicode61 remove_diacritics 2'
);

-- Triggers de synchro intervention <-> intervention_fts (à compléter)

CREATE INDEX idx_vote_seance ON vote(seance_id);
CREATE INDEX idx_intervention_depute ON intervention(depute_id);
CREATE INDEX idx_intervention_seance ON intervention(seance_id);
```

Migrations versionnées dans `migrations/`, appliquées par
`voix.cli db migrate`.

## API interne

Conventions : JSON, REST minimaliste, pagination par `limit`/`offset`,
réponses cachées 1h par `flask-caching`.

| Méthode | Route | Description |
|---|---|---|
| GET | `/api/deputes` | Liste tous les députés (filtres `parti`, `region`). |
| GET | `/api/deputes/<id>` | Fiche complète + statistiques agrégées. |
| GET | `/api/deputes/<id>/votes` | Historique de votes. |
| GET | `/api/deputes/<id>/interventions` | Interventions, paginé. |
| GET | `/api/votes` | Liste de votes (filtres `depuis`, `jusqu_a`, `parti`). |
| GET | `/api/votes/<id>` | Détail d'un vote + ventilation par député. |
| GET | `/api/seances` | Calendrier des séances. |
| GET | `/api/recherche?q=…` | Recherche plein-texte sur interventions. |
| GET | `/api/exports/votes.csv` | Export CSV de tous les votes. |
| GET | `/api/exports/deputes.csv` | Export CSV des députés. |

OpenAPI servi à `/api/openapi.json`. Documentation Swagger statique
à `/api/docs`.

## Frontend

Cinq pages HTML, pas plus en Phase 1.

- `index.html` — actualité (3 derniers votes, 5 dernières séances).
- `deputes.html` — annuaire avec filtres (parti, région).
- `depute.html?id=…` — profil : présences, dissidence, sujets,
  derniers votes, dernières interventions.
- `vote.html?id=…` — détail d'un vote, carte/graphique des positions.
- `recherche.html` — moteur de recherche transversal.

Stratégie : la majorité du contenu vient de **JSON pré-calculés**
servis statiquement (frontend/data/), pour les pages stables.
Seule la recherche et le détail vote/député tapent l'API. Cache
agressif côté navigateur.

CSS : variables custom, fluid type, mobile-first, sans framework.
Une seule feuille `style.css`, ~600 lignes maximum.

JS : modules ES6, pas de bundler. Chaque page charge uniquement
son module. Chart.js via CDN avec SRI.

Accessibilité : niveau AA visé. Sémantique HTML stricte, navigation
au clavier complète, contrastes AAA pour le texte courant.

## Déploiement

**Cible retenue pour ce dépôt :** [Neon](https://neon.tech) (PostgreSQL) pour
la base en production, [Netlify](https://www.netlify.com) pour le site statique
(`frontend/`). Voir `netlify.toml`, `.env.example` et `AGENTS.md` pour les
variables et l’hébergement de l’API (Flask) et des jobs de scrape, qui
ne tournent pas sur Netlify.

Le projet doit pouvoir vivre sur un VPS à ~5 $/mois (1 vCPU, 1 Go RAM,
20 Go disque). Cibles testées :

- **Production minimale :** Hetzner CX11 / OVH VPS Starter, Debian 12,
  nginx + gunicorn + cron.
- **Alternative statique :** la majorité du site générable en statique
  (Netlify, Cloudflare Pages, GitHub Pages), seule l'API recherche
  hébergée en VPS.

Sauvegardes : `voix.db` répliqué quotidiennement vers stockage objet
S3-compatible (Backblaze B2, Wasabi). Restic ou Litestream pour
SQLite spécifiquement. **Tester** la restauration une fois par mois.

DNS : `voix.qc` (à acquérir), TLS via Let's Encrypt + certbot.

## Considérations éthiques et légales

**Scraping respectueux.** Rate limiting, User-Agent identifiable,
respect du `robots.txt`. Si l'AssNat publie une API officielle ou
un format ouvert, basculer dessus immédiatement.

**Données ouvertes.** Le contenu de l'AssNat est de l'information
publique, mais le travail de structuration est protégeable.
Publier la base de données dérivée sous **CC BY 4.0** ou
**ODbL 1.0** pour permettre la réutilisation tout en exigeant
attribution.

**Diffamation.** Le site rapporte des faits — votes, mots prononcés,
présences. Aucune interprétation, aucune accusation. Lien direct
vers la source officielle (`source_url`) sur **chaque** donnée.
Mécanisme de signalement d'erreur visible.

**Données personnelles.** Les députés sont des personnalités publiques
agissant dans le cadre de leur fonction publique. Aucune donnée
personnelle hors fonction n'est collectée. Aucun cookie de tracking,
aucun analytics tiers. Logs d'accès anonymisés à 7 jours.

**Code de conduite.** Les contributeurs adhèrent au [Contributor
Covenant](https://www.contributor-covenant.org/) v2.1.

## Roadmap

> Checklist d’implémentation détaillée (étapes ordonnées par dépendance) : voir [`ROADMAP.md`](docs/ROADMAP.md).

### Phase 1 — Fondations (3 mois)

Voir [Périmètre Phase 1](#périmètre-phase-1). Livrable : site public
fonctionnel sur la législature courante.

### Phase 2 — Profondeur (6 mois)

- Archive 10 ans : législatures 41 (2014) à courante.
- Recherche sémantique par embeddings.
- Alertes courriel et flux RSS personnalisés (par député, par sujet).
- Classification thématique automatique des interventions
  (économie, santé, environnement, langue, etc.).
- Export Parquet pour analyses externes.
- API publique documentée et versionnée.

### Phase 3 — Croisements (long terme)

- Suivi cheminement des projets de loi (premier dépôt → sanction).
- Travaux des commissions parlementaires + mémoires déposés.
- Croisement avec InfluencesQC (donations DGEQ, lobby) — qui a financé
  les députés ayant voté pour ce PL ?
- Comparaisons inter-législatives, mesure de polarisation.
- Outil pédagogique pour cours de science politique (collège, université).

## Licence

- **Code :** AGPL-3.0 — le code reste libre, les forks aussi.
- **Données dérivées :** CC BY 4.0 (ou ODbL 1.0 — à arbitrer).
- **Documentation :** CC BY 4.0.

Voir [LICENSE](LICENSE) et [LICENSE-DATA](LICENSE-DATA).

## Contact

Issues GitHub pour bugs et propositions techniques.
Pour signalement d'erreur factuelle : courriel dédié à venir
(politique de correction sous 72h).

---

*Voix.qc n'est ni affilié à l'Assemblée nationale du Québec ni à
aucun parti politique. C'est un projet civique indépendant.*