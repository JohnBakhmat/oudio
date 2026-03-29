package core

Track_Id :: distinct string
Artist_Id :: distinct string
Album_Id :: distinct string


Track :: struct {
	id:           Track_Id,
	title:        string,
	track_number: u8,
	mb_id:        Maybe(string), // MUSICBRAINZ_TRACKID,
	album_id:     Album_Id,
}

delete_track :: proc(track: Track, allocator := context.allocator) {
	delete(string(track.id))
	delete(string(track.album_id))
	delete(track.title)

	if mb_id, ok := track.mb_id.?; ok {
		delete(mb_id)
	}
}

Artist :: struct {
	id:        Artist_Id,
	name:      string,
	acoust_id: Maybe(string),
	mb_id:     Maybe(string), // MUSICBRAINZ_ARTISTID,
}

delete_artist :: proc(artist: Artist, allocator := context.allocator) {
	delete(string(artist.id))
	delete(artist.name)

	if acoust_id, ok := artist.acoust_id.?; ok {
		delete(acoust_id)
	}

	if mb_id, ok := artist.mb_id.?; ok {
		delete(mb_id)
	}
}


Album :: struct {
	id:       Album_Id,
	title:    string,
	mb_id:    Maybe(string), // MUSICBRAINZ_ALBUMID,
	mb_rg_id: Maybe(string), // MUSICBRAINZ_RELEASEGROUPID,
}

delete_album :: proc(album: Album, allocator := context.allocator) {
	delete(string(album.id))
	delete(album.title)

	if mb_id, ok := album.mb_id.?; ok {
		delete(mb_id)
	}

	if mb_rg_id, ok := album.mb_rg_id.?; ok {
		delete(mb_rg_id)
	}
}


// Junctions
ArtistAlbum :: struct {
	artist_id: Artist_Id,
	album_id:  Album_Id,
}


// Api
AlbumFull :: struct {
	album:   Album,
	artists: []Artist,
	tracks:  []struct {
		track:   Track,
		artists: []Artist,
	},
}

AlbumShort :: struct {
	album:   Album,
	artists: []Artist,
}
