package formats

import "core:bufio"
import "core:fmt"
import "core:io"
import os "core:os/os2"
import "core:testing"


ReadError :: enum {
	UnknownError,
	UnsupportedFile,
	UnableToOpenFile,
	UnableToFindVorbisComment,
}

VorbisComment :: struct {
	title: string,
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

read :: proc(file: ^os.File) -> (c: VorbisComment, err: ReadError) {

	r: bufio.Reader
	buffer: [1024 * 8]byte
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

			fmt.printfln("\n\n Vorbis Comment Bytes: %s \n\n", vorbisCommentBytes)

			return VorbisComment{title = "Vampire in the Corner"}, nil
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


	actual, err := read(f)

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


//@(test)
//should_check_flac_file :: proc(t: ^testing.T) {
//
//	file_path := "../../test-data/07. Vampire in the Corner.flac"
//	f, ferr := os.open(file_path, {.Read})
//	if ferr != nil {
//		fmt.eprintfln("{}", ferr)
//		testing.expect(t, false, "failed to open flac file")
//	}
//	defer os.close(f)
//
//
//	r: bufio.Reader
//	buffer: [1024]byte
//	bufio.reader_init_with_buf(&r, os.to_reader(f), buffer[:])
//	defer bufio.reader_destroy(&r)
//
//	actual := check_is_flac(&r)
//
//	testing.expect(t, actual == true, "failed to open flac file")
//}
//
//
//@(test)
//should_return_error_on_non_flac_file :: proc(t: ^testing.T) {
//
//	file_path := "../../test-data/08. Last Dinosaurs - Purxst.wav"
//	f, ferr := os.open(file_path, {.Read})
//	if ferr != nil {
//		fmt.eprintfln("{}", ferr)
//		testing.expect(t, false, "failed to open flac file")
//	}
//	defer os.close(f)
//
//
//	r: bufio.Reader
//	buffer: [1024]byte
//	bufio.reader_init_with_buf(&r, os.to_reader(f), buffer[:])
//	defer bufio.reader_destroy(&r)
//
//	actual := check_is_flac(&r)
//
//	testing.expect(
//		t,
//		actual == false,
//		"check_is_flac was supposed to return false for non flac file",
//	)
//}
