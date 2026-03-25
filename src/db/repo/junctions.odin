package repo

import db_pkg "../"
import sqlite "../../../vendor/sqlite"
import sa "../../../vendor/sqlite/addons"
import types "../../core"
import "core:c"
import "core:fmt"
import "core:strings"

new_artist_album :: proc(
	db: ^sqlite.Connection,
	a: types.ArtistAlbum,
	allocator := context.allocator,
) -> db_pkg.DatabaseErrors {

	fmt.printfln("New Artist<->Album $#v", a)
	ok: bool

	c_artist_id := strings.clone_to_cstring(a.artist_id, allocator)
	c_album_id := strings.clone_to_cstring(string(a.album_id), allocator)

	defer {
		delete(c_artist_id, allocator)
		delete(c_album_id, allocator)
	}

	query: cstring = "INSERT INTO artist_album (artist_id, album_id) VALUES (?, ?) ON CONFLICT DO NOTHING"

	stmt: ^sqlite.Statement

	if rc := sqlite.prepare_v2(db, query, c.int(len(query)), &stmt, nil); rc != .Ok {
		return .UnknownError
	}
	defer sqlite.finalize(stmt)


	if rc := sqlite.bind_text(
		stmt,
		param_idx = 1,
		param_value = c_artist_id,
		param_len = c.int(len(a.artist_id)),
		free = {behaviour = .Static},
	); rc != .Ok {
		fmt.eprintfln("failed to bind value to ArtistId. result code: {}", rc)
		return .UnknownError
	}


	if rc := sqlite.bind_text(
		stmt,
		param_idx = 2,
		param_value = c_album_id,
		param_len = c.int(len(a.album_id)),
		free = {behaviour = .Static},
	); rc != .Ok {
		fmt.eprintfln("failed to bind value to albumId. result code: {}", rc)
		return .UnknownError
	}


	fmt.printfln("prepared sql: {}\n", sqlite.expanded_sql(stmt))

	rc := sqlite.step(stmt)
	fmt.printfln("Step RC: %v", rc)
	if (rc == .Constraint) {
		return .UniqueConstraint
	}
	if (rc != .Done) {
		return .UnknownError
	}

	return .None

}
