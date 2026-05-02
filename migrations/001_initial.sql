-- Schéma SQLite indicatif (README). À ajuster selon les sources réelles assnat.qc.ca.

CREATE TABLE depute (
    id              INTEGER PRIMARY KEY,
    nom_complet     TEXT NOT NULL,
    nom_recherche   TEXT NOT NULL,
    parti_actuel    TEXT,
    circonscription TEXT NOT NULL,
    region          TEXT,
    debut_mandat    DATE NOT NULL,
    fin_mandat      DATE,
    photo_url       TEXT,
    bio_assnat_url  TEXT
);

CREATE TABLE depute_parti_historique (
    depute_id  INTEGER REFERENCES depute(id),
    parti      TEXT NOT NULL,
    debut      DATE NOT NULL,
    fin        DATE,
    motif      TEXT,
    PRIMARY KEY (depute_id, debut)
);

CREATE TABLE seance (
    id          INTEGER PRIMARY KEY,
    date        DATE NOT NULL,
    legislature INTEGER NOT NULL,
    session     INTEGER NOT NULL,
    numero      INTEGER NOT NULL,
    type        TEXT,
    UNIQUE (legislature, session, numero)
);

CREATE TABLE vote (
    id              INTEGER PRIMARY KEY,
    seance_id       INTEGER REFERENCES seance(id),
    sujet           TEXT NOT NULL,
    description     TEXT,
    type            TEXT,
    projet_loi_id   TEXT,
    resultat        TEXT NOT NULL,
    pour            INTEGER,
    contre          INTEGER,
    abstentions     INTEGER,
    timestamp       DATETIME,
    source_url      TEXT NOT NULL
);

CREATE TABLE vote_depute (
    vote_id    INTEGER REFERENCES vote(id),
    depute_id  INTEGER REFERENCES depute(id),
    position   TEXT NOT NULL,
    PRIMARY KEY (vote_id, depute_id)
);

CREATE TABLE intervention (
    id              INTEGER PRIMARY KEY,
    seance_id       INTEGER REFERENCES seance(id),
    depute_id       INTEGER REFERENCES depute(id),
    ordre_seance    INTEGER NOT NULL,
    role            TEXT,
    texte           TEXT NOT NULL,
    nb_mots         INTEGER NOT NULL,
    source_url      TEXT NOT NULL,
    statut          TEXT NOT NULL
);

CREATE VIRTUAL TABLE intervention_fts USING fts5(
    texte,
    content='intervention',
    content_rowid='id',
    tokenize='unicode61 remove_diacritics 2'
);

CREATE INDEX idx_vote_seance ON vote(seance_id);
CREATE INDEX idx_intervention_depute ON intervention(depute_id);
CREATE INDEX idx_intervention_seance ON intervention(seance_id);
