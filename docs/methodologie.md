# Méthodologie

Ce fichier fixe les **définitions** utilisées par Voix.qc et leurs
**limites**. Toute page publique appuyée sur l’une de ces métriques doit
en afficher la définition courte et lier ce document.

Décisions actées (✅) ou pendantes (⚠️) sont marquées en tête de section.

---

## Présence

**Décision : ⚠️ provisoire — `P1` adoptée à défaut.**

### Définition `P1` (provisoire — Phase 1)

Un député est compté **présent à une séance plénière de l’Assemblée** si,
et seulement si, son nom apparaît avec une position non vide dans **au
moins un vote nominal** de cette séance.

- Positions « présentes » : `pour`, `contre`, `abstention`.
- Positions « absentes » : `absent`, `paire`, `non-vote-enregistré`.

### Avantages

- Reconstructible intégralement depuis le `vote_depute` table.
- Pas de dépendance à un signal officiel de présence (qui n’a pas été
  identifié dans l’audit du 2 mai 2026 — voir `sources/calendrier.md`).

### Limites à publier sur chaque page « présence »

- Sous-estime la présence : un député qui assiste aux débats mais ne vote
  à aucun appel nominal apparaît comme absent.
- Une séance sans aucun vote nominal n’a **pas** de mesure de présence
  (à exclure du dénominateur, ne pas compter comme « tout le monde
  absent »).

### Définition `P2` (à instruire — Phase 2 si possible)

Présent dès le début de séance selon la liste de présence officielle
publiée dans le procès-verbal. Bloquée tant que la source officielle
n’est pas confirmée.

---

## Dissidence

**Décision : ✅ — définition unique pour Phase 1.**

### Caucus de référence (par parti et par vote)

Pour un vote `v` et un parti `p` :

1. Soit `V(v, p)` l’ensemble des députés du parti `p` ayant exprimé une
   position **non absente** au vote `v` (positions `pour` / `contre` /
   `abstention`).
2. Le **caucus de référence** est la **position majoritaire** parmi
   `V(v, p)`. En cas d’égalité stricte (ex. 5 pour / 5 contre) : aucune
   référence pour ce vote, dissidence non calculée pour ce parti sur ce
   vote.
3. Les députés **indépendants** (pas de parti enregistré au moment du
   vote) n’ont pas de caucus de référence ; leurs votes ne génèrent ni
   dissidence ni alignement.

### Dissidence individuelle

Un député `d` du parti `p` est en **dissidence** sur `v` si et seulement si
sa position diffère du caucus de référence `R(v, p)`. Si `d` était absent,
ou si `R(v, p)` est indéfini (égalité ou parti = indépendant) : ni
dissident ni aligné, mais `non comparable`.

### Statistiques agrégées par député

Sur une fenêtre temporelle (toute la législature, par défaut) :

```
taux_dissidence(d) = nb_votes_dissident(d) / nb_votes_comparables(d)
```

Le dénominateur **exclut** les votes où `d` était absent ou
`non comparable`.

### À afficher sur chaque page députée

- Numérateur et dénominateur bruts (pas seulement le pourcentage).
- Lien direct vers la liste des votes dissidents.

---

## Sujets dominants

**Décision : ⚠️ Hors Phase 1.**

Le README projette une classification thématique automatique en Phase 2
(embeddings + clustering ou classification supervisée). En Phase 1,
n’afficher aucune statistique « sujets ». Si un compteur de mots-clés
naïf est introduit comme placeholder, **le marquer expérimental** sur
la page.

---

## Tension de licence (rappel)

Voir `docs/sources/_global.md` § « Tension de licence ». Tant que
l’arbitrage CC BY 4.0 vs CC-BY-NC 4.0 n’est pas tranché, **ne pas
ré-encapsuler** de CSV Données Québec dans les exports publics.

---

## Sources d’erreur connues

- **Présence (P1)** : sous-estimation systématique sur les séances à
  faible activité de vote nominal.
- **Dissidence** : silencieuse en cas de caucus partagé 50/50 (rare mais
  arrive sur petits caucus).
- **Versionnement Journal** : un parser cassé sur la version
  préliminaire peut produire un texte incomplet ; toujours afficher la
  version `final` quand elle existe (cf. `sources/journal.md`).

---

## Mécanisme de correction

Toute personne identifiant une donnée erronée peut signaler via le canal
prévu (à publier — issue tracker ou courriel). Cible de correction : 72 h
ouvrables, conforme au README. Tracer chaque correction dans
`docs/changelog-sources.md`.
