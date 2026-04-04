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

	id := db_pkg.gen_id("album", allocator)
	new_id = types.Album_Id(id)


	mb_id_value: sa.Query_Param_Value
	if mb_id, ok := album.mb_id.?; ok {
		mb_id_value = mb_id
	}

	mb_rg_id_value: sa.Query_Param_Value
	if mb_rg_id, ok := album.mb_rg_id.?; ok {
		mb_rg_id_value = mb_rg_id
	}

	query := "INSERT INTO album (id, title, mb_id, mb_rg_id) VALUES (?, ?, ?, ?)"

	rc := sa.execute(
		db,
		query,
		{
			{index = 1, value = id},
			{index = 2, value = album.title},
			{index = 3, value = mb_id_value},
			{index = 4, value = mb_rg_id_value},
		},
	)

	fmt.printfln("\n\n\n\nRC:%v \n\n\n\n", rc)

	#partial switch rc {
	case .Constraint:
		return new_id, .UniqueConstraint
	case .Done, .Ok:
		return new_id, .None
	case:
		fmt.eprintfln("new_album failed with result code: %v", rc)
		return new_id, .UnknownError
	}

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


get_or_create_album :: proc(
	db: ^sqlite.Connection,
	album: types.Album,
	allocator := context.allocator,
) -> (
	res: types.Album_Id,
	ok: bool,
) {
	new_album_id, new_album_err := new_album(db, album)

	if (new_album_err == .None || new_album_err == .UniqueConstraint) == false {
		return "", false
	}

	fmt.printfln("Album Err %v", new_album_err)

	if (new_album_err == .UniqueConstraint) {
		fmt.printfln("Sync, album unique constraint")
		existing_album, existing_album_ok := get_album_by_title(db, album.title)

		assert(existing_album_ok)

		defer types.delete_album(existing_album)

		fmt.printfln("Existing Album %v", existing_album)

		delete(string(new_album_id))
		new_album_id = types.Album_Id(strings.clone(string(existing_album.id)))
	}

	return new_album_id, true
}
