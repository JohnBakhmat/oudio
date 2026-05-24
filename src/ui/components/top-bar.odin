package components

import clay "../../../vendor/clay-odin"
import c "../config"

top_bar :: proc() {


	if clay.UI(clay.ID("top-bar"))(
	clay.ElementDeclaration {
		layout = {
			sizing = {
				width = clay.SizingGrow(),
				height = clay.SizingFit({max = 40.0}),
			},
			padding = {left = 12, top = 12, bottom = 12},
		},
		backgroundColor = c.COLOR_BACKGROUND,
	},
	) {

		if clay.UI(clay.ID("logo-container"))({layout = {childGap = 6}}) {

			// clay.Text(
			// 	"oudio",
			// 	clay.TextElementConfig {
			// 		fontSize = 12,
			// 		textColor = c.COLOR_ACCENT,
			// 	},
			// )
		}
	}


}
