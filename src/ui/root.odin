package ui

import clay "../../vendor/clay-odin"
import comp "./components"

root :: proc(dt: f32) -> clay.ClayArray(clay.RenderCommand) {

	clay.BeginLayout()

	// FIXME: enable scrolling
	// clay.UpdateScrollContainers(true, 0, dt)

	if clay.UI(clay.ID("root"))(
	clay.ElementDeclaration {
		layout = {
			sizing = {height = clay.SizingGrow(), width = clay.SizingGrow()},
			layoutDirection = .TopToBottom,
		},
	},
	) {

		comp.top_bar()

		if clay.UI(clay.ID("main"))(
		clay.ElementDeclaration {
			layout = {
				sizing = {
					height = clay.SizingGrow(),
					width = clay.SizingGrow(),
				},
			},
		},
		) {

			comp.library_aside()
		}

	}

	return clay.EndLayout(dt)
}
