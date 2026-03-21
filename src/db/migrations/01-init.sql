CREATE TABLE migrations (
	id INTEGER PRIMARY KEY,
	name TEXT NOT NULL UNIQUE,
	applied_at DATE
);

CREATE TABLE album (
	id TEXT PRIMARY KEY,
	title TEXT NOT NULL,
	mb_id TEXT UNIQUE,
	mb_rg_id TEXT UNIQUE
);

CREATE TABLE artist (
	id TEXT PRIMARY KEY,
	name TEXT NOT NULL UNIQUE,
	mb_id TEXT UNIQUE,
	acoust_id TEXT UNIQUE
);

CREATE TABLE track (
	id TEXT PRIMARY KEY,
	title TEXT NOT NULL,
	track_number INTEGER NOT NULL DEFAULT 0,
	mb_id TEXT,
	album_id TEXT NOT NULL,

	FOREIGN KEY(album_id) REFERENCES album(id) ON DELETE CASCADE
);

CREATE INDEX track_album_idx ON track(album_id);

CREATE TABLE artist_track (
	artist_id TEXT NOT NULL,
	track_id TEXT NOT NULL,

	PRIMARY KEY(artist_id, track_id),
	FOREIGN KEY(artist_id) REFERENCES artist(id),
	FOREIGN KEY(track_id) REFERENCES track(id)
);

CREATE TABLE artist_album (
	artist_id TEXT NOT NULL,
	album_id TEXT NOT NULL,

	PRIMARY KEY(artist_id, album_id),
	FOREIGN KEY(artist_id) REFERENCES artist(id),
	FOREIGN KEY(album_id) REFERENCES album(id)
);

INSERT INTO migrations (name, applied_at) VALUES ("01-init", CURRENT_TIMESTAMP);
