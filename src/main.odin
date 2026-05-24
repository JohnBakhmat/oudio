package main

import clay "../vendor/clay-odin"
import "core:fmt"
import "ui"

main :: proc() {

	ui.setup_ui()


	render_commands := ui.root()

	for i in 0 ..< i32(render_commands.length) {
		render_command := clay.RenderCommandArray_Get(&render_commands, i)

		fmt.printfln("Command %#v", render_command)
	}
}
