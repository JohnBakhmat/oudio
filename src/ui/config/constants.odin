package config

import clay "../../../vendor/clay-odin"


// #CACED4
COLOR_FOREGROUND :: clay.Color{202, 206, 212, 255}

// #0A0B0D
COLOR_BACKGROUND :: clay.Color{10, 11, 13, 255}

// #606369
COLOR_FOREGROUND_FADING :: clay.Color{96, 99, 105, 255}

// #57CB60
COLOR_ACCENT :: clay.Color{87, 203, 96, 255}


FONT_SIZE_BASE :: 12
FONT_SIZE_LG :: FONT_SIZE_BASE + 4
FONT_SIZE_SM :: FONT_SIZE_BASE - 4

TEXT_BASE :: clay.TextElementConfig {
	fontSize  = FONT_SIZE_BASE,
	textColor = COLOR_FOREGROUND,
}


FONT_ID_BASE :: 69
