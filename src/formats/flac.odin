package formats

import "core:bufio"
import "core:encoding/endian"
import "core:fmt"
import "core:io"
import "core:mem"
import "core:os"
import "core:path/filepath"
import "core:strconv"
import "core:strings"
import "core:testing"
import app_core "../core"

ReadError :: enum {
	UnknownError,
	UnsupportedFile,
	UnableToOpenFile,
	UnableToFindVorbisComment,
	UnableToReadVendorString,
	Invalid_Vendor_String,
	Unable_To_Read_Field_Length,
}


VorbisComment :: struct {
	title:        string,
	album:        string,
	album_artist: string,
	track_number: u8,
	artists:      []string,
	mb_id:        Maybe(string),
	mb_rg_id:     Maybe(string),
	mb_artist_id: Maybe(string),
}

destroy_vorbis_comment :: proc(c: VorbisComment, allocator: mem.Allocator = context.allocator) {
	delete(c.title, allocator)
	delete(c.album, allocator)
	delete(c.album_artist, allocator)
	delete(c.artists, allocator)
	if mb_id, ok := c.mb_id.?; ok {
		delete(mb_id, allocator)
	}

	if mb_rg_id, ok := c.mb_rg_id.?; ok {
		delete(mb_rg_id, allocator)
	}

	if mb_artist_id, ok := c.mb_artist_id.?; ok {
		delete(mb_artist_id, allocator)
	}
}

check_is_flac :: proc(r: ^bufio.Reader) -> bool {

	marker := make([]byte, 4)
	defer delete(marker)
	n, err := bufio.reader_read(r, marker)

	if err != nil || n != 4 {
		return false
	}

	app_core.log_debugf("%s %s", app_core.colorize("marker", app_core.ANSI_CYAN), app_core.colorize(string(marker), app_core.ANSI_GREEN))

	if string(marker) != "fLaC" {
		return false
	}

	return true
}

MAX_METADATA_BLOCK :: 128
BLOCK_HEADER_SIZE :: 4
VORBIS_COMMENT :: 4
MAX_VORBIS_FIELDS :: 10000 // Reasonable limit for metadata fields
MAX_FIELD_LENGTH :: 1024 * 1024 // 1MB max per field

Header :: struct {
	is_last:     bool,
	stream_info: u8,
	length:      u32,
}

parse_header :: proc(arr: []byte) -> Header {
	app_core.log_debugf("%s len=%d data=%v", app_core.colorize("parse_header", app_core.ANSI_CYAN), len(arr), arr)

	assert(len(arr) >= 4)

	app_core.log_debugf("%s b0=%d b1=%d b2=%d b3=%d", app_core.colorize("header-bytes", app_core.ANSI_DIM), arr[0], arr[1], arr[2], arr[3])

	return Header {
		is_last = arr[0] & 0x80 != 0,
		stream_info = arr[0] & 0x7F,
		length = u32(arr[1]) << 16 | u32(arr[2]) << 8 | u32(arr[3]),
	}
}

parse_vorbis_comment :: proc(arr: ^[]byte) -> (c: VorbisComment, err: ReadError) {
	app_core.log_debugf("%s %s", app_core.colorize("vorbis-bytes", app_core.ANSI_CYAN), app_core.colorize(fmt.tprintf("%d", len(arr)), app_core.ANSI_GREEN))

	length := u32(len(arr))
	cursor: u32 = 0
	vendor_str_len: u32
	num_fields: u32
	ok: bool = true

	if cursor + 4 > u32(len(arr)) {
		return VorbisComment{}, .UnknownError // TODO: descriptive error
	}

	// Read vendor string length
	vendor_str_len, ok = endian.get_u32(arr[cursor:cursor + 4], .Little)
	if (!ok) {
		return VorbisComment{}, .UnableToReadVendorString
	}
	app_core.log_debugf("%s %s", app_core.colorize("vendor-length", app_core.ANSI_CYAN), app_core.colorize(fmt.tprintf("%d", vendor_str_len), app_core.ANSI_GREEN))
	cursor += 4

	if (vendor_str_len > MAX_FIELD_LENGTH || cursor + vendor_str_len > length) {
		return VorbisComment{}, .UnableToReadVendorString
	}

	// Read vendor string
	vendor_str := string(arr[cursor:cursor + vendor_str_len])
	app_core.log_debugf("%s %s", app_core.colorize("vendor", app_core.ANSI_CYAN), app_core.colorize(vendor_str, app_core.ANSI_GREEN))
	cursor += vendor_str_len

	//Read number of fields
	if cursor + 4 > u32(len(arr)) {
		return VorbisComment{}, .UnknownError // TODO: descriptive error
	}
	num_fields, ok = endian.get_u32(arr[cursor:cursor + 4], .Little)
	if (!ok) {
		return VorbisComment{}, .UnknownError
	}
	app_core.log_debugf("%s %s", app_core.colorize("fields", app_core.ANSI_CYAN), app_core.colorize(fmt.tprintf("%d", num_fields), app_core.ANSI_GREEN))
	if (num_fields > MAX_VORBIS_FIELDS) {
		return VorbisComment{}, .UnknownError
	}
	cursor += 4

	artists: [dynamic]string

	// Read fields
	comment: VorbisComment
	for i in 0 ..< num_fields {

		if cursor + 4 > u32(len(arr)) {
			return VorbisComment{}, .UnknownError // TODO: descriptive error
		}

		field_length: u32

		field_length, ok = endian.get_u32(arr[cursor:cursor + 4], .Little)
		if (!ok) {
			return VorbisComment{}, .Unable_To_Read_Field_Length
		}

		if (field_length > MAX_FIELD_LENGTH || cursor + field_length > length) {
			return VorbisComment{}, .UnknownError
		}
		app_core.log_debugf("%s %s", app_core.colorize("field-length", app_core.ANSI_DIM), app_core.colorize(fmt.tprintf("%d", field_length), app_core.ANSI_GREEN))

		cursor += 4

		field := string(arr[cursor:cursor + field_length])
		app_core.log_debugf("%s %s", app_core.colorize("field", app_core.ANSI_YELLOW), app_core.colorize(field, app_core.ANSI_MAGENTA))

		pair := strings.split(field, "=")
		defer delete(pair)
		if (len(pair) != 2) {
			return VorbisComment{}, .UnknownError
		}
		key := pair[0]
		value := pair[1]

		app_core.log_debugf("%s %s   %s %s", app_core.colorize("key", app_core.ANSI_CYAN), app_core.colorize(key, app_core.ANSI_YELLOW), app_core.colorize("value", app_core.ANSI_CYAN), app_core.colorize(value, app_core.ANSI_GREEN))


		switch key {
		case "ALBUM":
			comment.album = strings.clone(value)
		case "ARTIST":
			append(&artists, strings.clone(value))
		case "ALBUM ARTIST":
			comment.album_artist = strings.clone(value)
		case "TITLE":
			comment.title = strings.clone(value)
		case "MUSICBRAINZ_ALBUMID":
			comment.mb_id = strings.clone(value)
		case "MUSICBRAINZ_RELEASEGROUPID":
			comment.mb_rg_id = strings.clone(value)
		case "MUSICBRAINZ_ARTISTID":
			comment.mb_artist_id = strings.clone(value)
		case "TRACKNUMBER":
			track_number, ok := strconv.parse_int(value)
			if !ok {
				track_number = 0
			}
			comment.track_number = u8(track_number)
		}
		cursor += field_length
	}

	comment.artists = artists[:]

	if comment.album_artist == "" && len(comment.artists) > 0 {
		comment.album_artist = comment.artists[0]
	}

	app_core.log_infof("%s %#v", app_core.colorize("parsed-comment", app_core.ANSI_CYAN), comment)

	return comment, nil
}


flac_read :: proc(file: ^os.File) -> (c: VorbisComment, err: ReadError) {

	r: bufio.Reader
	buffer: [1024]byte
	stream := os.to_reader(file)
	bufio.reader_init_with_buf(&r, stream, buffer[:])
	defer bufio.reader_destroy(&r)

	// Check marker
	is_flac := check_is_flac(&r)
	if !is_flac {
		return VorbisComment{}, .UnsupportedFile
	}

	headerBytes := make([]byte, BLOCK_HEADER_SIZE)
	defer delete(headerBytes)
	for i in 0 ..< MAX_METADATA_BLOCK {
		n, err := bufio.reader_read(&r, headerBytes)
		if err != nil || n != BLOCK_HEADER_SIZE {
			return VorbisComment{}, .UnknownError
		}

		app_core.log_debugf("%s %v", app_core.colorize("header-bytes", app_core.ANSI_DIM), headerBytes)

		header := parse_header(headerBytes)

		app_core.log_debugf(
			"%s type=%s length=%s is_last=%v",
			app_core.colorize("header", app_core.ANSI_CYAN),
			app_core.colorize(fmt.tprintf("%d", header.stream_info), app_core.ANSI_YELLOW),
			app_core.colorize(fmt.tprintf("%d", header.length), app_core.ANSI_GREEN),
			header.is_last,
		)


		if (header.stream_info == VORBIS_COMMENT) {
			app_core.log_infof("%s", app_core.colorize("found vorbis comment block", app_core.ANSI_CYAN))

			vorbisCommentBytes := make([]byte, header.length)
			defer delete(vorbisCommentBytes)

			s := bufio.reader_to_stream(&r)

			vn, verr := io.read_full(s, vorbisCommentBytes)
			if verr != nil || cast(u32)vn != header.length {
				app_core.log_errorf("failed reading vorbis comment bytes err=%v read=%d expected=%d", verr, vn, header.length)
				return VorbisComment{}, .UnknownError
			}

			return parse_vorbis_comment(&vorbisCommentBytes)
		}

		if (header.is_last) {
			return VorbisComment{}, .UnableToFindVorbisComment
		}

		skip := header.length
		app_core.log_debugf("%s %s", app_core.colorize("skip", app_core.ANSI_DIM), app_core.colorize(fmt.tprintf("%d", skip), app_core.ANSI_GREEN))
		x, xerr := bufio.reader_discard(&r, int(skip))
		if xerr != nil {
			app_core.log_errorf("discard error: %v", xerr)
			return VorbisComment{}, .UnknownError
		}
		if x != int(skip) {
			app_core.log_errorf("discard incomplete: wanted %d, got %d", skip, x)
			// Need to handle partial discard
		}

		app_core.log_debugf("%s %d", app_core.colorize("discarded", app_core.ANSI_DIM), x)

	}


	return VorbisComment{}, nil
}

@(test)
should_read_flac_file :: proc(t: ^testing.T) {
	file_path := "../../test-data/07. Vampire in the Corner.flac"

	input_path, test_err := filepath.join({#directory, file_path}, context.temp_allocator)
	testing.expect(t, test_err == nil)

	f, ferr := os.open(input_path, {.Read})
	if ferr != nil {
		fmt.eprintfln("{}", ferr)
		testing.expect(t, false, "failed to open flac file")
	}
	defer os.close(f)


	actual, err := flac_read(f)
	defer destroy_vorbis_comment(actual)

	fmt.printfln("Actual: %v", actual)

	expected := "Vampire in the Corner"

	testing.expectf(
		t,
		err == nil && actual.title == expected,
		"Valid flac file wasn't parsed correctly. \n Expected %s | Actual: %s | Error: %v",
		expected,
		actual,
		err,
	)
}

@(test)
should_check_flac_file :: proc(t: ^testing.T) {

	file_path := "../../test-data/07. Vampire in the Corner.flac"

	input_path, test_err := filepath.join({#directory, file_path}, context.temp_allocator)
	testing.expect(t, test_err == nil)

	f, ferr := os.open(input_path, {.Read})
	if ferr != nil {
		fmt.eprintfln("{}", ferr)
		testing.expect(t, false, "failed to open flac file")
	}
	defer os.close(f)


	r: bufio.Reader
	buffer: [1024]byte
	bufio.reader_init_with_buf(&r, os.to_reader(f), buffer[:])
	defer bufio.reader_destroy(&r)

	actual := check_is_flac(&r)

	testing.expect(t, actual == true, "failed to open flac file")
}


@(test)
should_return_error_on_non_flac_file :: proc(t: ^testing.T) {

	file_path := "../../test-data/08. Last Dinosaurs - Purxst.wav"

	input_path, test_err := filepath.join({#directory, file_path}, context.temp_allocator)
	testing.expect(t, test_err == nil)

	f, ferr := os.open(input_path, {.Read})
	if ferr != nil {
		fmt.eprintfln("{}", ferr)
		testing.expect(t, false, "failed to open flac file")
	}
	defer os.close(f)


	r: bufio.Reader
	buffer: [1024]byte
	bufio.reader_init_with_buf(&r, os.to_reader(f), buffer[:])
	defer bufio.reader_destroy(&r)

	actual := check_is_flac(&r)

	testing.expect(
		t,
		actual == false,
		"check_is_flac was supposed to return false for non flac file",
	)
}
