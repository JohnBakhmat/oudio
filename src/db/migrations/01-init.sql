create table migrations (
	id integer primary key,
	name text not null unique,
	applied_at date
);

create table album (
	id text primary key,
	title text not null unique,
	mb_id text unique,
	mb_rg_id text unique
);

create table artist (
	id text primary key,
	name text not null unique,
	mb_id text unique,
	acoust_id text unique
);

create table track (
	id text primary key,
	title text not null,
	track_number integer not null default 0,
	mb_id text,
	album_id text not null,

	unique(title, track_number, album_id)
	foreign key(album_id) references album(id) on delete cascade
);

create table file (
	id text primary key,
	path text not null unique,
	track_id text not null unique,

	foreign key (track_id) references track(id)
);

create index track_album_idx on track(album_id);

create table artist_track (
	artist_id text not null,
	track_id text not null,

	primary key(artist_id, track_id),
	foreign key(artist_id) references artist(id),
	foreign key(track_id) references track(id)
);

create table artist_album (
	artist_id text not null,
	album_id text not null,

	primary key(artist_id, album_id),
	foreign key(artist_id) references artist(id),
	foreign key(album_id) references album(id)
);

insert into migrations (name, applied_at) values ("01-init", current_timestamp);
