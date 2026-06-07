package components

import clay "../../../vendor/clay-odin"
import c "../config"


library_body :: proc() {

	if clay.UI(clay.ID("library-body"))(
	clay.ElementDeclaration {
		layout = {
			sizing = {width = clay.SizingGrow(), height = clay.SizingGrow()},
			layoutDirection = .TopToBottom,
		},
		backgroundColor = c.COLOR_BACKGROUND,
		border = {
			width = {betweenChildren = 1},
			color = c.COLOR_BACKGROUND_LIGHTER,
		},
		clip = {vertical = true, childOffset = clay.GetScrollOffset()},
	},
	) {


		library_row({0, "In Rainbows", "Radiohead", 2007, true})
		library_row({1, "Kid A", "Radiohead", 2000, false})
		library_row({2, "Kid A", "Radiohead", 2000, false})
		library_row({3, "BODY RUSH", "Karma Fields", 2019, false})
		library_row({4, "Imaginal Disk", "Magdalena Bay", 2024, false})

	}


}
