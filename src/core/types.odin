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

Artist :: struct {
	id:        Artist_Id,
	name:      string,
	acoust_id: Maybe(string),
	mb_id:     Maybe(string), // MUSICBRAINZ_ARTISTID,
}

Album :: struct {
	id:       Album_Id,
	title:    string,
	mb_id:    Maybe(string), // MUSICBRAINZ_ALBUMID,
	mb_rg_id: Maybe(string), // MUSICBRAINZ_RELEASEGROUPID,
}

// Junctions
ArtistAlbum :: struct {
	artist_id: string,
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
