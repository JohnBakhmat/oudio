package repo

import db_pkg "../"
import sqlite "../../../vendor/sqlite"
import types "../../core"
import "core:testing"

@(test)
should_create_new_artist :: proc(t: ^testing.T) {
	db := open_test_db(t)
	defer sqlite.close(db)

	artist := types.Artist{
		name = db_pkg.gen_id("artist_name"),
	}

	new_id, err := new_artist(db, artist)
	defer delete(string(new_id))
	defer delete(artist.name)

	testing.expect(t, err == .None)
	testing.expect(t, len(string(new_id)) > 0)
}

@(test)
should_create_new_artist_batch :: proc(t: ^testing.T) {
	db := open_test_db(t)
	defer sqlite.close(db)

	artists := []types.Artist{
		{name = "artist_batch_1"},
		{name = "artist_batch_2"},
		{name = "artist_batch_3"},
	}

	rc := new_artist_batch(db, artists)
	testing.expect(t, rc == .Ok)
}

@(test)
should_get_artist_by_name :: proc(t: ^testing.T) {
	db := open_test_db(t)
	defer sqlite.close(db)

	name := db_pkg.gen_id("artist_lookup")
	defer delete(name)

	artist := types.Artist{name = name}
	new_id, err := new_artist(db, artist)
	defer delete(string(new_id))
	testing.expect(t, err == .None)

	found, ok := get_artist_by_name(db, name)
	defer if ok do types.delete_artist(found)

	testing.expect(t, ok)
	testing.expect(t, found.name == name)
	testing.expect(t, len(string(found.id)) > 0)
}

@(test)
should_get_or_create_artist :: proc(t: ^testing.T) {
	db := open_test_db(t)
	defer sqlite.close(db)

	name := db_pkg.gen_id("artist_upsert")
	defer delete(name)

	artist := types.Artist{name = name}

	first_id, first_ok := get_or_create_artist(db, artist)
	testing.expect(t, first_ok)
	testing.expect(t, len(string(first_id)) > 0)

	second_id, second_ok := get_or_create_artist(db, artist)
	testing.expect(t, second_ok)
	testing.expect(t, string(second_id) == string(first_id))

	delete(string(first_id))
	delete(string(second_id))
}
