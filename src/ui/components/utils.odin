package components
import clay "../../../vendor/clay-odin"

grow_horizontal :: proc() {
	if clay.UI()(
	clay.ElementDeclaration{layout = {sizing = {width = clay.SizingGrow()}}},
	) {  }
}


grow_vertical :: proc() {
	if clay.UI()(
	clay.ElementDeclaration{layout = {sizing = {height = clay.SizingGrow()}}},
	) {  }
}
