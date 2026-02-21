package formats

import "core:bufio"
import "core:fmt"
import os "core:os/os2"
import "core:testing"


is_flac :: proc(r: ^bufio.Reader) -> bool {

	marker := make([]byte, 4)
	defer delete(marker)
	n, err := bufio.reader_read(r, marker)

	if err != nil || n != 4 {
		return false
	}

	if string(marker) != "fLaC" {
		return false
	}

	return true
}

read :: proc(file: ^os.File) {

	r: bufio.Reader
	buffer: [1024]byte
	bufio.reader_init_with_buf(&r, os.to_reader(file), buffer[:])
	defer bufio.reader_destroy(&r)

	// Check marker

	marker := make([]byte, 4)
	n, err := bufio.reader_read(&r, marker)

	if err != nil || n != 4 {
		return // file is corrupted
	}

	if string(marker) != "fLaC" {
		return // not flac
	}

	fmt.printfln("{}", string(marker))

	return
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


	r: bufio.Reader
	buffer: [1024]byte
	bufio.reader_init_with_buf(&r, os.to_reader(f), buffer[:])
	defer bufio.reader_destroy(&r)

	actual := is_flac(&r)

	testing.expect(t, actual == true, "failed to open flac file")
}
