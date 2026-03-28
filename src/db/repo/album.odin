package repo

import db_pkg "../"
import sqlite "../../../vendor/sqlite"
import sa "../../../vendor/sqlite/addons"
import types "../../core"
import "core:c"
import "core:fmt"
import "core:strings"

new_album :: proc(
	db: ^sqlite.Connection,
	album: types.Album,
	allocator := context.allocator,
) -> (
	new_id: types.Album_Id,
	err: db_pkg.DatabaseErrors,
) {

	fmt.printfln("New Album: %#v", album)
	ok: bool

	id := db_pkg.gen_id("album", allocator)
	new_id = types.Album_Id(id)
	c_id := strings.clone_to_cstring(id, allocator)
	c_title := strings.clone_to_cstring(album.title, allocator)

	defer {
		delete(c_id, allocator)
		delete(c_title, allocator)
	}

	query: cstring = "INSERT INTO album (id, title, mb_id, mb_rg_id) VALUES (?, ?, ?, ?)"

	stmt: ^sqlite.Statement

	if rc := sqlite.prepare_v2(db, query, c.int(len(query)), &stmt, nil); rc != .Ok {
		return new_id, .UnknownError
	}
	defer sqlite.finalize(stmt)

	if rc := sqlite.bind_text(
		stmt,
		param_idx = 1,
		param_value = c_id,
		param_len = c.int(len(id)),
		free = {behaviour = .Static},
	); rc != .Ok {
		fmt.eprintfln("failed to bind value to ArtistId. result code: {}", rc)
		return new_id, .UnknownError
	}


	if rc := sqlite.bind_text(
		stmt,
		param_idx = 2,
		param_value = c_title,
		param_len = c.int(len(album.title)),
		free = {behaviour = .Static},
	); rc != .Ok {
		fmt.eprintfln("failed to bind value to artist title. result code: {}", rc)
		return new_id, .UnknownError
	}


	c_mb_id, c_mb_rg_id: cstring
	defer delete(c_mb_id, allocator)
	defer delete(c_mb_rg_id, allocator)

	if mb_id, ok := album.mb_id.?; ok {
		c_mb_id = strings.clone_to_cstring(mb_id, allocator)
		fmt.printfln("%s %s", mb_id, c_mb_id)

		if rc := sqlite.bind_text(
			stmt,
			param_idx = 3,
			param_value = c_mb_id,
			param_len = c.int(len(mb_id)),
			free = {behaviour = .Static},
		); rc != .Ok {
			fmt.eprintfln("failed to bind value to mb_id. result code: {}", rc)
			return new_id, .UnknownError
		}

	}


	if mb_rg_id, ok := album.mb_rg_id.?; ok {
		c_mb_rg_id = strings.clone_to_cstring(mb_rg_id, allocator)

		if rc := sqlite.bind_text(
			stmt,
			param_idx = 4,
			param_value = c_mb_rg_id,
			param_len = c.int(len(mb_rg_id)),
			free = {behaviour = .Static},
		); rc != .Ok {
			fmt.eprintfln("failed to bind value to mb_rg_id. result code: {}", rc)
			return new_id, .UnknownError
		}

	}


	fmt.printfln("prepared sql: {}\n", sqlite.expanded_sql(stmt))


	rc := sqlite.step(stmt)
	fmt.printfln("Step RC: %v", rc)
	if (rc == .Constraint) {
		return new_id, .UniqueConstraint
	}
	if (rc != .Done) {
		return new_id, .UnknownError
	}

	return new_id, .None
}


new_album_batch :: proc(
	db: ^sqlite.Connection,
	albums: []types.Album,
	allocator := context.allocator,
) -> sqlite.Result_Code {

	rc: sqlite.Result_Code

	n := len(albums)


	fmt.printfln("Starting transaction")
	rc = sa.execute(db, "BEGIN TRANSACTION;")
	assert(rc == .Ok)

	for album in albums {
		fmt.printfln("Inserting %v", album)
		new_id, err := new_album(db, album, allocator)
		assert(err == .None)
	}

	fmt.printfln("Commiting transaction")
	rc = sa.execute(db, "COMMIT;")
	assert(rc == .Ok)

	return rc
}

get_album_by_title :: proc(
	db: ^sqlite.Connection,
	title: string,
	allocator := context.allocator,
) -> (
	res: types.Album,
	ok: bool,
) {

	query: cstring = "SELECT * FROM album WHERE title = ? LIMIT 1"

	stmt: ^sqlite.Statement

	if rc := sqlite.prepare_v2(db, query, c.int(len(query)), &stmt, nil); rc != .Ok {
		fmt.eprintfln("failed to prepare statement. result code: {}", rc)
		return res, false
	}

	defer sqlite.finalize(stmt)

	c_title := strings.clone_to_cstring(title, allocator)
	defer delete(c_title)

	if rc := sqlite.bind_text(
		stmt,
		param_idx = 1,
		param_value = c_title,
		param_len = c.int(len(title)),
		free = {behaviour = .Static},
	); rc != .Ok {
		fmt.eprintfln("failed to bind value to ArtistId. result code: {}", rc)
		return res, false
	}

	fmt.printfln("prepared sql: {}\n", sqlite.expanded_sql(stmt))

	album: types.Album

	for sqlite.step(stmt) == .Row {

		album = types.Album {
			id    = types.Album_Id(strings.clone_from(sqlite.column_text(stmt, 0))),
			title = strings.clone_from(sqlite.column_text(stmt, 1)),
		}

	}

	return album, true
}

get_album_by_id :: proc(
	db: ^sqlite.Connection,
	id: string,
	allocator := context.allocator,
) -> (
	res: types.Album,
	ok: bool,
) {

	query: cstring = "SELECT * FROM album WHERE id = ? LIMIT 1"

	stmt: ^sqlite.Statement

	if rc := sqlite.prepare_v2(db, query, c.int(len(query)), &stmt, nil); rc != .Ok {
		fmt.eprintfln("failed to prepare statement. result code: {}", rc)
		return res, false
	}

	defer sqlite.finalize(stmt)

	c_id := strings.clone_to_cstring(id, allocator)
	defer delete(c_id)

	if rc := sqlite.bind_text(
		stmt,
		param_idx = 1,
		param_value = c_id,
		param_len = c.int(len(id)),
		free = {behaviour = .Static},
	); rc != .Ok {
		fmt.eprintfln("failed to bind value to ArtistId. result code: {}", rc)
		return res, false
	}

	fmt.printfln("prepared sql: {}\n", sqlite.expanded_sql(stmt))

	albums := make([dynamic]types.Album, 0, 1)
	defer {
		for album in albums {
			types.delete_album(album)
		}
		delete_dynamic_array(albums)
	}

	for sqlite.step(stmt) == .Row {

		album := types.Album {
			id    = types.Album_Id(strings.clone_from(sqlite.column_text(stmt, 0))),
			title = strings.clone_from(sqlite.column_text(stmt, 1)),
		}

		append(&albums, album)
	}

	return albums[0], true
}
