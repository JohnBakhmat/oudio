package ui

import clay "../../vendor/clay-odin"
import "core:fmt"

foo :: proc() -> clay.ClayArray(clay.RenderCommand) {
	clay.BeginLayout()

	if clay.UI()({}) {
		clay.Text("Hello", clay.TextElementConfig{textColor = COLOR_FOREGROUND, fontSize = 16})
	}

	return clay.EndLayout(1)
}
