package repo

import db_pkg "../"
import sqlite "../../../vendor/sqlite"
import sa "../../../vendor/sqlite/addons"
import types "../../core"
import "core:c"
import "core:fmt"
import "core:strings"


new_track :: proc(
	db: ^sqlite.Connection,
	track: types.Track,
	allocator := context.allocator,
) -> (
	new_id: types.Track_Id,
	err: db_pkg.DatabaseErrors,
) {

	fmt.printfln("New Track: %#v", track)
	ok: bool

	id := db_pkg.gen_id("track", allocator)
	new_id = types.Track_Id(id)

	c_id := strings.clone_to_cstring(id, allocator)
	c_title := strings.clone_to_cstring(track.title, allocator)
	c_album_id := strings.clone_to_cstring(string(track.album_id), allocator)

	defer {
		delete(c_id, allocator)
		delete(c_title, allocator)
		delete(c_album_id, allocator)
	}

	query: cstring = "INSERT INTO track (id, title, album_id, track_number, mb_id) VALUES (?, ?, ?, ?, ?)"

	stmt: ^sqlite.Statement

	fmt.println("before prepare")

	if rc := sqlite.prepare_v2(db, query, c.int(len(query)), &stmt, nil); rc != .Ok {
		fmt.eprintfln("prepare error %v", rc)
		return new_id, .UnknownError
	}
	defer sqlite.finalize(stmt)

	fmt.println("after prepare")

	if rc := sqlite.bind_text(
		stmt,
		param_idx = 1,
		param_value = c_id,
		param_len = c.int(len(id)),
		free = {behaviour = .Static},
	); rc != .Ok {
		fmt.eprintfln("failed to bind value to TrackId. result code: {}", rc)
		return new_id, .UnknownError
	}

	if rc := sqlite.bind_text(
		stmt,
		param_idx = 2,
		param_value = c_title,
		param_len = c.int(len(track.title)),
		free = {behaviour = .Static},
	); rc != .Ok {
		fmt.eprintfln("failed to bind value to track title. result code: {}", rc)
		return new_id, .UnknownError
	}

	if rc := sqlite.bind_text(
		stmt,
		param_idx = 3,
		param_value = c_album_id,
		param_len = c.int(len(track.album_id)),
		free = {behaviour = .Static},
	); rc != .Ok {
		fmt.eprintfln("failed to bind value to track album id. result code: {}", rc)
		return new_id, .UnknownError
	}


	if rc := sqlite.bind_int(stmt, param_idx = 4, param_value = i32(track.track_number));
	   rc != .Ok {
		fmt.eprintfln("failed to bind value to track album id. result code: {}", rc)
		return new_id, .UnknownError
	}


	c_mb_id: cstring
	defer delete(c_mb_id, allocator)

	if mb_id, ok := track.mb_id.?; ok {
		c_mb_id = strings.clone_to_cstring(mb_id, allocator)
		fmt.printfln("%s %s", mb_id, c_mb_id)

		if rc := sqlite.bind_text(
			stmt,
			param_idx = 5,
			param_value = c_mb_id,
			param_len = c.int(len(mb_id)),
			free = {behaviour = .Static},
		); rc != .Ok {
			fmt.eprintfln("failed to bind value to mb_id. result code: {}", rc)
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

get_track_by_title :: proc(
	db: ^sqlite.Connection,
	title: string,
	album_id: Maybe(types.Album_Id),
	allocator := context.allocator,
) -> (
	res: types.Track,
	ok: bool,
) {
	query_with_album: cstring = "SELECT * FROM track WHERE title = ? AND album_id = ? LIMIT 1"
	query_without_album: cstring = "SELECT * FROM track WHERE title = ? LIMIT 1"
	query := query_without_album
	use_album_filter := false
	album_id_value := ""

	if v, has_album := album_id.?; has_album {
		query = query_with_album
		use_album_filter = true
		album_id_value = string(v)
	}

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
		fmt.eprintfln("failed to bind value to track title. result code: {}", rc)
		return res, false
	}

	c_album_id: cstring
	defer delete(c_album_id)

	if use_album_filter {
		c_album_id = strings.clone_to_cstring(album_id_value, allocator)

		if rc := sqlite.bind_text(
			stmt,
			param_idx = 2,
			param_value = c_album_id,
			param_len = c.int(len(album_id_value)),
			free = {behaviour = .Static},
		); rc != .Ok {
			fmt.eprintfln("failed to bind value to album_id. result code: {}", rc)
			return res, false
		}
	}

	fmt.printfln("prepared sql: {}\n", sqlite.expanded_sql(stmt))

	if sqlite.step(stmt) != .Row {
		return res, false
	}

	track := types.Track {
		id           = types.Track_Id(strings.clone_from(sqlite.column_text(stmt, 0))),
		title        = strings.clone_from(sqlite.column_text(stmt, 1)),
		track_number = u8(sqlite.column_int(stmt, 2)),
		album_id     = types.Album_Id(strings.clone_from(sqlite.column_text(stmt, 4))),
	}

	if mb_id_ptr := sqlite.column_text(stmt, 3); mb_id_ptr != nil {
		track.mb_id = strings.clone_from(mb_id_ptr)
	}

	return track, true
}


get_or_create_track :: proc(
	db: ^sqlite.Connection,
	track: types.Track,
	allocator := context.allocator,
) -> (
	res: types.Track_Id,
	ok: bool,
) {

	new_track_id, new_track_err := new_track(db, track)

	fmt.printfln("track Err %v", new_track_err)

	if (new_track_err == .None || new_track_err == .UniqueConstraint) == false {
		return "", false
	}


	if (new_track_err == .UniqueConstraint) {
		fmt.printfln("Sync, track unique constraint")
		existing_track, existing_track_ok := get_track_by_title(db, track.title, track.album_id)

		assert(existing_track_ok)

		defer types.delete_track(existing_track)

		fmt.printfln("Existing track %v", existing_track)

		delete(string(new_track_id))
		new_track_id = types.Track_Id(strings.clone(string(existing_track.id)))
	}

	return new_track_id, true
}
