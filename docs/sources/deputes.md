# Source — liste des députés

Audit du **2 mai 2026**. Voir aussi [`_global.md`](_global.md).

## URL canoniques

| Ressource | URL | Format | Statut |
|---|---|---|---|
| Annuaire complet | `https://www.assnat.qc.ca/fr/deputes/index.html` | HTML statique | ✅ scrapable direct |
| Fiche député | `https://www.assnat.qc.ca/fr/deputes/<slug>-<id>/index.html` | HTML statique | ✅ scrapable direct |

`<slug>` = `nom-prenom` normalisé en minuscules + tirets, accents conservés
parfois retirés (vérifier au parsing). `<id>` = entier (1 à 5 chiffres,
non strictement séquentiel).

Exemples observés :
- `/fr/deputes/abou-khalil-alice-19315/index.html`
- `/fr/deputes/bonnardel-francois-11/index.html`
- `/fr/deputes/berube-pascal-991/index.html`

## Fixtures

- [`tests/fixtures/deputes/deputes-index.html`](../../tests/fixtures/deputes/deputes-index.html) — annuaire (185 KB).
  - Contient `href="/fr/deputes/<slug>-<id>/index.html"` pour les 125 députés.
- [`tests/fixtures/deputes/depute-abou-khalil.html`](../../tests/fixtures/deputes/depute-abou-khalil.html) — profil (93 KB).
- [`tests/fixtures/deputes/depute-bonnardel.html`](../../tests/fixtures/deputes/depute-bonnardel.html) — profil second (102 KB), parti CAQ.

## Structure HTML utile

L’annuaire `deputes/index.html` contient les liens vers chaque profil (un
`<a href="/fr/deputes/...">` par député, repérables par regex
`href="/fr/deputes/[a-z-]+-\d+/index\.html"`).

Les pages-fiche (HTML serveur ASP.NET) exposent au moins :

- `<div class="enteteFicheDepute">` — bandeau supérieur (nom, parti,
  circonscription, photo).
- `<div class="tabulationFicheDepute">` (`id="ctl00_ColCentre_ContenuColonneGauche_onglets"`)
  — onglets : biographie, fonctions, etc.
- `<h2>Fonctions politiques, parlementaires et ministérielles</h2>` —
  ancrage stable pour l’historique de mandat.

Pas de microdata `itemprop=...` repérée → s’appuyer sur les classes CSS
ci-dessus + textes localisés.

## Parser cible (à implémenter en §4a du ROADMAP)

1. `voix/scrapers/deputes.py` :
   - GET `index.html`, cache.
   - Extraire la liste de couples `(slug, id)`.
   - Pour chaque profil : GET `index.html` du député, cache.
2. `voix/parsers/deputes_html.py` :
   - `selectolax` sur `enteteFicheDepute` → `nom_complet`, `parti_actuel`, `circonscription`.
   - `tabulationFicheDepute` → mandats (`debut_mandat`, `fin_mandat`).
   - URL photo si présente.
3. Validation : nombre de députés extraits ∈ [120, 130] (tolérance
   élections partielles, vacances).

## Fréquence et cycle

- **Mise à jour amont** : à chaque changement (élection partielle,
  changement de caucus, démission). Pas de calendrier régulier.
- **Cycle de scrape recommandé** : quotidien, premier appel du cycle —
  rapide (~125 fiches), permet de détecter les défections de parti.
- **Idempotence** : `INSERT OR REPLACE ON depute(id)` ; historiser les
  changements de parti dans `depute_parti_historique` si différence avec
  le dernier snapshot.

## Pièges connus

- L’ID dans l’URL **n’est pas garanti stable** entre législatures
  (à vérifier sur des fixtures de la 41e/42e si l’archive longitudinale
  devient pertinente, Phase 2).
- Pas de page « historique des députés » accessible en HTML statique —
  il faudra reconstituer côté Voix.qc à partir des snapshots quotidiens.
- Anciens parlementaires : route séparée `/fr/patrimoine/anciens-parlementaires/{id}.html`
  (cf. `_listeObjetMetierPatronUrl`). Hors Phase 1.

## Statut

✅ **Source débloquée** : peut alimenter §2 (modèles + BD) et §4a (scraper)
du `ROADMAP.md`.
