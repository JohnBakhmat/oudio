package repo

import db_pkg "../"
import sqlite "../../../vendor/sqlite"
import sa "../../../vendor/sqlite/addons"
import types "../../core"
import "core:fmt"
import "core:strings"

new_artist :: proc(
	db: ^sqlite.Connection,
	artist: types.Artist,
	allocator := context.allocator,
) -> (
	new_id: types.Artist_Id,
	err: db_pkg.DatabaseErrors,
) {


	fmt.printfln("New artist: %#v", artist)

	id := db_pkg.gen_id("artist", allocator)
	new_id = types.Artist_Id(id)


	mb_id_value: sa.Query_Param_Value
	if mb_id, ok := artist.mb_id.?; ok {
		mb_id_value = mb_id
	}

	acoust_id_value: sa.Query_Param_Value
	if acoust_id, ok := artist.acoust_id.?; ok {
		acoust_id_value = acoust_id
	}


	query := "INSERT INTO artist (id, name, mb_id, acoust_id) VALUES (?, ?, ?, ?)"

	rc := sa.execute(
		db,
		query,
		{
			{index = 1, value = id},
			{index = 2, value = artist.name},
			{index = 3, value = mb_id_value},
			{index = 4, value = acoust_id_value},
		},
	)


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


new_artist_batch :: proc(
	db: ^sqlite.Connection,
	artists: []types.Artist,
	allocator := context.allocator,
) -> sqlite.Result_Code {

	rc: sqlite.Result_Code

	n := len(artists)


	fmt.printfln("Starting transaction")
	rc = sa.execute(db, "BEGIN TRANSACTION;")
	assert(rc == .Ok)

	for artist in artists {
		fmt.printfln("Inserting %v", artist)
		new_id, err := new_artist(db, artist, allocator)
		assert(err == .None)
	}

	fmt.printfln("Commiting transaction")
	rc = sa.execute(db, "COMMIT;")
	assert(rc == .Ok)

	return rc
}


get_artist_by_name :: proc(
	db: ^sqlite.Connection,
	name: string,
	allocator := context.allocator,
) -> (
	res: types.Artist,
	ok: bool,
) {
	return get_artist_by_column(db, "name", name, allocator)
}

get_artist_by_mb_id :: proc(
	db: ^sqlite.Connection,
	mb_id: string,
	allocator := context.allocator,
) -> (
	res: types.Artist,
	ok: bool,
) {
	return get_artist_by_column(db, "mb_id", mb_id, allocator)
}

get_artist_by_acoust_id :: proc(
	db: ^sqlite.Connection,
	acoust_id: string,
	allocator := context.allocator,
) -> (
	res: types.Artist,
	ok: bool,
) {
	return get_artist_by_column(db, "acoust_id", acoust_id, allocator)
}

@(private)
get_artist_by_column :: proc(
	db: ^sqlite.Connection,
	column: string,
	value: string,
	allocator := context.allocator,
) -> (
	res: types.Artist,
	ok: bool,
) {
	Artist_Row :: struct {
		id:   string `sqlite:"id"`,
		name: string `sqlite:"name"`,
	}

	sql: string
	switch column {
	case "name":
		sql = "SELECT id, name FROM artist WHERE name = ? LIMIT 1"
	case "mb_id":
		sql = "SELECT id, name FROM artist WHERE mb_id = ? LIMIT 1"
	case "acoust_id":
		sql = "SELECT id, name FROM artist WHERE acoust_id = ? LIMIT 1"
	case:
		return res, false
	}

	rows := make([dynamic]Artist_Row, 0, 1, allocator)
	defer {
		for row in rows {
			delete(row.id)
			delete(row.name)
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
	artist := types.Artist {
		id   = types.Artist_Id(strings.clone(row.id, allocator)),
		name = strings.clone(row.name, allocator),
	}

	return artist, true
}

find_existing_artist :: proc(
	db: ^sqlite.Connection,
	artist: types.Artist,
	allocator := context.allocator,
) -> (
	res: types.Artist,
	ok: bool,
) {
	if mb_id, has_mb_id := artist.mb_id.?; has_mb_id {
		if existing, found := get_artist_by_mb_id(db, mb_id, allocator); found {
			return existing, true
		}
	}

	if acoust_id, has_acoust_id := artist.acoust_id.?; has_acoust_id {
		if existing, found := get_artist_by_acoust_id(db, acoust_id, allocator); found {
			return existing, true
		}
	}

	return get_artist_by_name(db, artist.name, allocator)
}

get_or_create_artist :: proc(
	db: ^sqlite.Connection,
	artist: types.Artist,
	allocator := context.allocator,
) -> (
	res: types.Artist_Id,
	ok: bool,
) {
	if existing_artist, existing_artist_ok := find_existing_artist(
		db,
		artist,
		allocator,
	); existing_artist_ok {
		defer types.delete_artist(existing_artist)
		return types.Artist_Id(strings.clone(string(existing_artist.id), allocator)), true
	}

	new_artist_id, new_artist_err := new_artist(db, artist, allocator)

	if new_artist_err == .None {
		fmt.printfln("New artist |%v| with id |%v|", artist.name, new_artist_id)
		return new_artist_id, true
	}

	if new_artist_err != .UniqueConstraint {
		return "", false
	}

	fmt.printfln("Sync, artist unique constraint for |%v|", artist.name)

	existing_artist, existing_artist_ok := find_existing_artist(
		db,
		artist,
		allocator,
	)
	if !existing_artist_ok {
		fmt.eprintfln(
			"artist unique constraint but no match by mb_id, acoust_id, or name for |%v|",
			artist.name,
		)
		delete(string(new_artist_id))
		return "", false
	}

	defer types.delete_artist(existing_artist)

	fmt.printfln("Existing artist %v", existing_artist)

	delete(string(new_artist_id))
	return types.Artist_Id(strings.clone(string(existing_artist.id), allocator)), true
}
