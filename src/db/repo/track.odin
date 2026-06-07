package repo

import db_pkg "../"
import sqlite "../../../vendor/sqlite"
import sa "../../../vendor/sqlite/addons"
import types "../../core"
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
	Track_Row :: struct {
		id:           string `sqlite:"id"`,
		title:        string `sqlite:"title"`,
		track_number: i32 `sqlite:"track_number"`,
		mb_id:        string `sqlite:"mb_id"`,
		album_id:     string `sqlite:"album_id"`,
	}

	rows := make([dynamic]Track_Row, 0, 1, allocator)
	defer {
		for row in rows {
			delete(row.id)
			delete(row.title)
			delete(row.mb_id)
			delete(row.album_id)
		}
		delete_dynamic_array(rows)
	}

	rc := sqlite.Result_Code.Ok

	if v, has_album := album_id.?; has_album {
		rc = sa.query(
			db,
			&rows,
			"SELECT id, title, track_number, COALESCE(mb_id, '') AS mb_id, album_id FROM track WHERE title = ? AND album_id = ? LIMIT 1",
			{{index = 1, value = title}, {index = 2, value = string(v)}},
		)
	} else {
		rc = sa.query(
			db,
			&rows,
			"SELECT id, title, track_number, COALESCE(mb_id, '') AS mb_id, album_id FROM track WHERE title = ? LIMIT 1",
			{{index = 1, value = title}},
		)
	}

	if rc != .Ok || len(rows) == 0 {
		return res, false
	}

	row := rows[0]
	track := types.Track {
		id           = types.Track_Id(strings.clone(row.id, allocator)),
		title        = strings.clone(row.title, allocator),
		track_number = u8(row.track_number),
		album_id     = types.Album_Id(strings.clone(row.album_id, allocator)),
	}

	if len(row.mb_id) > 0 {
		track.mb_id = strings.clone(row.mb_id, allocator)
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

	if (new_track_err == .None || new_track_err == .UniqueConstraint) ==
	   false {
		return "", false
	}


	if (new_track_err == .UniqueConstraint) {
		fmt.printfln("Sync, track unique constraint")
		existing_track, existing_track_ok := get_track_by_title(
			db,
			track.title,
			track.album_id,
		)

		assert(existing_track_ok)

		defer types.delete_track(existing_track)

		fmt.printfln("Existing track %v", existing_track)

		delete(string(new_track_id))
		new_track_id = types.Track_Id(strings.clone(string(existing_track.id)))
	}

	return new_track_id, true
}
