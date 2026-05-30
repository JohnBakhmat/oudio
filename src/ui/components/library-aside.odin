package components

import clay "../../../vendor/clay-odin"
import c "../config"

library_aside :: proc() {

	if clay.UI(clay.ID("library-aside"))(
	clay.ElementDeclaration {
		layout = {
			sizing = {
				height = clay.SizingGrow(),
				width = clay.SizingFixed(256.0),
			},
		},
		backgroundColor = c.COLOR_BACKGROUND,
	},
	) {

		if clay.UI(clay.ID("library-aside__header"))(
		clay.ElementDeclaration {
			layout = {
				sizing = {
					width = clay.SizingGrow(),
					height = clay.SizingFit(),
				},
				padding = {left = 16, right = 16, top = 8, bottom = 8},
				layoutDirection = .LeftToRight,
			},
		},
		) {
			clay.Text(
				"LIBRARY",
				clay.TextElementConfig {
					fontSize = c.FONT_SIZE_SM,
					textColor = c.COLOR_FOREGROUND_FADING,
					fontId = c.FONT_ID_BASE_BOLD,
				},
			)

			if clay.UI()(
			clay.ElementDeclaration {
				layout = {sizing = {width = clay.SizingGrow()}},
			},
			) {  }


			clay.Text(
				"albums",
				clay.TextElementConfig {
					fontSize = c.FONT_SIZE_SM,
					textColor = c.COLOR_FOREGROUND_FADING,
					fontId = c.FONT_ID_BASE_BOLD,
				},
			)


		}

	}
}
