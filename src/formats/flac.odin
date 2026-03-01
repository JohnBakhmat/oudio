package formats

import "core:bufio"
import "core:encoding/endian"
import "core:fmt"
import "core:io"
import "core:mem"
import os "core:os/os2"
import "core:strconv"
import "core:strings"
import "core:testing"

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
}

destroy_vorbis_comment :: proc(c: VorbisComment, allocator: mem.Allocator = context.allocator) {
	delete(c.title, allocator)
	delete(c.album, allocator)
	delete(c.album_artist, allocator)
	delete(c.artists)
}

check_is_flac :: proc(r: ^bufio.Reader) -> bool {

	marker := make([]byte, 4)
	defer delete(marker)
	n, err := bufio.reader_read(r, marker)

	if err != nil || n != 4 {
		return false
	}

	fmt.printfln("Marker: %v", string(marker))

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
	fmt.printfln("parse_header called, len=%d, data=%v", len(arr), arr)

	assert(len(arr) >= 4)

	fmt.printfln(
		"Before return - arr[0]=%d arr[1]=%d arr[2]=%d arr[3]=%d",
		arr[0],
		arr[1],
		arr[2],
		arr[3],
	)

	return Header {
		is_last = arr[0] & 0x80 != 0,
		stream_info = arr[0] & 0x7F,
		length = u32(arr[1]) << 16 | u32(arr[2]) << 8 | u32(arr[3]),
	}
}

parse_vorbis_comment :: proc(arr: ^[]byte) -> (c: VorbisComment, err: ReadError) {
	fmt.printfln("Vorbis Comment Bytes: %d", len(arr))

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
	fmt.printfln("Vendor string length %d", vendor_str_len)
	cursor += 4

	if (vendor_str_len > MAX_FIELD_LENGTH || cursor + vendor_str_len > length) {
		return VorbisComment{}, .UnableToReadVendorString
	}

	// Read vendor string
	vendor_str := string(arr[cursor:cursor + vendor_str_len])
	fmt.printfln("Vendor string %s", vendor_str)
	cursor += vendor_str_len

	//Read number of fields
	if cursor + 4 > u32(len(arr)) {
		return VorbisComment{}, .UnknownError // TODO: descriptive error
	}
	num_fields, ok = endian.get_u32(arr[cursor:cursor + 4], .Little)
	if (!ok) {
		return VorbisComment{}, .UnknownError
	}
	fmt.printfln("Number of fields %d", num_fields)
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
		fmt.printfln("Field length %d", field_length)

		cursor += 4

		field := string(arr[cursor:cursor + field_length])
		fmt.printfln("field %v", field)

		pair := strings.split(field, "=")
		defer delete(pair)
		if (len(pair) != 2) {
			return VorbisComment{}, .UnknownError
		}
		key := pair[0]
		value := pair[1]

		fmt.printfln("key |%v| value |%v| ", key, value)


		switch key {
		case "ALBUM":
			comment.album = strings.clone(value)
		case "ARTIST":
			append(&artists, strings.clone(value))
		case "ALBUM ARTIST":
			comment.album_artist = strings.clone(value)
		case "TITLE":
			comment.title = strings.clone(value)
		case "TRACK NUMBER":
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

		fmt.printfln("HeaderBytes: %v", headerBytes)

		fmt.printfln("About to call parse_header")
		header := parse_header(headerBytes)
		fmt.printfln("parse_header returned successfully")

		fmt.printfln(
			"Parsed header: stream_info=%d, length=%d, is_last=%v",
			header.stream_info,
			header.length,
			header.is_last,
		)


		if (header.stream_info == VORBIS_COMMENT) {
			fmt.printfln("Found Vorbis Comment")

			vorbisCommentBytes := make([]byte, header.length)
			defer delete(vorbisCommentBytes)

			s := bufio.reader_to_stream(&r)

			vn, verr := io.read_full(s, vorbisCommentBytes)
			if verr != nil || cast(u32)vn != header.length {
				fmt.printfln("Failed to read voribs comment as bytes %v %d", verr, vn)
				return VorbisComment{}, .UnknownError
			}

			return parse_vorbis_comment(&vorbisCommentBytes)
		}

		if (header.is_last) {
			return VorbisComment{}, .UnableToFindVorbisComment
		}

		skip := header.length
		fmt.printfln("Skip: %i", skip)
		x, xerr := bufio.reader_discard(&r, int(skip))
		if xerr != nil {
			fmt.printfln("Discard error: %v", xerr)
			return VorbisComment{}, .UnknownError
		}
		if x != int(skip) {
			fmt.printfln("Discard incomplete: wanted %d, got %d", skip, x)
			// Need to handle partial discard
		}

		fmt.printfln("Discarded: %i", x)

	}


	return VorbisComment{}, nil
}

@(test)
should_read_flac_file :: proc(t: ^testing.T) {
	file_path := "../../test-data/07. Vampire in the Corner.flac"
	f, ferr := os.open(file_path, {.Read})
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
	f, ferr := os.open(file_path, {.Read})
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
	f, ferr := os.open(file_path, {.Read})
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
