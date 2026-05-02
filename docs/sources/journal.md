# Source — Journal des débats

Audit du **2 mai 2026**. Voir aussi [`_global.md`](_global.md).

## URL canoniques

| Ressource | URL | Format | Statut |
|---|---|---|---|
| Page d’entrée | `https://www.assnat.qc.ca/fr/travaux-parlementaires/journaux-debats.html` | HTML statique | hub navigation |
| Index par législature/session | `https://www.assnat.qc.ca/fr/travaux-parlementaires/journaux-debats/index-jd/<leg>-<session>.html` (ex. `43-2.html`) | HTML coquille + postback ASP.NET | ⚠️ liste dynamique |
| Recherche dans le Journal | `https://www.assnat.qc.ca/fr/travaux-parlementaires/journaux-debats/index-jd/recherche.html` | HTML | **interdit par robots.txt** |
| Séance individuelle | inconnu — non capturé | présumé HTML | ⚠️ à découvrir |

## Fixtures

- [`tests/fixtures/journal/journaux-debats-index.html`](../../tests/fixtures/journal/journaux-debats-index.html) — page d’entrée (111 KB).
- [`tests/fixtures/journal/journal-43-2.html`](../../tests/fixtures/journal/journal-43-2.html)
  — coquille de l’index pour la **43e législature, 2e session** (111 KB,
  contenu structurel identique à la précédente : navigation, pas de liste
  réelle de séances).

## Inconnue bloquante

Comme pour les votes, la page d’index par session est une **coquille
ASP.NET** : la liste des séances et leurs URLs n’apparaît qu’après postback.

- Aucun lien direct `<a href="...">` vers une séance individuelle dans la
  fixture.
- La page de **recherche** (qui afficherait probablement les liens) est
  explicitement interdite par `robots.txt`
  (`Disallow: /fr/travaux-parlementaires/journaux-debats/index-jd/recherche.html`).
- Le patron d’URL générique pour un journal d’après le route table interne
  est `Journal:/fr/travaux-parlementaires/{path}.html` — **trop large** pour
  guider une énumération.

**Pistes** (mêmes que pour les votes — voir [`votes.md`](votes.md)) :

1. Reverse-engineering du postback ASP.NET sur l’index par session.
2. Headless browser ponctuel pour découvrir les URLs réelles d’une
   législature.
3. Demande à `donneesouvertes@assnat.qc.ca`.

> **À arbitrer avant §4c du `ROADMAP.md`.**

## Versionnement préliminaire / final

Le README impose la conservation explicite de **deux statuts** par
intervention :

- `preliminaire` (le lendemain de la séance)
- `final` (~2 semaines après)

Ce double statut doit être identifiable dans la page-fiche d’une séance
(à confirmer une fois qu’on tient une fixture). En attendant, prévoir un
champ `intervention.statut` dans le schéma (déjà présent dans
`migrations/001_initial.sql`).

## Format HTML par séance

À **valider** :

- Suite d’interventions identifiables individuellement.
- Métadonnées par intervention : nom de l’intervenant, rôle (député /
  ministre / président), ordre dans la séance, ancrage (anchor HTML).
- Texte intégral inline ou paginé.

## Pièges connus

- Le format HTML du Journal a déjà changé entre législatures (cf. README) →
  **versionner les parsers** (`journal_html_v1.py`, `..._v2.py`) et
  sélectionner par législature.
- La distinction préliminaire/final doit éviter d’écraser : conserver les
  deux versions en BD et marquer celle qui fait foi.

## Statut

⚠️ **Source bloquée** — même blocage qu’en `votes.md` (énumération
dynamique + recherche interdite par `robots.txt`). Bloque §4c du
`ROADMAP.md`.
