package ui

import clay "../../vendor/clay-odin"
import "core:fmt"

error_handler :: proc "c" (errorData: clay.ErrorData) {
	// Do something with the error data.
}

width: f32 = 1366
height: f32 = 768


// Example measure text function
measure_text :: proc "c" (text: clay.StringSlice, config: ^clay.TextElementConfig, userData: rawptr) -> clay.Dimensions {
	// clay.TextElementConfig contains members such as fontId, fontSize, letterSpacing, etc..
	// Note: clay.String->chars is not guaranteed to be null terminated
	return {width = f32(text.length * i32(config.fontSize)), height = f32(config.fontSize)}
}


setup_ui :: proc() {
	fmt.println("Hello World")

	min_memory_size := clay.MinMemorySize()
	memory := make([^]u8, min_memory_size)
	arena: clay.Arena = clay.CreateArenaWithCapacityAndMemory(uint(min_memory_size), memory)

	clay.Initialize(arena, {width, height}, {handler = error_handler})

	clay.SetMeasureTextFunction(measure_text, nil)

	render_commands := foo()

	for i in 0 ..< i32(render_commands.length) {
		render_command := clay.RenderCommandArray_Get(&render_commands, i)

		fmt.printfln("Command %#v", render_command)
	}
}
