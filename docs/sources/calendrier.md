# Source — calendrier des travaux et séances

Audit du **2 mai 2026**. Voir aussi [`_global.md`](_global.md).

> Cette source n’est pas listée explicitement dans le README initial mais
> apparaît dans `ROADMAP.md` §1 (« calendrier ») et conditionne la table
> `seance` du schéma SQLite.

## URL canoniques

| Ressource | URL | Format | Statut |
|---|---|---|---|
| Calendrier des travaux parlementaires | `https://www.assnat.qc.ca/fr/travaux-parlementaires/calendrier-travaux.html` | HTML coquille + postback ASP.NET | ⚠️ contenu dynamique |
| Index « Assemblée nationale » | `https://www.assnat.qc.ca/fr/travaux-parlementaires/assemblee-nationale/index.html` | HTML coquille | ⚠️ |
| Index séances par législature/session | `https://www.assnat.qc.ca/fr/travaux-parlementaires/assemblee-nationale/<leg>-<session>/index.html` (ex. `43-2`) | HTML coquille | ⚠️ |
| Séance individuelle | `/fr/travaux-parlementaires/assemblee-nationale/{id}/index.html` (patron — `{id}` ≠ `<leg>-<session>`) | HTML statique présumé | ⚠️ |

## Fixtures

- [`tests/fixtures/calendrier/calendrier-travaux.html`](../../tests/fixtures/calendrier/calendrier-travaux.html) (70 KB)
- [`tests/fixtures/calendrier/travaux-index.html`](../../tests/fixtures/calendrier/travaux-index.html) — page parente `/fr/travaux-parlementaires/index.html` (94 KB)
- [`tests/fixtures/calendrier/assemblee-index.html`](../../tests/fixtures/calendrier/assemblee-index.html) (121 KB)
- [`tests/fixtures/calendrier/assemblee-43-2.html`](../../tests/fixtures/calendrier/assemblee-43-2.html) (121 KB) — coquille pour la session courante 43-2.

## Sessions historiques observables

Sur `assemblee-index.html` on capture (en clair, dans des `<a>`) les sessions
plus anciennes : `11-4`, `12-1` à `12-4`, `13-1` à `13-4`, … jusqu’à la
session courante `43-2`. La liste sert au moins de **table d’index des
législatures** sans appel dynamique.

```text
/fr/travaux-parlementaires/assemblee-nationale/11-4/index.html
/fr/travaux-parlementaires/assemblee-nationale/12-1/index.html
...
/fr/travaux-parlementaires/assemblee-nationale/43-2/index.html
```

## Inconnue bloquante

Identique aux votes/journal : la **liste des séances** d’une session
n’est pas dans le HTML statique des index ; un postback ASP.NET est requis.

À résoudre conjointement avec votes.md et journal.md (§4b–§4c du ROADMAP).

## Définition « présence »

**Décision pendante** (à graver dans `docs/methodologie.md`) — deux
définitions concurrentes :

- (P1) **Présent au moins à un vote nominal** dans la séance.
- (P2) **Présent au début de séance** (signaling officiel de l’AssNat
  s’il existe — non confirmé par cet audit).

Avantage P1 : entièrement reconstructible à partir des votes nominaux,
sans dépendance à un signalement officiel. Inconvénient : sous-estime la
présence (un député présent à des débats sans aucun vote nominal sera
classé absent).

P2 demande une source officielle de présence ; à ce stade pas trouvée.

> Recommandation provisoire : adopter P1 et **documenter explicitement la
> métrique sur chaque page** (« présence aux votes nominaux »). Réviser si
> P2 devient récupérable.

## Statut

⚠️ **Source partiellement bloquée**. Les sessions historiques sont
listables ; les séances individuelles non, sans postback ASP.NET.
