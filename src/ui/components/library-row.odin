package components

import clay "../../../vendor/clay-odin"
import c "../config"
import "core:fmt"
import "core:hash"
import "core:strings"


RowProps :: struct {
	idx:       u32,
	title:     string,
	artist:    string,
	year:      int,
	is_active: bool,
}

library_row :: proc(props: RowProps) {

	if clay.UI(clay.ID("library_row", props.idx))(
	clay.ElementDeclaration {
		layout = {
			sizing = {width = clay.SizingGrow(), height = clay.SizingFit()},
			padding = {top = 8, left = 12, right = 12, bottom = 8},
			layoutDirection = .LeftToRight,
			childGap = 12,
			childAlignment = {y = .Center},
		},
		backgroundColor = clay.Hovered() ? c.COLOR_BACKGROUND_LIGHTER : c.COLOR_BACKGROUND,
	},
	) {


		if clay.UI(clay.ID("cover"))(
		clay.ElementDeclaration {
			layout = {
				sizing = {
					height = clay.SizingFit({min = 40}),
					width = clay.SizingFit({min = 40}),
				},
			},
			backgroundColor = c.COLOR_ACCENT,
			aspectRatio = {aspectRatio = 1},
			cornerRadius = {
				topLeft = 5,
				topRight = 5,
				bottomRight = 5,
				bottomLeft = 5,
			},
		},
		) {


		}


		if clay.UI(clay.ID("info"))(
		clay.ElementDeclaration {
			layout = {
				sizing = {
					width = clay.SizingGrow(),
					height = clay.SizingFit(),
				},
				layoutDirection = .TopToBottom,
			},
		},
		) {

			clay.Text(
				props.title,
				clay.TextElementConfig {
					fontSize = c.FONT_SIZE_BASE,
					fontId = c.FONT_ID_BASE,
					textColor = props.is_active ? c.COLOR_ACCENT : c.COLOR_FOREGROUND,
				},
			)


			bottomText := fmt.aprintf("%s * %d", props.artist, props.year)

			clay.Text(
				bottomText,
				clay.TextElementConfig {
					fontSize = c.FONT_SIZE_SM,
					fontId = c.FONT_ID_BASE,
					textColor = c.COLOR_FOREGROUND_FADING,
				},
			)

		}
	}
}
