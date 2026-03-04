package library

import formats "../formats"
import "core:fmt"
import "core:mem"
import "core:mem/virtual"
import vmem "core:mem/virtual"
import "core:os"
import "core:slice"
import "core:strings"
import "core:testing"

SUPPORTED_EXTENSIONS :: []string{"flac"}

is_supported :: proc(fi: os.File_Info) -> bool {
	for suffix in SUPPORTED_EXTENSIONS {
		if strings.has_suffix(fi.fullpath, suffix) {
			return true
		}
	}
	return false
}

ReadError :: enum {
	None,
	UnknownError,
	Unable_To_Resolve_Absolute_Path,
	Unable_To_Read_Dir,
}

// read_dir :: proc(
// 	path: string,
// 	allocator: mem.Allocator = context.allocator,
// ) -> (
// 	result: []formats.VorbisComment,
// 	error: ReadError,
// ) {
// 	real_path, err := os.get_absolute_path(path, allocator)
// 	defer delete(real_path)
//
// 	if err != nil {
// 		return nil, .Unable_To_Resolve_Absolute_Path
// 	}
//
// 	dir_entries: []os.File_Info
// 	dir_entries, err = os.read_all_directory_by_path(real_path, allocator)
// 	defer os.file_info_slice_delete(dir_entries, allocator)
//
// 	fmt.printfln("Dir entries: %v", dir_entries)
//
// 	if err != nil {
// 		return nil, .Unable_To_Read_Dir
// 	}
//
// 	dir_slice := dir_entries[:]
// 	only_flac := slice.filter(dir_slice, is_flac)
// 	defer delete(only_flac)
//
// 	fmt.printfln("only flac: %v", only_flac)
//
// 	length := len(only_flac)
//
// 	res := make([]formats.VorbisComment, length)
// 	defer delete(res)
//
// 	file: ^os.File
// 	ferr: os.Error
//
// 	for i in 0 ..< length {
// 		entry := only_flac[i]
//
// 		fmt.printfln("entry %v", entry)
// 		file, ferr = os.open(entry.fullpath, {.Read})
// 		if ferr != nil {
// 			os.close(file)
// 			continue
// 		}
// 		comment, err := formats.flac_read(file)
// 		if err != nil {
// 			os.close(file)
// 			continue
// 		}
// 		res[i] = comment
// 		os.close(file)
// 	}
//
// 	fmt.printfln("\nFound: %v", len(res))
//
// 	return res, nil
// }

walk_dir :: proc(path: string, allocator := context.allocator) -> [dynamic]string {

	w := os.walker_create(path)
	defer os.walker_destroy(&w)
	paths := make([dynamic]string, allocator)

	skipped := 0
	failed := 0

	for info in os.walker_walk(&w) {

		if path, err := os.walker_error(&w); err != nil {
			fmt.eprintfln("failed walking %s: %s", path, err)
			failed += 1
			continue
		}

		if !is_supported(info) {
			skipped += 1
			continue
		}

		fmt.printfln("Found: %s", info.fullpath)
		append(&paths, info.fullpath)
	}

	fmt.printfln("=== Total ===")
	fmt.printfln("Found: %d", len(paths))
	fmt.printfln("Skipped: %d", skipped)
	fmt.printfln("Failed: %d", failed)
	fmt.printfln("=============")

	return paths
}

@(test)
should_index_all_file_paths :: proc(t: ^testing.T) {
	dir_path := "../../test-data/"

	arena: vmem.Arena
	arena_err := vmem.arena_init_growing(&arena)
	defer vmem.arena_destroy(&arena)

	testing.expect(t, arena_err == nil, "Failed to initialize arena")


	arena_allocator := vmem.arena_allocator(&arena)

	paths_dyn := walk_dir(dir_path, arena_allocator)
	defer delete_dynamic_array(paths_dyn)

	paths := paths_dyn[:]

	testing.expect(t, len(paths) > 0, "Didnt find anything")

}
