
package repo

import db_pkg "../"
import sqlite "../../../vendor/sqlite"
import types "../../core"
import "core:fmt"
import "core:mem"
import "core:testing"


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

	if rc := sqlite.open(db_pkg.db_url, &db); rc != .Ok {
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


@(test)
should_get_album_by_id :: proc(t: ^testing.T) {


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

	if rc := sqlite.open(db_pkg.db_url, &db); rc != .Ok {
		fmt.panicf("failed to open database. result code {}", rc)
	}
	fmt.printfln("connected to database")

	defer {
		sqlite.close(db)
		fmt.printfln("\nconnection closed")
	}


	input := "album_019cf0fc-b57a-7f58-a298-ad3166101dd9"

	album, ok := get_album_by_id(db, input)
	testing.expect(t, ok)
	testing.expect(t, album.title == "Test title")

}
