package db

import "core:fmt"
import "core:mem"
import "core:os"
import "core:path/filepath"
import "core:slice"
import "core:strings"

import sqlite "../../vendor/sqlite"
import sa "../../vendor/sqlite/addons"

DB_URL :: "oudio.db"

main :: proc() {

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


	migration_dir, err := filepath.join({#directory, "migrations"}, context.allocator)
	defer delete(migration_dir)

	assert(err == nil, "Unable to resolve migrations folder path")

	dir_entries, err2 := os.read_all_directory_by_path(migration_dir, context.allocator)
	defer os.file_info_slice_delete(dir_entries, context.allocator)

	assert(err2 == nil, "Unable to find migration list from folder")

	only_sql := slice.filter(dir_entries, proc(x: os.File_Info) -> bool {
		return strings.has_suffix(x.fullpath, ".sql")
	})
	defer delete(only_sql)

	slice.sort_by(only_sql, proc(a, b: os.File_Info) -> bool {
		return strings.compare(a.fullpath, b.fullpath) < 0
	})

	fmt.printfln("Entries: %#v", only_sql)

	// Apply


	db: ^sqlite.Connection

	if rc := sqlite.open(DB_URL, &db); rc != .Ok {
		fmt.panicf("failed to open database. result code {}", rc)
	}
	fmt.printfln("connected to database")

	defer {
		sqlite.close(db)
		fmt.printfln("\nconnection closed")
	}

	for migration in only_sql {
		apply(db, migration.fullpath)
	}
}

apply :: proc(db: ^sqlite.Connection, path: string, allocator := context.allocator) {

	data, err := os.read_entire_file_from_path(path, allocator)
	assert(err == nil, "Unable to apply migration")
	defer delete(data, allocator)

	text := string(data)

	expressions := strings.split(text, ";")
	defer delete(expressions)

	trimmed: string
	for exp in expressions {
		trimmed = strings.trim_space(exp)
		if (len(trimmed) == 0) {continue}

		fmt.printfln("Expressions: |%#v| \nApplying", trimmed)

		rc := sa.execute(db, trimmed)
		assert(rc == .Ok)

		fmt.printfln("Applied successfully")
	}
	delete(trimmed)

	//	rc := sa.execute(db, text)
	//	assert(rc == .Ok)
}
