package library

import formats "../formats"
import "core:fmt"
import "core:mem"
import "core:mem/virtual"
import vmem "core:mem/virtual"
import "core:os"
import "core:path/filepath"
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

		filePath := strings.clone(info.fullpath, allocator)

		fmt.printfln("Found: %s", filePath)
		append(&paths, filePath)
		fmt.printfln("inner Paths: %$v", paths)
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

	input_path, test_err := filepath.join({#directory, dir_path}, context.temp_allocator)
	testing.expect(t, test_err == nil)

	arena: vmem.Arena
	arena_err := vmem.arena_init_growing(&arena)
	defer vmem.arena_destroy(&arena)

	testing.expect(t, arena_err == nil, "Failed to initialize arena")

	arena_allocator := vmem.arena_allocator(&arena)

	paths_dyn := walk_dir(input_path, arena_allocator)
	defer delete_dynamic_array(paths_dyn)

	paths := paths_dyn[:]

	testing.expect(t, len(paths) > 0, "Didnt find anything")

}
