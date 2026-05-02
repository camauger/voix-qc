# Source — votes nominaux

Audit du **2 mai 2026**. Voir aussi [`_global.md`](_global.md).

## URL canoniques

| Ressource | URL | Format | Statut |
|---|---|---|---|
| Index « Registre des votes » | `https://www.assnat.qc.ca/fr/travaux-parlementaires/registre-des-votes/index.html` | HTML coquille + postback ASP.NET | ⚠️ liste non scrapable directement |
| Vote individuel | `https://www.assnat.qc.ca/fr/travaux-parlementaires/registre-des-votes/<id>/index.html` | HTML statique (présumé) | ⚠️ identifiants à découvrir |
| Lexique « vote par appel nominal » | `https://www.assnat.qc.ca/fr/patrimoine/lexique/vote-par-appel-nominal.html` | HTML statique | référence |

## Fixtures

- [`tests/fixtures/votes/registre-votes-index.html`](../../tests/fixtures/votes/registre-votes-index.html)
  — la coquille (102 KB). Contient le formulaire `id="aspnetForm"` et la
  table de patronnes d’URL (`_listeObjetMetierPatronUrl`).
- **Aucune fixture de vote individuel** : voir « Inconnue bloquante » ci-dessous.

## Inconnue bloquante

Le registre est rendu via **postback ASP.NET WebForms** :

```html
<form method="post" action="/fr/travaux-parlementaires/registre-des-votes/index.html"
      id="aspnetForm"> ... </form>
```

- Aucun listing JSON ou CSV public découvert.
- Tests d’énumération séquentielle des IDs `1`, `1000`, `5000`, `10000`,
  `50000`, `100000`, `500000` → **tous 404**. Les IDs ne sont donc pas
  trivialement séquentiels.
- `robots.txt` interdit `/json/` (donc pas d’endpoint AJAX privé légitime
  à découvrir).

**Trois pistes**, à arbitrer avant §4b du `ROADMAP.md` :

1. **Reverse-engineering du postback ASP.NET** : capturer un GET initial,
   extraire `__VIEWSTATE` + `__EVENTVALIDATION`, faire le POST avec les
   filtres (date, projet de loi…). Coût : moyen ; risque : casse à chaque
   redéploiement IIS d’assnat.qc.ca.
2. **Headless browser ponctuel** (Playwright) pour énumérer les IDs et
   alimenter une table d’index. Une seule fois, ensuite scraping HTML
   statique sur chaque vote. Coût : ajoute une dépendance lourde,
   contradictoire avec « pas de bundler / stack légère » du README ; à
   utiliser seulement si (1) échoue.
3. **Demander un export officiel** à `donneesouvertes@assnat.qc.ca`. Aucun
   dataset votes/débats sur Données Québec aujourd’hui. Aligne avec la
   clause éthique du README. Coût : asynchrone (semaines), mais c’est la
   bonne option si l’AssNat répond.

> **Aucune des trois pistes n’est tranchée.** À reprendre avec le mainteneur
> avant d’écrire `voix/scrapers/votes.py`.

## Hypothèses sur la page-fiche d’un vote

À **valider** dès qu’on a une fixture réelle :

- Présence d’un sujet (titre), d’un type (motion / projet de loi / amendement),
  d’un projet de loi associé (numéro, lien `projet-loi-{numero}.html`),
  d’une date / heure, d’un résultat (`adopté` / `rejeté`).
- Liste des positions individuelles (`pour`, `contre`, `abstention`,
  `absent`, `paire`) avec lien vers la fiche député.
- Source canonique disponible en lien direct (utile pour `vote.source_url`).

## Validation métier (rappel README)

Pour chaque vote ingéré : `pour + contre + abstentions = nb membres présents`.
Lever et marquer le vote comme `inconsistant` si la somme ne tombe pas — ne
pas écraser silencieusement.

## Format

Le README mentionne une « capture des votes nominaux » potentiellement en PDF
(procès-verbaux). **Pas confirmé** par cet audit : la page individuelle d’un
vote semble être HTML, et les PDF apparaissent plutôt liés aux **séances**
complètes (procès-verbaux), pas aux votes individuels.

À reconfirmer avec une fixture réelle.

## Statut

⚠️ **Source partiellement bloquée**. Patron d’URL connu, mais pas
d’énumération possible avec la stack actuelle. Bloque §4b du `ROADMAP.md`
jusqu’à arbitrage des trois pistes ci-dessus.
