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

	id := db_pkg.gen_id("track", allocator)
	new_id = types.Track_Id(id)

	mb_id_value: sa.Query_Param_Value
	if mb_id, ok := track.mb_id.?; ok {
		mb_id_value = mb_id
	}

	rc := sa.execute(
		db,
		"INSERT INTO track (id, title, album_id, track_number, mb_id) VALUES (?, ?, ?, ?, ?)",
		{
			{index = 1, value = id},
			{index = 2, value = track.title},
			{index = 3, value = string(track.album_id)},
			{index = 4, value = i32(track.track_number)},
			{index = 5, value = mb_id_value},
		},
	)

	#partial switch rc {
	case .Constraint:
		return new_id, .UniqueConstraint
	case .Done, .Ok:
		return new_id, .None
	case:
		fmt.eprintfln("new_track2 failed with result code: %v", rc)
		return new_id, .UnknownError
	}
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
