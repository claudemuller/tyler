package adventure

import tfd "../vendor/tinyfiledialogs"
import "core:fmt"
import "core:os"
import "core:strconv"
import rl "vendor:raylib"

PANEL_PADDING :: 8.0
BTN_HEIGHT :: 30.0

Panel :: struct {
	rect:               rl.Rectangle,
	padding:            f32,
	items:              [dynamic]Item,
	label:              string,
	content_start_top:  f32,
	content_start_left: f32,
	internal_width:     f32,
}

ItemType :: enum {
	Button,
	Label,
	Slider,
}

Item :: struct {
	rect:     rl.Rectangle,
	label:    string,
	type:     ItemType,
	height:   f32,
	value:    ^f32,
	callback: proc(),
}

Tile :: struct {
	src_pos: rl.Vector2,
	src_rec: rl.Rectangle,
	dst_rec: rl.Rectangle,
	size:    struct {
		width:  f32,
		height: f32,
	},
}

main_panel: Panel
texture: rl.Texture2D
tiles: [dynamic]Tile
scale: f32 = 1.0
panel_tiles_in_row: i32 = 10
selected_tile: Tile
hovering_tile: rl.Rectangle

ui_setup :: proc() {
	rl.GuiLoadStyle("assets/style_dark.rgs")

	x: f32 = 20.0
	y: f32 = 20.0
	w: f32 = 300.0
	main_panel = Panel {
		label              = "Spritesheet",
		rect               = {x, y, w, 100},
		padding            = PANEL_PADDING,
		content_start_left = x + PANEL_PADDING,
		content_start_top  = y + PANEL_PADDING + 10,
		internal_width     = w - PANEL_PADDING * 2,
	}

	// Debug
	scale = 2
	load_tiles("assets/tilesheets/colored_packed.png", 16, 16, &texture)
	// _Debug

	append(&main_panel.items, Item{label = "Scale", type = .Slider, value = &scale})
	append(&main_panel.items, Item {
		label = "Load spritesheet",
		type = .Button,
		height = BTN_HEIGHT,
		callback = proc() {
			ret := tfd.inputBox("Tile width and height", "in pixels", "")
			if ret == "" {
				return
			}
			tile_width := f32(strconv.atof(string(ret)))
			tile_height := tile_width

			fname := tfd.openFileDialog(
				"Open File",
				nil,
				2,
				raw_data([]cstring{"*.png", "*.txt"}),
				nil,
				0,
			)
			if fname != "" {
				load_tiles(fname, tile_width, tile_height, &texture)
			}
		},
	})
}

load_tiles :: proc(fname: cstring, tile_width, tile_height: f32, tex: ^rl.Texture2D) {
	texture = rl.LoadTexture(fname)

	num_tiles_in_row := texture.width / i32(tile_width)
	num_tiles_in_col := texture.height / i32(tile_height)
	num_tile_cols := num_tiles_in_row * num_tiles_in_col / panel_tiles_in_row

	main_panel.internal_width = tile_width * scale * f32(panel_tiles_in_row)
	main_panel.rect.width = main_panel.internal_width + main_panel.padding * 2
	// TODO:(lukefilewalker) dynamically add items already in panel
	main_panel.rect.height = f32(num_tile_cols) * tile_height * scale + 100

	tiles = make([dynamic]Tile, num_tiles_in_row * num_tiles_in_col)

	xstart := main_panel.content_start_left
	// TODO:(lukefilewalker) magic number
	ystart := y_pos(main_panel.content_start_top, len(main_panel.items) + 3)

	i: i32
	for y in 0 ..< num_tiles_in_col {
		for x in 0 ..< num_tiles_in_row {
			// TODO:(lukefilewalker)  huh?
			// i := x * num_tiles_in_row + y
			dst_x := i32(i) % panel_tiles_in_row
			dst_y := i32(i) / panel_tiles_in_row

			tiles[y * num_tiles_in_row + x] = Tile {
				src_pos = {f32(x), f32(y)},
				src_rec = {
					x = f32(x) * tile_width,
					y = f32(y) * tile_height,
					width = tile_width,
					height = tile_height,
				},
				dst_rec = {
					x = f32(dst_x) * tile_width * scale + xstart,
					y = f32(dst_y) * tile_height * scale + ystart,
					width = tile_width * scale,
					height = tile_height * scale,
				},
				size = {tile_width, tile_height},
			}
			i += 1
		}
	}
}

ui_update :: proc() {
	// TODO:(lukefilewalker) don't have to loop each tile - convert MouseButton-pos to grid and check tile there
	for t, i in tiles {
		if rl.CheckCollisionPointRec(rl.GetMousePosition(), t.dst_rec) {
			hovering_tile = t.dst_rec

			if .LEFT in input.mouse.btns {
				selected_tile = t
			}
		}
	}
}

ui_draw :: proc() {
	rl.GuiPanel(main_panel.rect, fmt.ctprint(main_panel.label))

	for item, i in main_panel.items {
		switch item.type {
		case .Label:
			rl.GuiLabel(
				{
					main_panel.content_start_left,
					y_pos(main_panel.content_start_top, i),
					main_panel.internal_width,
					main_panel.content_start_top + main_panel.padding * 2.5,
				},
				item.value == nil ? fmt.ctprint(item.label) : fmt.ctprintf("%s %f", item.label, item.value^),
			)

		case .Button:
			if rl.GuiButton(
				{
					main_panel.content_start_left,
					// TODO:(lukefilewalker) magic num
					y_pos(main_panel.content_start_top, i) + 20,
					main_panel.internal_width,
					item.height,
				},
				fmt.ctprint(item.label),
			) {
				item.callback()
			}

		case .Slider:
			rl.GuiLabel(
				{
					main_panel.content_start_left,
					y_pos(main_panel.content_start_top, i),
					main_panel.internal_width,
					main_panel.content_start_top + main_panel.padding * 2.5,
				},
				item.value == nil ? fmt.ctprint(item.label) : fmt.ctprintf("%s %f", item.label, item.value^),
			)
			rl.GuiSliderBar(
				{
					// TODO:(lukefilewalker) magic num
					main_panel.content_start_left + 120,
					y_pos(main_panel.content_start_top, i) + 29,
					main_panel.internal_width - 150,
					item.height,
				},
				"min",
				"max",
				&scale,
				0,
				10,
			)
		}
	}

	if texture.id != 0 {
		// Draw tiles
		for t, i in tiles {
			rl.DrawTexturePro(texture, t.src_rec, t.dst_rec, {0, 0}, 0, rl.WHITE)

			rl.DrawRectangleLines(
				i32(t.dst_rec.x),
				i32(t.dst_rec.y),
				i32(t.dst_rec.width),
				i32(t.dst_rec.height),
				rl.LIGHTGRAY,
			)
		}

		// Draw selected tile
		dst := rl.Rectangle {
			input.mouse.px_pos.x,
			input.mouse.px_pos.y,
			selected_tile.dst_rec.width,
			selected_tile.dst_rec.height,
		}
		rl.DrawTexturePro(texture, selected_tile.src_rec, dst, {0, 0}, 0, rl.WHITE)

		// Draw hovering tile
		rl.DrawRectangleLinesEx(hovering_tile, 3, rl.RED)
	}

	// ret := tfd.saveFileDialog(
	// 	"Save File Dialog",
	// 	nil,
	// 	2,
	// 	raw_data([]cstring{"*.png", "*.txt"}),
	// 	nil,
	// )
	// fmt.printfln("You saved to this file: %s", ret)
}

y_pos :: proc(y_from_top: f32, n: int) -> f32 {
	return y_from_top + (BTN_HEIGHT * f32(n))
}
