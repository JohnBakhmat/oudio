package repo

import db_pkg "../"
import sqlite "../../../vendor/sqlite"
import sa "../../../vendor/sqlite/addons"
import types "../../core"
import "core:fmt"
import "core:strings"


new_file :: proc(
	db: ^sqlite.Connection,
	file: types.FileRecord,
	allocator := context.allocator,
) -> (
	new_id: types.File_Id,
	err: db_pkg.DatabaseErrors,
) {


	fmt.printfln("New File: %#v", file)

	id := db_pkg.gen_id("file", allocator)
	new_id = types.File_Id(id)

	rc := sa.execute(
		db,
		"INSERT INTO file (id, path, track_id) VALUES (?, ?, ?)",
		{
			{index = 1, value = id},
			{index = 2, value = file.path},
			{index = 3, value = string(file.track_id)},
		},
	)

	#partial switch rc {
	case .Constraint:
		return new_id, .UniqueConstraint
	case .Done, .Ok:
		return new_id, .None
	case:
		fmt.eprintfln("new_file failed with result code: %v", rc)
		return new_id, .UnknownError
	}
}
