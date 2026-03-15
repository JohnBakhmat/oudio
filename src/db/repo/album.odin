package repo

import db_pkg "../"
import sqlite "../../../vendor/sqlite"
import sa "../../../vendor/sqlite/addons"
import types "../../core"
import "core:fmt"

new_album :: proc(
	db: ^sqlite.Connection,
	album: types.Album,
	allocator := context.allocator,
) -> sqlite.Result_Code {

	id := db_pkg.gen_id("album", allocator)
	defer delete(id, allocator)


	params := make([dynamic]sa.Query_Param, 2, 4, allocator)
	defer delete_dynamic_array(params)

	params[0] = sa.Query_Param{1, id}
	params[1] = sa.Query_Param{2, album.title}


	mb_id, mb_rg_id: string
	ok: bool

	mb_id, ok = album.mb_id.?
	if ok do append(&params, sa.Query_Param{3, mb_id})

	mb_rg_id, ok = album.mb_rg_id.?
	if ok do append(&params, sa.Query_Param{4, mb_rg_id})

	return sa.execute(
		db,
		"INSERT INTO album (id, title, mb_id, mb_rg_id) VALUES (?, ?, ?, ?)",
		params[:],
	)
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
		rc = new_album(db, album, allocator)
		assert(rc == .Ok)
	}

	fmt.printfln("Commiting transaction")
	rc = sa.execute(db, "COMMIT;")
	assert(rc == .Ok)

	return rc
}

get_album_by_id :: proc(
	db: ^sqlite.Connection,
	id: string,
	allocator := context.allocator,
) -> (
	res: types.Album,
	ok: bool,
) {

	params := []sa.Query_Param{{1, id}}
	query := "SELECT * FROM album WHERE id = ? LIMIT 1"

	albums := make([dynamic]types.Album, 0, 1)

	rc := sa.query(db, &albums, query, params)
	if (rc != .Ok || len(albums) != 1) {
		return res, false
	}

	return albums[0], true
}
