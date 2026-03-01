package library

import formats "../formats"
import "core:fmt"
import "core:mem"
import os "core:os/os2"
import "core:slice"
import "core:strings"
import "core:testing"


is_flac :: proc(fi: os.File_Info) -> bool {
	return strings.ends_with(fi.name, ".flac")
}

read_dir :: proc(
	path: string,
	allocator: mem.Allocator = context.allocator,
) -> (
	result: []formats.VorbisComment,
	ok: bool,
) {
	real_path, err := os.get_absolute_path(path, allocator)
	defer delete(real_path)


	if err != nil {
		return nil, false
	}

	dir_entries: []os.File_Info
	dir_entries, err = os.read_all_directory_by_path(real_path, allocator)
	defer delete(dir_entries)

	fmt.printfln("Dir entries: %v", dir_entries)

	if err != nil {
		return nil, false
	}

	dir_slice := dir_entries[:]
	only_flac := slice.filter(dir_slice, is_flac)
	defer delete(only_flac)

	fmt.printfln("only flac: %v", only_flac)

	length := len(only_flac)

	res := make([]formats.VorbisComment, length)
	defer delete(res)

	file: ^os.File
	ferr: os.Error

	for i in 0 ..< length {
		entry := only_flac[i]

		fmt.printfln("entry %v", entry)
		file, ferr = os.open(entry.fullpath, {.Read})
		defer os.close(file)
		if ferr != nil {
			return nil, false
		}
		comment, err := formats.flac_read(file)
		if err != nil {
			return nil, false
		}
		res[i] = comment
		os.close(file)
	}

	return res, true
}

@(test)
should_read_dir :: proc(t: ^testing.T) {
	dir_path := "../../test-data"

	result, ok := read_dir(dir_path)

	fmt.printfln("Results: %v", result)

	testing.expect(t, ok)

	for x in result {
		formats.destroy_vorbis_comment(x)
	}
}
