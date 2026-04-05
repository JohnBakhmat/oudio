package repo

import db_pkg "../"
import sqlite "../../../vendor/sqlite"
import types "../../core"
import "core:testing"

create_album_for_track_test :: proc(t: ^testing.T, db: ^sqlite.Connection) -> types.Album_Id {
	title := db_pkg.gen_id("track_album")
	defer delete(title)

	album := types.Album{title = title}
	album_id, err := new_album(db, album)
	testing.expect(t, err == .None)

	return album_id
}

@(test)
should_create_new_track :: proc(t: ^testing.T) {
	db := open_test_db(t)
	defer sqlite.close(db)

	album_id := create_album_for_track_test(t, db)
	defer delete(string(album_id))

	track_title := db_pkg.gen_id("track_title")
	defer delete(track_title)

	track := types.Track{
		title        = track_title,
		track_number = 1,
		album_id     = album_id,
	}

	track_id, err := new_track(db, track)
	defer delete(string(track_id))

	testing.expect(t, err == .None)
	testing.expect(t, len(string(track_id)) > 0)
}

@(test)
should_get_track_by_title :: proc(t: ^testing.T) {
	db := open_test_db(t)
	defer sqlite.close(db)

	album_id := create_album_for_track_test(t, db)
	defer delete(string(album_id))

	track_title := db_pkg.gen_id("track_lookup")
	defer delete(track_title)

	track := types.Track{
		title        = track_title,
		track_number = 2,
		album_id     = album_id,
	}

	track_id, err := new_track(db, track)
	testing.expect(t, err == .None)
	defer delete(string(track_id))

	found, ok := get_track_by_title(db, track_title, album_id)
	defer if ok do types.delete_track(found)

	testing.expect(t, ok)
	testing.expect(t, found.title == track_title)
	testing.expect(t, string(found.album_id) == string(album_id))
}

@(test)
should_get_or_create_track :: proc(t: ^testing.T) {
	db := open_test_db(t)
	defer sqlite.close(db)

	album_id := create_album_for_track_test(t, db)
	defer delete(string(album_id))

	track_title := db_pkg.gen_id("track_upsert")
	defer delete(track_title)

	track := types.Track{
		title        = track_title,
		track_number = 3,
		album_id     = album_id,
	}

	first_id, first_ok := get_or_create_track(db, track)
	testing.expect(t, first_ok)
	testing.expect(t, len(string(first_id)) > 0)

	second_id, second_ok := get_or_create_track(db, track)
	testing.expect(t, second_ok)
	testing.expect(t, string(second_id) == string(first_id))

	delete(string(first_id))
	delete(string(second_id))
}
