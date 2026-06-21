package repo

import db_pkg "../"
import sqlite "../../../vendor/sqlite"
import sa "../../../vendor/sqlite/addons"
import types "../../core"
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
	return get_album_by_column(db, "title", title, allocator)
}

get_album_by_mb_id :: proc(
	db: ^sqlite.Connection,
	mb_id: string,
	allocator := context.allocator,
) -> (
	res: types.Album,
	ok: bool,
) {
	return get_album_by_column(db, "mb_id", mb_id, allocator)
}

get_album_by_mb_rg_id :: proc(
	db: ^sqlite.Connection,
	mb_rg_id: string,
	allocator := context.allocator,
) -> (
	res: types.Album,
	ok: bool,
) {
	return get_album_by_column(db, "mb_rg_id", mb_rg_id, allocator)
}

@(private)
get_album_by_column :: proc(
	db: ^sqlite.Connection,
	column: string,
	value: string,
	allocator := context.allocator,
) -> (
	res: types.Album,
	ok: bool,
) {
	Album_Row :: struct {
		id:    string `sqlite:"id"`,
		title: string `sqlite:"title"`,
	}

	sql: string
	switch column {
	case "title":
		sql = "SELECT id, title FROM album WHERE title = ? LIMIT 1"
	case "mb_id":
		sql = "SELECT id, title FROM album WHERE mb_id = ? LIMIT 1"
	case "mb_rg_id":
		sql = "SELECT id, title FROM album WHERE mb_rg_id = ? LIMIT 1"
	case:
		return res, false
	}

	rows := make([dynamic]Album_Row, 0, 1, allocator)
	defer {
		for row in rows {
			delete(row.id)
			delete(row.title)
		}
		delete_dynamic_array(rows)
	}

	rc := sa.query(
		db,
		&rows,
		sql,
		{{index = 1, value = value}},
	)

	if rc != .Ok || len(rows) == 0 {
		return res, false
	}

	row := rows[0]
	album := types.Album {
		id    = types.Album_Id(strings.clone(row.id, allocator)),
		title = strings.clone(row.title, allocator),
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
	Album_Row :: struct {
		id:    string `sqlite:"id"`,
		title: string `sqlite:"title"`,
	}

	rows := make([dynamic]Album_Row, 0, 1, allocator)
	defer {
		for row in rows {
			delete(row.id)
			delete(row.title)
		}
		delete_dynamic_array(rows)
	}

	rc := sa.query(
		db,
		&rows,
		"SELECT id, title FROM album WHERE id = ? LIMIT 1",
		{{index = 1, value = id}},
	)

	if rc != .Ok || len(rows) == 0 {
		return res, false
	}

	row := rows[0]
	album := types.Album {
		id    = types.Album_Id(strings.clone(row.id, allocator)),
		title = strings.clone(row.title, allocator),
	}

	return album, true
}


find_existing_album :: proc(
	db: ^sqlite.Connection,
	album: types.Album,
	allocator := context.allocator,
) -> (
	res: types.Album,
	ok: bool,
) {
	if mb_id, has_mb_id := album.mb_id.?; has_mb_id {
		if existing, found := get_album_by_mb_id(db, mb_id, allocator); found {
			return existing, true
		}
	}

	if mb_rg_id, has_mb_rg_id := album.mb_rg_id.?; has_mb_rg_id {
		if existing, found := get_album_by_mb_rg_id(db, mb_rg_id, allocator); found {
			return existing, true
		}
	}

	return get_album_by_title(db, album.title, allocator)
}

get_or_create_album :: proc(
	db: ^sqlite.Connection,
	album: types.Album,
	allocator := context.allocator,
) -> (
	res: types.Album_Id,
	ok: bool,
) {
	if existing_album, existing_album_ok := find_existing_album(
		db,
		album,
		allocator,
	); existing_album_ok {
		defer types.delete_album(existing_album)
		return types.Album_Id(strings.clone(string(existing_album.id), allocator)), true
	}

	new_album_id, new_album_err := new_album(db, album, allocator)

	if new_album_err == .None {
		return new_album_id, true
	}

	if new_album_err != .UniqueConstraint {
		return "", false
	}

	fmt.printfln("Sync, album unique constraint for |%v|", album.title)

	existing_album, existing_album_ok := find_existing_album(db, album, allocator)
	if !existing_album_ok {
		fmt.eprintfln(
			"album unique constraint but no match by mb_id, mb_rg_id, or title for |%v|",
			album.title,
		)
		delete(string(new_album_id))
		return "", false
	}

	defer types.delete_album(existing_album)

	fmt.printfln("Existing Album %v", existing_album)

	delete(string(new_album_id))
	return types.Album_Id(strings.clone(string(existing_album.id), allocator)), true
}
