package ui

import clay "../../vendor/clay-odin"
import c "./config"
import "core:fmt"
import "core:path/filepath"
import "core:strings"
import rl "vendor:raylib"

error_handler :: proc "c" (errorData: clay.ErrorData) {
	// Do something with the error data.
}

width: i32 = 1890
height: i32 = 901


// // Example measure text function
// measure_text :: proc "c" (
// 	text: clay.StringSlice,
// 	config: ^clay.TextElementConfig,
// 	userData: rawptr,
// ) -> clay.Dimensions {
// 	// clay.TextElementConfig contains members such as fontId, fontSize, letterSpacing, etc..
// 	// Note: clay.String->chars is not guaranteed to be null terminated
// 	return {
// 		width = f32(text.length * i32(config.fontSize)),
// 		height = f32(config.fontSize),
// 	}
// }
//


setup_ui :: proc() {
	fmt.println("Hello World")

	min_memory_size := clay.MinMemorySize()
	memory := make([^]u8, min_memory_size)
	arena: clay.Arena = clay.CreateArenaWithCapacityAndMemory(
		uint(min_memory_size),
		memory,
	)

	clay.Initialize(
		arena,
		{cast(f32)width, cast(f32)height},
		{handler = error_handler},
	)

	clay.SetMeasureTextFunction(measure_text, nil)


	load_font(c.FONT_ID_BASE, 12, "assets/JetBrainsMonoNerdFont-Regular.ttf")
	load_font(
		c.FONT_ID_BASE_BOLD,
		12,
		"assets/JetBrainsMonoNerdFontMono-Bold.ttf",
	)

}
