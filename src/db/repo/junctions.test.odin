package repo

import db_pkg "../"
import sqlite "../../../vendor/sqlite"
import types "../../core"
import "core:testing"

@(test)
should_create_artist_album_junction :: proc(t: ^testing.T) {
	db := open_test_db(t)
	defer sqlite.close(db)

	artist_name := db_pkg.gen_id("junction_artist")
	defer delete(artist_name)
	artist := types.Artist {
		name = artist_name,
	}
	artist_id, artist_err := new_artist(db, artist)
	testing.expect(t, artist_err == .None)
	defer delete(string(artist_id))

	album_title := db_pkg.gen_id("junction_album")
	defer delete(album_title)
	album := types.Album {
		title = album_title,
	}
	album_id, album_err := new_album(db, album)
	testing.expect(t, album_err == .None)
	defer delete(string(album_id))

	link := types.ArtistAlbum {
		artist_id = artist_id,
		album_id  = album_id,
	}

	err := new_artist_album(db, link)
	testing.expect(t, err == .None)
}

@(test)
should_ignore_duplicate_artist_album_junction :: proc(t: ^testing.T) {
	db := open_test_db(t)
	defer sqlite.close(db)

	artist_name := db_pkg.gen_id("junction_artist_dupe")
	defer delete(artist_name)
	artist := types.Artist {
		name = artist_name,
	}
	artist_id, artist_err := new_artist(db, artist)
	testing.expect(t, artist_err == .None)
	defer delete(string(artist_id))

	album_title := db_pkg.gen_id("junction_album_dupe")
	defer delete(album_title)
	album := types.Album {
		title = album_title,
	}
	album_id, album_err := new_album(db, album)
	testing.expect(t, album_err == .None)
	defer delete(string(album_id))

	link := types.ArtistAlbum {
		artist_id = artist_id,
		album_id  = album_id,
	}

	first_err := new_artist_album(db, link)
	second_err := new_artist_album(db, link)

	testing.expect(t, first_err == .None)
	testing.expect(t, second_err == .None)
}
