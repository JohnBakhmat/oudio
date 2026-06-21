package repo

import db_pkg "../"
import sqlite "../../../vendor/sqlite"
import types "../../core"
import "core:testing"

@(test)
should_create_new_album :: proc(t: ^testing.T) {
	db := open_test_db(t)
	defer sqlite.close(db)

	title := db_pkg.gen_id("album_title")
	defer delete(title)

	album := types.Album {
		title = title,
	}
	new_id, err := new_album(db, album)
	defer delete(string(new_id))

	testing.expect(t, err == .None)
	testing.expect(t, len(string(new_id)) > 0)
}

@(test)
should_get_album_by_id :: proc(t: ^testing.T) {
	db := open_test_db(t)
	defer sqlite.close(db)

	title := db_pkg.gen_id("album_by_id")
	defer delete(title)

	album := types.Album {
		title = title,
	}
	new_id, err := new_album(db, album)
	testing.expect(t, err == .None)

	found, ok := get_album_by_id(db, string(new_id))
	defer if ok do types.delete_album(found)
	defer delete(string(new_id))

	testing.expect(t, ok)
	testing.expect(t, found.title == title)
	testing.expect(t, string(found.id) == string(new_id))
}

@(test)
should_get_album_by_title :: proc(t: ^testing.T) {
	db := open_test_db(t)
	defer sqlite.close(db)

	title := db_pkg.gen_id("album_lookup")
	defer delete(title)

	album := types.Album {
		title = title,
	}
	new_id, err := new_album(db, album)
	testing.expect(t, err == .None)
	defer delete(string(new_id))

	found, ok := get_album_by_title(db, title)
	defer if ok do types.delete_album(found)

	testing.expect(t, ok)
	testing.expect(t, found.title == title)
}

@(test)
should_get_or_create_album :: proc(t: ^testing.T) {
	db := open_test_db(t)
	defer sqlite.close(db)

	title := db_pkg.gen_id("album_upsert")
	defer delete(title)

	album := types.Album {
		title = title,
	}

	first_id, first_ok := get_or_create_album(db, album)
	testing.expect(t, first_ok)
	testing.expect(t, len(string(first_id)) > 0)

	second_id, second_ok := get_or_create_album(db, album)
	testing.expect(t, second_ok)
	testing.expect(t, string(second_id) == string(first_id))

	delete(string(first_id))
	delete(string(second_id))
}

@(test)
should_get_or_create_album_by_mb_id_when_title_differs :: proc(t: ^testing.T) {
	db := open_test_db(t)
	defer sqlite.close(db)

	mb_id := "ca69373e-daf4-4605-9353-5ae4a4f2556e"

	first := types.Album {
		title = "Persona 5 OST",
		mb_id = mb_id,
	}
	first_id, first_ok := get_or_create_album(db, first)
	testing.expect(t, first_ok)
	defer delete(string(first_id))

	second := types.Album {
		title = "「ペルソナ5」オリジナル・サウンドトラック",
		mb_id = mb_id,
	}
	second_id, second_ok := get_or_create_album(db, second)
	testing.expect(t, second_ok)
	defer delete(string(second_id))

	testing.expect(t, string(second_id) == string(first_id))
}
