# Journal des changements upstream (assnat.qc.ca)

Tracer ici toute rupture de format HTML/PDF, mise à jour d’URL ou évolution
de la politique de l’AssNat (robots.txt, conditions d’utilisation, ouverture
ou fermeture d’une API).

Format : `## YYYY-MM-DD` puis liste à puces. Lier la fixture mise à jour si
applicable.

---

## 2026-05-02 — audit initial des sources

- Audit complet de `assnat.qc.ca` pour Phase 1.
- Fixtures réelles déposées dans `tests/fixtures/{deputes,votes,journal,calendrier,robots}/`.
- Documentation par source créée :
  [`_global.md`](sources/_global.md), [`deputes.md`](sources/deputes.md),
  [`votes.md`](sources/votes.md), [`journal.md`](sources/journal.md),
  [`calendrier.md`](sources/calendrier.md).
- **Constats clés** :
  - **Députés** : annuaire et fiches en HTML statique → scrapable
    (`httpx` + `selectolax`). ✅
  - **Votes nominaux**, **Journaux des débats**, **Séances** : index
    rendus via postback ASP.NET WebForms ; pas d’endpoint JSON public
    (et `/json/` interdit par `robots.txt`). ⚠️
  - Énumération séquentielle des IDs de votes testée (`1`, `1000`, …,
    `500000`) : tous 404. Les IDs ne sont pas séquentiels simples.
  - Trois pistes ouvertes pour débloquer votes/journal/séances : reverse
    du postback, headless browser ponctuel, ou demande officielle à
    `donneesouvertes@assnat.qc.ca`. **Aucune tranchée.**
- **Données Québec** (`assemblee-nationale-du-quebec`) :
  - 3 datasets CSV publics : projets de loi, commissions, circonscriptions.
  - **Pas** de jeu de données pour députés / votes / débats.
  - Licence **CC-BY-NC 4.0** — tension avec la cible CC BY 4.0 du
    README pour les données dérivées Voix.qc. À arbitrer.
- **Méthodologie** (`docs/methodologie.md`) :
  - Définition `P1` (présence aux votes nominaux) adoptée provisoirement.
  - Définition formelle de la dissidence actée (caucus de référence =
    majorité du parti par vote ; `non comparable` en cas d’égalité ou
    d’indépendant).

### Action mainteneur

- Trancher les trois pistes votes/journal (cf. `sources/votes.md`).
- Envoyer un courriel à `donneesouvertes@assnat.qc.ca` pour demander un
  format ouvert sur votes nominaux et débats. Tracer la réponse ici.
- Trancher l’arbitrage de licence (CC BY vs CC-BY-NC pour les données
  dérivées intégrant ou non les CSV Données Québec).
