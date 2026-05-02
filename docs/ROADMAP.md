# Roadmap opérationnel — Voix.qc

Checklist d’implémentation par ordre de dépendance. Coche au fur et à mesure.
Vue stratégique (phases en mois) : voir la section *Roadmap* du `README.md`.

Convention :
- `[x]` fait, `[ ]` à faire, `[~]` partiel.
- Chaque section se termine par un **livrable vérifiable**.
- Ne pas sauter d’étape vers le bas sans avoir validé le livrable au-dessus
  (ex. ne pas écrire d’API tant que la BD ne contient rien de réel).

---

## 0. Squelette du dépôt

- [x] `pyproject.toml`, `voix/`, `frontend/`, `migrations/`, `scripts/`, `tests/`, `docs/`.
- [x] `.gitignore`, `.env.example`, `LICENSE` (AGPL-3.0), `LICENSE-DATA` (CC BY 4.0), `NOTICE`.
- [x] `AGENTS.md` (contexte IA + conventions).
- [x] CI GitHub Actions : `ruff` + `mypy` + `pytest`.
- [x] `voix/cli.py` (`voix --help`, `voix serve`, `voix db init`).
- [x] `voix/api/app.py` avec `/api/health` + test smoke.
- [x] `netlify.toml` (publication `frontend/`).
- **Livrable :** `pip install -e ".[dev]"` puis `pytest && ruff check . && mypy voix` passent.

## 1. Audit des sources avant tout code de scrape

> Bloquant : sans ça, on écrit des parsers qui supposent des structures fausses.

- [x] Vérifier `https://www.assnat.qc.ca/robots.txt` ; documenter dans `sources/_global.md` (fixture : `tests/fixtures/robots/`).
- [~] Pour **chaque source** (députés, votes, journal, calendrier) :
  - [x] Identifier l’URL canonique (HTML, PDF, ou export structuré s’il existe).
  - [~] Sauvegarder 2–3 fixtures réelles dans `tests/fixtures/<source>/`.
    - Députés : 3 fixtures (annuaire + 2 profils). ✅
    - Votes / Journal / Séances : seulement les **coquilles d’index** (postback ASP.NET) ; pas de fixture page-fiche tant que l’énumération n’est pas débloquée.
  - [x] Confirmer la fréquence de mise à jour observable.
  - [x] Remplir `sources/<source>.md` (URL, format, robots, fixtures, règles de re-crawl).
- [x] Confirmer la définition retenue de **présence** et de **dissidence** dans `methodologie.md` (présence `P1` provisoire ; dissidence actée).
- **Livrable :** un fichier markdown par source + un dossier de fixtures non vides. ✅
### Inconnues bloquantes (à lever avant §3–§4 pour votes / journal / séances)

> **Députés : ✅ débloqué.** Annuaire + fiches en HTML statique, scrapable
> avec `httpx` + `selectolax` (cf. `sources/deputes.md`). Les blocages
> ci-dessous concernent **uniquement** votes, journal et séances.

#### B1 — Énumération impossible des votes

- **Symptôme :** la page d’index `/fr/travaux-parlementaires/registre-des-votes/index.html`
  est une **coquille HTML** ; la liste réelle des votes est rendue par
  postback ASP.NET WebForms (formulaire `id="aspnetForm"` avec
  `__VIEWSTATE` / `__EVENTVALIDATION`).
- **Test négatif :** énumération séquentielle des IDs `1`, `1000`, `5000`,
  `10000`, `50000`, `100000`, `500000` → **tous 404**. Les IDs ne sont
  donc pas trivialement incrémentaux.
- **Aucun endpoint JSON public** : `robots.txt` interdit `/json/`, donc
  pas d’API privée légitime à découvrir.
- **Impact ROADMAP :** bloque §4b (scraper votes) et indirectement §5
  (analytics dissidence) tant que la liste de votes n’est pas accessible.
- **Détail :** `sources/votes.md`.

#### B2 — Pattern URL « vote individuel » non vérifié

- **Symptôme :** le patron `/fr/travaux-parlementaires/registre-des-votes/<id>/index.html`
  est extrait du route table interne JS (`_listeObjetMetierPatronUrl`)
  mais **aucun ID valide n’a été obtenu**, donc aucune fixture page-fiche
  n’existe.
- **Conséquence :** la structure HTML d’une page de vote (sujet, type,
  positions individuelles, lien vers projet de loi) reste **hypothétique**.
  Le parser de §4b ne peut être conçu sans ça.
- **Lien avec B1 :** se résout dès que B1 est levé.

#### B3 — Énumération impossible des séances

- **Symptôme :** identique à B1 — `/fr/travaux-parlementaires/assemblee-nationale/<leg>-<session>/index.html`
  est une coquille. La liste des séances individuelles n’apparaît qu’après
  postback.
- **Ce qui marche quand même :** la liste des **sessions** historiques
  (`11-4` → `43-2`) est, elle, en HTML statique.
- **Impact ROADMAP :** bloque la table `seance` et donc l’ancrage temporel
  des votes et interventions.
- **Détail :** `sources/calendrier.md`.

#### B4 — Énumération impossible du Journal des débats

- **Symptôme :** index par session (ex. `index-jd/43-2.html`) = coquille
  ASP.NET. La page de **recherche** qui afficherait probablement les liens
  est explicitement interdite par `robots.txt`
  (`Disallow: /fr/travaux-parlementaires/journaux-debats/index-jd/recherche.html`).
- **Patron interne trop large :** `Journal:/fr/travaux-parlementaires/{path}.html`
  ne guide pas une énumération.
- **Impact ROADMAP :** bloque §4c (scraper journal) et la recherche FTS
  (§6) qui en dépend.
- **Détail :** `sources/journal.md`.

#### Pistes pour B1–B4 (à arbitrer ensemble)

1. **Reverse-engineering du postback ASP.NET.** GET initial → extraction
   `__VIEWSTATE` / `__EVENTVALIDATION` → POST sur la même URL avec
   filtres (date, parti, projet de loi). **Coût** : moyen. **Risque** :
   casse silencieuse à chaque redéploiement IIS d’assnat.qc.ca ; cible
   mouvante dans le temps.
2. **Headless browser ponctuel** (Playwright) pour énumérer les IDs et
   matérialiser une table d’index. Une seule fois par session, ensuite
   scraping HTML statique sur chaque fiche. **Coût** : ajoute Playwright
   + Chromium en dépendance — contradictoire avec la stack légère du
   README. **À utiliser seulement si (1) échoue.**
3. **Demande officielle** à `donneesouvertes@assnat.qc.ca` pour un export
   structuré des votes nominaux et du Journal. Aligne avec la clause
   éthique du README (« si l’AssNat publie une API officielle, basculer
   dessus immédiatement »). **Coût** : asynchrone (semaines), mais c’est
   la solution propre si l’AssNat répond.
- À lancer **en parallèle**, pas séquentiellement : (3) en arrière-plan,
  (1) ou (2) en attendant.

### Décisions méthodologiques pendantes (validation mainteneur)

#### D1 — Définition de la présence

- **Statut :** `P1` (présence aux votes nominaux) **adoptée provisoirement**.
- **Raison :** seule définition entièrement reconstructible sans source
  officielle, qui n’a pas été identifiée à l’audit.
- **Limite assumée :** sous-estime la présence d’un député qui assiste
  aux débats sans voter à aucun appel nominal.
- **Détail :** `methodologie.md` § Présence.

#### D2 — Licence des données dérivées

- **Tension :** Données Québec publie 3 CSV AssNat (projets de loi,
  commissions, circonscriptions) sous **CC-BY-NC 4.0**. La cible Voix.qc
  pour les exports publics est **CC BY 4.0** (README, `LICENSE-DATA`).
- **Conséquence :** ré-encapsuler ces CSV dans la base publiée
  **contamine** les données dérivées avec la clause NC.
- **Trois options** consignées dans `sources/_global.md` § Tension de
  licence (A : ne rien réutiliser ; B : tout passer en NC ; C : table
  hybride). **Aucune tranchée.**

#### D3 — Action courriel

- Envoyer à `donneesouvertes@assnat.qc.ca` la demande mentionnée en
  piste (3) ci-dessus, et **tracer la réponse dans `changelog-sources.md`**.
- Décision pendante côté mainteneur uniquement (pas un blocage technique).

## 2. Modèles métier et schéma BD

- [ ] Implémenter les `dataclass` dans `voix/models.py` :
  - [ ] `Depute`, `DeputeChangementParti`, `Seance`, `Vote`, `VoteDepute`, `Intervention`.
  - [ ] Annotations complètes ; pas de `Any`.
- [ ] `voix/db.py` :
  - [ ] Connexion SQLite (`VOIX_DB_PATH`) avec FTS5 activé.
  - [ ] Application séquentielle des fichiers `migrations/NNN_*.sql`.
  - [ ] Triggers `intervention` ↔ `intervention_fts` ajoutés à `001_initial.sql`.
- [ ] `voix db init` crée effectivement la BD avec les tables attendues.
- [ ] Tests : insertion + lecture d’un `Depute`, d’un `Vote`, d’une `Intervention`.
- **Livrable :** `voix db init` puis insertion via test → BD ouvrable, FTS répond.

## 3. Couche scraping bas niveau (`voix/scrapers/base.py`)

- [ ] Client HTTP partagé (`httpx`) avec :
  - [ ] User-Agent depuis `Settings.user_agent`.
  - [ ] Délai minimal `Settings.rate_limit_seconds` entre deux requêtes (séquentiel, pas de pool).
  - [ ] `If-Modified-Since` quand le cache local existe.
  - [ ] Sauvegarde brute dans `data/cache/<source>/<date>/<url-hash>.<ext>`.
  - [ ] Retry borné (réseau seulement, pas sur 4xx).
- [ ] Tests :
  - [ ] Cache écrit puis relu sans appel réseau (mocker `httpx`).
  - [ ] Délai respecté entre deux appels.
- **Livrable :** un `fetch(url)` réutilisable par tous les scrapers, prouvé par tests.

## 4. Scrapers + parsers par source

> Pour chaque source : scraper d’abord (cache rempli), parser ensuite (consomme le cache).

### 4a. Députés
- [ ] `voix/scrapers/deputes.py` : récupère et cache la page des 125 députés.
- [ ] `voix/parsers/deputes_html.py` (`selectolax`) → liste de `Depute`.
- [ ] CLI : `voix scrape deputes` (idempotent : `INSERT OR REPLACE`).
- [ ] Tests parser sur fixtures.

### 4b. Votes nominaux
- [ ] `voix/scrapers/votes.py` : liste les séances, télécharge PV (PDF ou HTML).
- [ ] `voix/parsers/votes_pdf.py` (`pdfplumber`, fallback `pymupdf`).
- [ ] **Validation** : `pour + contre + abstentions = nb présents`. Lever si incohérent.
- [ ] CLI : `voix scrape votes --since YYYY-MM-DD`.
- [ ] Tests sur 2–3 PV réels (votes serrés, votes unanimes, abstentions).

### 4c. Journal des débats
- [ ] `voix/scrapers/journal.py` : pages HTML par séance.
- [ ] `voix/parsers/journal_html.py` : extraction interventions (intervenant, rôle, texte, ordre).
- [ ] Distinction `preliminaire` vs `final` conservée (pas un écrasement).
- [ ] CLI : `voix scrape journal --since YYYY-MM-DD`.
- [ ] Tests sur fixtures (1 séance préliminaire + 1 finale).

- [ ] CLI utilitaire : `voix reparse <source>` consomme uniquement le cache local (pas de réseau).
- **Livrable :** après un scrape sur une fenêtre courte, la BD contient des votes + interventions cohérents avec assnat.qc.ca.

## 5. Calculs dérivés (`voix/analytics/`)

- [ ] `presence.py` : présence par député par séance (selon définition figée en §1).
- [ ] `dissidence.py` : caucus de référence par parti et par vote, écart au caucus.
- [ ] CLI : `voix analytics rebuild` (recalcul intégral, idempotent).
- [ ] Tests :
  - [ ] Cas dissidence avérée.
  - [ ] Cas absence du député.
  - [ ] Cas vote sans caucus identifiable (députés indépendants).
- **Livrable :** tables/vues `presence_*`, `dissidence_*` peuplées et requêtables.

## 6. API Flask (`voix/api/`)

- [ ] Brancher `flask-caching` (cache 1h sur GET).
- [ ] Implémenter et tester (`app.test_client()`) :
  - [ ] `GET /api/deputes` (filtres `parti`, `region`).
  - [ ] `GET /api/deputes/<id>` (fiche + agrégats).
  - [ ] `GET /api/deputes/<id>/votes`.
  - [ ] `GET /api/deputes/<id>/interventions` (paginé).
  - [ ] `GET /api/votes` (filtres date/parti).
  - [ ] `GET /api/votes/<id>` (ventilation par député).
  - [ ] `GET /api/seances`.
  - [ ] `GET /api/recherche?q=…` (FTS5).
  - [ ] `GET /api/exports/votes.csv` et `/api/exports/deputes.csv`.
- [ ] CORS limité à l’origine Netlify (`VOIX_PUBLIC_API_BASE_URL`).
- [ ] OpenAPI statique servi à `/api/openapi.json` + Swagger statique à `/api/docs`.
- **Livrable :** suite de tests API verte ; chaque route a au moins un test bonheur + un test erreur.

## 7. Génération JSON statiques (`scripts/rebuild_static.py`)

- [ ] Écrire dans `frontend/data/` :
  - [ ] `deputes.json` (annuaire complet).
  - [ ] `seances_recentes.json` (5 dernières).
  - [ ] `votes_recents.json` (3 derniers).
  - [ ] Un fichier `depute-<id>.json` par député (option, sinon API).
- [ ] Idempotent ; régénération complète en quelques secondes.
- **Livrable :** `frontend/` est navigable sans serveur API tant qu’on ne sort pas des pages stables.

## 8. Frontend (5 pages, vanilla)

- [x] `index.html` (placeholder).
- [ ] `deputes.html` — annuaire avec filtres parti/région.
- [ ] `depute.html?id=…` — fiche : présences, dissidence, sujets, derniers votes/interventions, Chart.js (CDN + SRI).
- [ ] `vote.html?id=…` — détail vote + ventilation graphique.
- [ ] `recherche.html` — moteur FTS via `/api/recherche`.
- [ ] `js/api.js` : injection de `window.__VOIX_API_BASE__` (Netlify build).
- [ ] CSS : variables, fluid type, mobile-first, ≤ 600 lignes.
- [ ] Audit accessibilité : nav clavier, focus visibles, contrastes AAA texte courant, sémantique HTML.
- **Livrable :** `cd frontend && python -m http.server 8000` → toutes les pages chargent et consomment soit `data/*.json`, soit l’API locale.

## 9. Préparation déploiement Neon (PostgreSQL)

- [ ] Créer projet Neon ; conserver l’URL `sslmode=require` dans le gestionnaire de secrets.
- [ ] `pip install -e ".[neon]"` sur l’environnement qui applique les migrations.
- [ ] Créer `migrations/postgres/` avec :
  - [ ] Équivalent du schéma SQLite (types, contraintes).
  - [ ] Stratégie FTS (au choix, à arbitrer dans `architecture.md`) :
    - `tsvector` + `GIN` + `unaccent`, ou
    - `pg_trgm` pour recherche approximative.
- [ ] Adapter `voix/db.py` :
  - [ ] Si `VOIX_DATABASE_URL` est défini → `psycopg`.
  - [ ] Sinon → SQLite (chemin actuel conservé en dev).
- [ ] Tests d’intégration Postgres (CI Neon ou conteneur local) :
  - [ ] Insertions identiques à SQLite.
  - [ ] Requête de recherche équivalente à FTS5.
- **Livrable :** `voix db init` fonctionne contre une URL Neon ; suite de tests contre Postgres verte.

## 10. Hébergement de l’API et des jobs (hors Netlify)

> Netlify ne fait tourner ni Flask longue durée ni le cron de scrape.

- [ ] Choisir la cible (au choix, à figer dans `AGENTS.md`) :
  - [ ] VPS Debian 12 (nginx + gunicorn + cron), ou
  - [ ] PaaS (Render, Fly.io, Railway), ou
  - [ ] GitHub Actions cron + artefact (si l’API peut rester serverless).
- [ ] `gunicorn` configuré (`workers`, `timeout`).
- [ ] HTTPS via Let’s Encrypt (ou TLS du PaaS).
- [ ] Cron quotidien :
  ```
  0 6 * * *  /chemin/scripts/daily_update.sh >> /var/log/voix-qc.log 2>&1
  ```
- [ ] Sauvegarde quotidienne de la BD :
  - SQLite : Litestream → S3-compatible (Backblaze B2 / Wasabi).
  - Neon : snapshot natif + export logique périodique.
- [ ] **Tester** une restauration une fois.
- **Livrable :** une URL d’API publique HTTPS qui répond sur `/api/health`.

## 11. Déploiement Netlify (frontend statique)

- [ ] Connecter le dépôt à Netlify (`publish = frontend`).
- [ ] Variables d’environnement Netlify : `VOIX_PUBLIC_API_BASE_URL` = URL API §10.
- [ ] Activer le proxy `[[redirects]]` dans `netlify.toml` (`/api/*` → API).
- [ ] Vérifier les en-têtes (`X-Frame-Options`, CSP minimale).
- [ ] DNS : pointer le domaine `voix.qc` (ou autre) vers Netlify, TLS auto.
- [ ] Smoke test post-déploiement : 5 pages chargent + recherche fonctionne.
- **Livrable :** site public accessible, données réelles.

## 12. Observabilité et hygiène opérationnelle

- [ ] Logs API anonymisés ≤ 7 jours (cf. README éthique).
- [ ] Suivi minimal d’erreurs (Sentry self-hosted ou logs structurés + alerte mail).
- [ ] Page publique simple `/etat` ou `/api/health` exposée en lecture.
- [ ] Mécanisme de signalement d’erreur factuelle (formulaire ou mailto) lié dans le footer.
- [ ] Procédure de correction documentée (cible README : 72 h).
- **Livrable :** un incident de scrape laisse une trace exploitable et notifie le mainteneur.

## 13. Pré-publication

- [ ] Mention « beta » + date de dernière mise à jour visible sur chaque page.
- [ ] `CONTRIBUTING.md` minimal (issues, branches, style, tests obligatoires).
- [ ] Code de conduite (Contributor Covenant v2.1).
- [ ] Vérifier qu’aucune donnée personnelle hors fonction publique n’est exposée.
- [ ] Annonce publique uniquement après que le cycle quotidien tourne **stable 7 jours**.

---

## Hors Phase 1 (rappel)

Phases 2 et 3 (archive longitudinale, embeddings, alertes RSS, classification thématique, croisements DGEQ/lobby, etc.) sont décrites dans le `README.md`. Ne pas y toucher tant que la Phase 1 n’est pas en production stable.
