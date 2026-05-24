package main

import clay "../vendor/clay-odin"
import "core:fmt"
import "ui"

import rl "vendor:raylib"

main :: proc() {

	ui.setup_ui()

	rl.InitWindow(ui.width, ui.height, "foo")
	rl.SetTargetFPS(60)

	for !rl.WindowShouldClose() {
		rl.BeginDrawing()
		defer rl.EndDrawing()
		rl.ClearBackground(rl.RAYWHITE)

		dt := rl.GetFrameTime()

		render_commands := ui.root(dt)
		ui.clay_raylib_render(&render_commands)

	}
}
