package ui

import clay "../../vendor/clay-odin"
import comp "./components"
import "core:fmt"

root :: proc() -> clay.ClayArray(clay.RenderCommand) {
	clay.BeginLayout()

	comp.top_bar()

	return clay.EndLayout(1)
}
