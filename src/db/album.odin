package db

import sqlite "../../vendor/sqlite"
import sa "../../vendor/sqlite/addons"
import types "../core"
import "core:fmt"
import "core:mem"
import "core:testing"

new_album :: proc(db: ^sqlite.Connection, album: types.Album) -> sqlite.Result_Code {

	id := gen_id("album")
	defer delete(id)

	return sa.execute(
		db,
		"INSERT INTO album (id, title, mb_id, mb_rg_id) VALUES (?, ?, ?, ?)",
		{{1, id}, {2, album.title}, {3, album.mb_id.?}, {4, album.mb_rg_id.?}},
	)
}


// ================
// Tests
// ================


@(test)
should_create_new_album :: proc(t: ^testing.T) {


	track: mem.Tracking_Allocator
	mem.tracking_allocator_init(&track, context.allocator)
	context.allocator = mem.tracking_allocator(&track)
	defer {
		if len(track.allocation_map) > 0 {
			fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
			for _, entry in track.allocation_map {
				fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
			}
		}
		if len(track.bad_free_array) > 0 {
			fmt.eprintf("=== %v incorrect frees: ===\n", len(track.bad_free_array))
			for entry in track.bad_free_array {
				fmt.eprintf("- %p @ %v\n", entry.memory, entry.location)
			}
		}
		mem.tracking_allocator_destroy(&track)
	}


	db: ^sqlite.Connection

	if rc := sqlite.open(db_url, &db); rc != .Ok {
		fmt.panicf("failed to open database. result code {}", rc)
	}
	fmt.printfln("connected to database")

	defer {
		sqlite.close(db)
		fmt.printfln("\nconnection closed")
	}

	album := types.Album {
		id       = "test",
		title    = "Test title",
		mb_id    = "asdf",
		mb_rg_id = "asdf",
	}

	rc := new_album(db, album)
	testing.expect(t, rc == .Ok)

}
