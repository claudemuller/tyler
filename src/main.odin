package tyler

import "core:fmt"
import "core:mem"
import "core:os"
import rl "vendor:raylib"

WINDOW_WIDTH :: 1920
WINDOW_HEIGHT :: 1080
WORLD_WIDTH :: 1920 * 2
WORLD_HEIGHT :: 1080 * 2

camera: rl.Camera2D
input: Input
blocks: map[u16]Tile
// TODO:(lukefilewalker) handle non-square tiles
block_size: i32

main :: proc() {
	track: mem.Tracking_Allocator
	mem.tracking_allocator_init(&track, context.allocator)
	context.allocator = mem.tracking_allocator(&track)

	defer {
		for _, entry in track.allocation_map {
			fmt.eprintf("%v leaked %v bytes\n", entry.location, entry.size)
		}
		for entry in track.bad_free_array {
			fmt.eprintf("%v bad free\n", entry.location)
		}
		mem.tracking_allocator_destroy(&track)
	}

	rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Tyler")
	defer rl.CloseWindow()
	rl.SetTargetFPS(60)
	rl.SetExitKey(.ESCAPE)

	setup()

	for !rl.WindowShouldClose() {
		process_input()
		update()
		render()
	}
}

setup :: proc() {
	camera = {
		target = {WORLD_WIDTH / 2, WORLD_HEIGHT / 2},
		offset = {WINDOW_WIDTH / 2, WINDOW_HEIGHT / 2},
		zoom   = scale,
	}

	ui_setup()
}

update :: proc() {
	// camera.offset += input.kb.axis

	if ui_update() do return

	// Remove a tile
	if .RIGHT in input.mouse.btns {
		world_mouse_pos := rl.GetScreenToWorld2D(input.mouse.px_pos, camera)
		x := i32(world_mouse_pos.x) / block_size
		y := i32(world_mouse_pos.y) / block_size
		hash := gen_hash(x, y)

		delete_key(&blocks, hash)
	}

	// Place a tile
	if selection.selected && .LEFT in input.mouse.btns {
		world_mouse_pos := rl.GetScreenToWorld2D(input.mouse.px_pos, camera)
		tile := selection.tile

		x := i32(world_mouse_pos.x / tile.dst_rec.width)
		y := i32(world_mouse_pos.y / tile.dst_rec.height)
		hash := gen_hash(x, y)

		tile.dst_rec.x = f32(x) * tile.dst_rec.width
		tile.dst_rec.y = f32(y) * tile.dst_rec.height

		blocks[hash] = tile
	}

	cur_mouse_pos := rl.Vector2 {
		(input.mouse.px_pos.x / WORLD_WIDTH) * 2 - 1,
		(input.mouse.px_pos.y / WORLD_HEIGHT) * 2 - 1,
	}
	if .MIDDLE in input.mouse.btns {
		if !input.mouse.is_panning {
			input.mouse.prev_px_pos = cur_mouse_pos
			input.mouse.is_panning = true
		}

		delta := cur_mouse_pos - input.mouse.prev_px_pos
		camera.offset += delta * MOUSE_PAN_SPEED
		// TODO:(lukefilewalker) clamp properly here
		camera.offset = clamp_camera(camera.offset)

		input.mouse.prev_px_pos = cur_mouse_pos
	} else {
		input.mouse.is_panning = false
	}
}

render :: proc() {
	rl.BeginDrawing()
	rl.ClearBackground(rl.BLACK)

	rl.BeginMode2D(camera)

	// Draw tiles
	if tileset.texture != nil {
		src: rl.Rectangle
		for _, tile in blocks {
			src = tile.dst_rec
			src.x = tile.pos.x * tile.dst_rec.width
			src.y = tile.pos.y * tile.dst_rec.height
			rl.DrawTexturePro(tileset.texture^, src, tile.dst_rec, {0, 0}, 0, rl.WHITE)
		}
	}

	// Draw grid
	if block_size > 0 {
		for y in i32(0) ..< WORLD_HEIGHT / block_size {
			for x in i32(0) ..< WORLD_WIDTH / block_size {
				rl.DrawRectangleLines(
					x * block_size,
					y * block_size,
					block_size,
					block_size,
					{30, 30, 30, 255},
				)
			}
		}
	}

	rl.EndMode2D()

	ui_draw()

	rl.EndDrawing()
}

clamp_camera :: proc(vec: rl.Vector2) -> rl.Vector2 {
	half_window_width := WINDOW_WIDTH / 2.0 / camera.zoom
	half_window_height := WINDOW_HEIGHT / 2.0 / camera.zoom
	minX: f32 = half_window_width
	minY: f32 = half_window_height
	maxX: f32 = WORLD_WIDTH - half_window_width
	maxY: f32 = WORLD_HEIGHT - half_window_height

	res_vec := vec

	if (res_vec.x < minX) do res_vec.x = minX
	if (res_vec.y < minY) do res_vec.y = minY
	if (res_vec.x > maxX) do res_vec.x = maxX
	if (res_vec.y > maxY) do res_vec.y = maxY

	return res_vec
}

gen_hash :: proc(x, y: i32) -> u16 {
	return u16(((x * 73856093) + (y * 19349663)) % 65536)
}
