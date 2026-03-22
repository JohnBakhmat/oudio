package repo

import db_pkg "../"
import sqlite "../../../vendor/sqlite"
import types "../../core"
import "core:fmt"
import "core:mem"
import "core:testing"


@(test)
should_create_new_artist :: proc(t: ^testing.T) {

	track: mem.Tracking_Allocator
	mem.tracking_allocator_init(&track, context.allocator, context.allocator)
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

	if rc := sqlite.open(db_pkg.db_url, &db); rc != .Ok {
		fmt.panicf("failed to open database. result code {}", rc)
	}
	fmt.printfln("connected to database")

	defer {
		sqlite.close(db)
		fmt.printfln("\nconnection closed")
	}

	artist := types.Artist {
		id        = "test",
		name      = "PinkPantheres",
		mb_id     = "asdf",
		acoust_id = "123",
	}

	new_id, err := new_artist(db, artist, context.allocator)
	testing.expect(t, err == .None)
}

@(test)
should_create_new_artist_batch :: proc(t: ^testing.T) {


	track: mem.Tracking_Allocator
	mem.tracking_allocator_init(&track, context.allocator, context.allocator)
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

	if rc := sqlite.open(db_pkg.db_url, &db); rc != .Ok {
		fmt.panicf("failed to open database. result code {}", rc)
	}
	fmt.printfln("connected to database")

	defer {
		sqlite.close(db)
		fmt.printfln("connection closed")
	}

	artists := []types.Artist {
		{id = "test1", name = "PinkPantheres1", mb_id = "asdf", acoust_id = "123"},
		{id = "test2", name = "PinkPantheres2", mb_id = "asdf", acoust_id = "123"},
		{id = "test3", name = "PinkPantheres3", mb_id = "asdf", acoust_id = "123"},
	}

	rc := new_artist_batch(db, artists, context.allocator)
	testing.expect(t, rc == .Ok)
}
