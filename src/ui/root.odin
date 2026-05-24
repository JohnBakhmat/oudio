package ui

import clay "../../vendor/clay-odin"
import comp "./components"
import "core:fmt"
import rl "vendor:raylib"

root :: proc(dt: f32) -> clay.ClayArray(clay.RenderCommand) {

	clay.BeginLayout()
	comp.top_bar()


	return clay.EndLayout(dt)
}
