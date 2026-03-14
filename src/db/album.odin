package db

import sqlite "../../vendor/sqlite"
import sa "../../vendor/sqlite/addons"
import types "../core"
import "core:fmt"
import "core:mem"
import "core:testing"

new_album :: proc(
	db: ^sqlite.Connection,
	album: types.Album,
	allocator := context.allocator,
) -> sqlite.Result_Code {

	id := gen_id("album", allocator)
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


// ================
// Tests
// ================


// @(test)
// should_create_new_album :: proc(t: ^testing.T) {
//
//
// 	track: mem.Tracking_Allocator
// 	mem.tracking_allocator_init(&track, context.allocator)
// 	context.allocator = mem.tracking_allocator(&track)
// 	defer {
// 		if len(track.allocation_map) > 0 {
// 			fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
// 			for _, entry in track.allocation_map {
// 				fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
// 			}
// 		}
// 		if len(track.bad_free_array) > 0 {
// 			fmt.eprintf("=== %v incorrect frees: ===\n", len(track.bad_free_array))
// 			for entry in track.bad_free_array {
// 				fmt.eprintf("- %p @ %v\n", entry.memory, entry.location)
// 			}
// 		}
// 		mem.tracking_allocator_destroy(&track)
// 	}
//
//
// 	db: ^sqlite.Connection
//
// 	if rc := sqlite.open(db_url, &db); rc != .Ok {
// 		fmt.panicf("failed to open database. result code {}", rc)
// 	}
// 	fmt.printfln("connected to database")
//
// 	defer {
// 		sqlite.close(db)
// 		fmt.printfln("\nconnection closed")
// 	}
//
// 	album := types.Album {
// 		id       = "test",
// 		title    = "Test title",
// 		mb_id    = "asdf",
// 		mb_rg_id = "asdf",
// 	}
//
// 	rc := new_album(db, album)
// 	testing.expect(t, rc == .Ok)
//
// }
