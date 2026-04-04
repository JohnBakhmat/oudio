package repo

import db_pkg "../"
import sqlite "../../../vendor/sqlite"
import sa "../../../vendor/sqlite/addons"
import types "../../core"
import "core:c"
import "core:fmt"
import "core:mem"
import "core:strings"
import "core:testing"

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

	query: cstring = "SELECT * FROM artist WHERE name = ? LIMIT 1"

	stmt: ^sqlite.Statement

	if rc := sqlite.prepare_v2(db, query, c.int(len(query)), &stmt, nil); rc != .Ok {
		fmt.eprintfln("failed to prepare statement. result code: {}", rc)
		return res, false
	}

	defer sqlite.finalize(stmt)

	c_name := strings.clone_to_cstring(name, allocator)
	defer delete(c_name)

	if rc := sqlite.bind_text(
		stmt,
		param_idx = 1,
		param_value = c_name,
		param_len = c.int(len(name)),
		free = {behaviour = .Static},
	); rc != .Ok {
		fmt.eprintfln("failed to bind value to artist name. result code: {}", rc)
		return res, false
	}

	fmt.printfln("prepared sql: {}\n", sqlite.expanded_sql(stmt))

	artist: types.Artist

	for sqlite.step(stmt) == .Row {

		artist = types.Artist {
			id   = types.Artist_Id(strings.clone_from(sqlite.column_text(stmt, 0))),
			name = strings.clone_from(sqlite.column_text(stmt, 1)),
		}

	}

	return artist, true
}


get_or_create_artist :: proc(
	db: ^sqlite.Connection,
	artist: types.Artist,
	allocator := context.allocator,
) -> (
	res: types.Artist_Id,
	ok: bool,
) {

	new_artist_id, new_artist_err := new_artist(db, artist)

	if (new_artist_err == .None || new_artist_err == .UniqueConstraint) == false {
		return "", false
	}

	fmt.printfln("New artist |%v| with id |%v|", artist.name, new_artist_id)

	if (new_artist_err == .UniqueConstraint) {

		fmt.printfln("Sync, artist unique constraint")
		existing_artist, existing_artist_ok := get_artist_by_name(db, artist.name)

		assert(existing_artist_ok)

		defer types.delete_artist(existing_artist)

		fmt.printfln("Existing artist %v", existing_artist)

		delete(string(new_artist_id))
		new_artist_id = types.Artist_Id(strings.clone(string(existing_artist.id)))
	}

	return new_artist_id, true

}
