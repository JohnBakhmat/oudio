package db

import "core:fmt"
import "core:strings"

import sqlite "../../vendor/sqlite"
import sa "../../vendor/sqlite/addons"
import t "../core"
import "core:encoding/uuid"

gen_id :: proc(prefix: Maybe(string), allocator := context.allocator) -> string {
	id: string

	id_uuid := uuid.generate_v7_basic()

	if (prefix != nil) {
		id = strings.concatenate([]string{prefix.?, "_", uuid.to_string(id_uuid, allocator)})
	} else {
		id = uuid.to_string(id_uuid, allocator)
	}

	return id
}

new_album :: proc(db: ^sqlite.Connection, album: t.Album) -> sqlite.Result_Code {

	id := gen_id("album")

	return sa.execute(
		db,
		"INSERT INTO album (id,title,mb_id,mb_rg_id) VALUES (?, ?, ?, ?)",
		{{1, id}, {2, album.title}, {3, album.mb_id.?}, {4, album.mb_rg_id.?}},
	)
}


new_artist :: proc(db: ^sqlite.Connection, artist: t.Artist) -> sqlite.Result_Code {

	id := gen_id("artist")

	return sa.execute(
		db,
		"INSERT INTO artist (id, name, mb_id, acoust_id) VALUES (?, ?, ?, ?)",
		{{1, id}, {2, artist.name}, {3, artist.mb_id.?}, {4, artist.acoust_id.?}},
	)
}
