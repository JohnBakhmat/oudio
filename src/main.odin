package main

import clay "../vendor/clay-odin"
import "core:fmt"
import "ui"

import pb "./playback"
import rl "vendor:raylib"

main :: proc() {
	pb.basic_playback()

	// rl.InitWindow(ui.width, ui.height, "foo")
	// rl.SetTargetFPS(60)
	//
	// ui.setup_ui()
	//
	// for !rl.WindowShouldClose() {
	// 	rl.BeginDrawing()
	// 	defer rl.EndDrawing()
	// 	rl.ClearBackground(rl.RAYWHITE)
	//
	// 	dt := rl.GetFrameTime()
	//
	// 	render_commands := ui.root(dt)
	// 	ui.clay_raylib_render(&render_commands)
	//
	// }
}
