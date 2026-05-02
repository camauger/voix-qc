# Sources — règles communes (assnat.qc.ca)

Audit du **2 mai 2026**. Re-vérifier ces hypothèses dès qu’un parser tombe en
panne ; consigner toute rupture dans `docs/changelog-sources.md`.

## robots.txt

Source : `https://www.assnat.qc.ca/robots.txt`
Fixture : [`tests/fixtures/robots/robots.txt`](../../tests/fixtures/robots/robots.txt)

Interdictions à respecter (extrait — voir fichier complet) :

- `Disallow: /json/`
- `Disallow: /fr/rss/`, `Disallow: /fr/fils-rss.html`
- `Disallow: /fr/recherche/`
- `Disallow: /fr/travaux-parlementaires/journaux-debats/index-jd/recherche.html`
- `Disallow: /media/`, `Disallow: /scripts/`, `Disallow: /styles/`, `Disallow: /images/`
- `Disallow: /xslt/`, `Disallow: /soutien/`, `Disallow: /voeux/`
- Quelques `Disallow:` ciblés sur des `MediaId=...` spécifiques (à filtrer dans
  le scraper).

Aucune règle n’interdit explicitement `/fr/deputes/`, `/fr/travaux-parlementaires/`,
`/fr/travaux-parlementaires/registre-des-votes/`, ni `/fr/travaux-parlementaires/journaux-debats/`
hors la page `recherche.html`. Le périmètre Phase 1 est donc compatible.

> **Re-télécharger le `robots.txt` au début de chaque session de scrape** et
> comparer le hash à la fixture commitée. Toute divergence bloque le pipeline
> jusqu’à validation manuelle.

## Patron d’URLs (route table interne du site)

Extrait de la variable JS `_listeObjetMetierPatronUrl` présente dans
`tests/fixtures/votes/registre-votes-index.html` :

| Type métier | Patron d’URL canonique |
|---|---|
| Député | `/fr/deputes/{slug-id}/index.html` |
| Vote | `/fr/travaux-parlementaires/registre-des-votes/{id}/index.html` |
| Séance Assemblée | `/fr/travaux-parlementaires/assemblee-nationale/{id}/index.html` |
| Projet de loi | `/fr/travaux-parlementaires/projets-loi/projet-loi-{numero}.html` |
| Journal (générique) | `/fr/travaux-parlementaires/{path}.html` |
| Commission | `/fr/travaux-parlementaires/commissions/{slug}/index.html` |
| Document générique | `/fr/document/{id}.html` |

Stocker ce patron côté code (`voix/scrapers/base.py`) plutôt que de hardcoder
chaque URL. Tester contre la fixture vote en CI : si le patron change, on s’en
aperçoit immédiatement.

## Architecture côté serveur

Le site est un **ASP.NET WebForms** classique :

- Formulaires `id="aspnetForm"` avec `__VIEWSTATE` / `__EVENTVALIDATION`.
- Beaucoup d’index (votes, séances, journal) sont des **coquilles HTML
  statiques**, dont la liste centrale est chargée par **postback** (POST sur
  la même URL avec les jetons cachés).
- Aucun endpoint JSON public découvert (`/json/` est en plus interdit par
  `robots.txt`).

Conséquence pour Phase 1 : voir bloc « Plan de scraping » dans chaque doc
source. Les pages-fiche (1 député, 1 vote, 1 séance) sont en revanche
**rendues côté serveur en HTML statique** et restent scrapables avec
`httpx` + `selectolax`.

## Source officielle alternative — Données Québec

`donneesquebec.ca`, organisation `assemblee-nationale-du-quebec`, expose
**3 jeux de données CSV en accès libre** (au moment de l’audit) :

- Projets de loi (à jour législatures en cours et précédente)
- Commissions et sous-commissions
- Circonscriptions

**Licence :** **CC-BY-NC 4.0** (attribution + pas d’utilisation commerciale).
**Pas de dataset officiel** pour les députés, les votes nominaux ou le Journal
des débats. Contact officiel : `donneesouvertes@assnat.qc.ca`.

> Action recommandée (avant code de scrape lourd) : contacter
> `donneesouvertes@assnat.qc.ca` pour demander un format ouvert sur votes
> et débats. Cohérent avec la clause éthique du README (« si l’AssNat publie
> une API officielle, basculer dessus immédiatement »).
> Tracer la demande dans `docs/changelog-sources.md`.

## Tension de licence

`AGENTS.md` / `README.md` envisagent **CC BY 4.0** pour les données dérivées
Voix.qc. Si on intègre des CSV Données Québec (CC-BY-NC 4.0) dans la base
publiée, la **clause NC contamine** les données dérivées correspondantes.

Décision à arbitrer (arbitrage à inscrire dans `docs/methodologie.md`) :

- (A) Ne pas réutiliser les CSV NC ; reconstruire circonscriptions/commissions
  par scraping HTML (autorisé, contenu public). → données dérivées CC BY 4.0 propres.
- (B) Réutiliser les CSV NC et publier la base agrégée sous CC-BY-NC 4.0.
- (C) Hybride : sources NC isolées dans des tables séparées, exports
  ségrégés.

Aucune de ces options n’est tranchée : **flag pour le mainteneur**.

## Conventions de scraping (rappel)

- User-Agent : `Voix.qc bot — contact: <email réel>` (cf. `VOIX_USER_AGENT`).
- **2 secondes** minimum entre deux requêtes (`VOIX_RATE_LIMIT_SECONDS`).
- Aucun parallélisme.
- Cache **avant** parse : `data/cache/<source>/<date>/<url-hash>.<ext>`.
- `If-Modified-Since` activé quand le cache local existe.

## Inconnues bloquantes (à lever avant code de scrape)

1. **Énumération des votes** — pas d’index statique, IDs non séquentiels
   (probés `1`, `1000`, …, `500000` → tous 404). Stratégie à choisir :
   reverse-engineering du postback ASP.NET, headless browser, ou attendre une
   réponse de `donneesouvertes@assnat.qc.ca`.
2. **Énumération des séances** — idem, page `assemblee-nationale/43-2/index.html`
   est une coquille dynamique.
3. **Journaux des débats** — la page d’index par session (`/index-jd/<leg>-<session>.html`)
   est aussi dynamique. Aucun chemin direct vers une séance individuelle
   capturé pendant l’audit.

Tant que ces trois points ne sont pas tranchés, **§3 et §4 de `ROADMAP.md`
ne peuvent pas démarrer pour les sources votes/journal/calendrier**. Députés,
en revanche, est débloqué.
