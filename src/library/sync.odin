package library

import sqlite "../../vendor/sqlite"
import sa "../../vendor/sqlite/addons"
import types "../core"
import db "../db/repo"
import formats "../formats"
import "core:fmt"
import "core:mem"
import "core:mem/virtual"
import vmem "core:mem/virtual"
import "core:os"
import "core:path/filepath"
import "core:slice"
import "core:strings"
import "core:testing"


main :: proc() {

	dir_path := "../../test-data/"
	input_path, test_err := filepath.join({#directory, dir_path}, context.temp_allocator)
	assert(test_err == nil)

	arena: vmem.Arena
	arena_err := vmem.arena_init_growing(&arena)
	defer vmem.arena_destroy(&arena)

	assert(arena_err == nil, "Failed to initialize arena")

	arena_allocator := vmem.arena_allocator(&arena)

	paths_dyn := walk_dir(input_path, arena_allocator)
	defer delete_dynamic_array(paths_dyn)

	paths := paths_dyn[:]


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


	db_conn: ^sqlite.Connection

	if rc := sqlite.open("oudio.db", &db_conn); rc != .Ok {
		fmt.panicf("failed to open database. result code {}", rc)
	}
	fmt.printfln("connected to database")

	defer {
		sqlite.close(db_conn)
		fmt.printfln("connection closed")
	}

	rc: sqlite.Result_Code


	for path in paths {
		fmt.printfln("Path: %s", path)

		file, ferr := os.open(path, {.Read})
		assert(ferr == nil)

		flac, flac_err := formats.flac_read(file)

		os.close(file)
		assert(flac_err == nil)

		album := types.Album {
			id       = "",
			title    = flac.album,
			mb_id    = flac.mb_id,
			mb_rg_id = flac.mb_rg_id,
		}

		artist := types.Artist {
			id   = "",
			name = flac.album_artist,
		}

		fmt.printfln("Flac Comment %#v, artist %#v album %#v", flac, artist, album)

		new_id, err := db.new_album(db_conn, album)
		defer delete(new_id)
		assert(err == .None || err == .UniqueConstraint)
		fmt.printfln("New album |%v| with id |%v|", album.title, new_id)

		rc = db.new_artist(db_conn, artist)
		assert(rc == .Ok)
		formats.destroy_vorbis_comment(flac)
	}

}
