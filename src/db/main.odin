package db


import sqlite "../../vendor/sqlite"
import sa "../../vendor/sqlite/addons"
import t "../core"

DB_URL :: "oudio.db"

new_album :: proc(
	db: ^sqlite.Connection,
	album: t.Album,
	allocator := context.allocator,
) -> sqlite.Result_Code {

	return sa.execute(
		db,
		"INSERT INTO album (id,title,mb_id,mb_rg_id) values (?,?,?,?)",
		{{1, "test"}, {2, album.title}, {3, album.mb_id.?}, {4, album.mb_rg_id.?}},
	)
}
