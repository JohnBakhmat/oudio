package repo

import sqlite "../../../vendor/sqlite"
import sa "../../../vendor/sqlite/addons"
import "core:os"
import "core:slice"
import "core:strings"
import "core:testing"

open_test_db :: proc(t: ^testing.T) -> ^sqlite.Connection {
	db: ^sqlite.Connection
	rc := sqlite.open(":memory:", &db)
	testing.expect(t, rc == .Ok)

	apply_test_migrations(t, db)
	return db
}

apply_test_migrations :: proc(t: ^testing.T, db: ^sqlite.Connection) {
	migration_dir := "src/db/migrations"

	dir_entries, err := os.read_all_directory_by_path(migration_dir, context.allocator)
	testing.expect(t, err == nil)
	defer os.file_info_slice_delete(dir_entries, context.allocator)

	only_sql := slice.filter(dir_entries, proc(x: os.File_Info) -> bool {
		return strings.has_suffix(x.fullpath, ".sql")
	})
	defer delete(only_sql)

	slice.sort_by(only_sql, proc(a, b: os.File_Info) -> bool {
		return strings.compare(a.fullpath, b.fullpath) < 0
	})

	for migration in only_sql {
		apply_sql_file(t, db, migration.fullpath)
	}
}

apply_sql_file :: proc(t: ^testing.T, db: ^sqlite.Connection, path: string) {
	data, err := os.read_entire_file_from_path(path, context.allocator)
	testing.expect(t, err == nil)
	defer delete(data, context.allocator)

	text := string(data)
	expressions := strings.split(text, ";")
	defer delete(expressions)

	for exp in expressions {
		trimmed := strings.trim_space(exp)
		if len(trimmed) == 0 do continue
		testing.expect(t, sa.execute(db, trimmed) == .Ok)
	}
}
