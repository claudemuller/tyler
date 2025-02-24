package adventure

import tfd "../vendor/tinyfiledialogs"
import "core:encoding/json"
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

Map :: struct {
	scale:     f32,
	tilesheet: cstring,
	tiles:     map[u16]Tile,
}

Selection :: struct {
	selected: bool,
	tile:     Tile,
}

main_panel: Panel
texture: rl.Texture2D
tilemap_tex: rl.RenderTexture2D
tiles: [dynamic]Tile
scale: f32 = 1.0
panel_tiles_in_row: i32 = 10
selection: Selection
hovering_tile: rl.Rectangle
scroll_offset: f32
tilesheet: cstring

ui_setup :: proc() {
	rl.GuiLoadStyle("res/style_dark.rgs")

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
	// load_tiles("assets/tilesheets/colored_packed.png", 16, 16, &texture)
	// load_tiles("../that-guy/res/assets/tilemap.png", 16, 16, &texture)
	// _Debug

	append(&main_panel.items, Item{label = "Scale", type = .Slider, value = &scale})
	append(
		&main_panel.items,
		Item {
			label = "Load spritesheet",
			type = .Button,
			height = BTN_HEIGHT,
			callback = proc() {
				ret := tfd.inputBox("Tile width and height", "in pixels", "")
				if ret == "" {
					return
				}
				tile_width := f32(strconv.atof(string(ret)))
				// TODO:(lukefilewalker) this isn't the best place :(
				block_size = i32(tile_width)
				tile_height := tile_width

				tilesheet = tfd.openFileDialog(
					"Open file",
					nil,
					2,
					raw_data([]cstring{"*.png", "*.txt"}),
					nil,
					0,
				)
				if tilesheet != "" {
					load_tiles(tilesheet, tile_width, tile_height, &texture)
				}
			},
		},
	)

	append(&main_panel.items, Item {
		label = "Save tilemap",
		type = .Button,
		height = BTN_HEIGHT,
		callback = proc() {
			fname := tfd.saveFileDialog(
				"Save as",
				nil,
				2,
				raw_data([]cstring{"*.json", "*.txt"}),
				nil,
			)
			if fname != "" {
				if ok := save_tilemap(fname); !ok {
					rl.TraceLog(.ERROR, "Error writing tilemap to disk")
				}
			}
		},
	})
}

save_tilemap :: proc(fname: cstring) -> bool {
	map_data := Map {
		scale     = scale,
		tilesheet = tilesheet,
		tiles     = blocks,
	}
	data, err := json.marshal(map_data, allocator = context.temp_allocator)
	if err != nil {
		rl.TraceLog(.ERROR, fmt.ctprintf("Error marshalling tilemap to json: %v", err))
		return false
	}
	defer free_all(context.temp_allocator)

	return os.write_entire_file(string(fname), data)
}

load_tiles :: proc(fname: cstring, tile_width, tile_height: f32, tex: ^rl.Texture2D) {
	texture = rl.LoadTexture(fname)

	num_tiles_in_row := texture.width / i32(tile_width)
	num_tiles_in_col := texture.height / i32(tile_height)
	num_tile_cols := num_tiles_in_row * num_tiles_in_col / panel_tiles_in_row + 1

	main_panel.internal_width = tile_width * scale * f32(panel_tiles_in_row)
	main_panel.rect.width = main_panel.internal_width + main_panel.padding * 2
	// TODO:(lukefilewalker) dynamically add height of items already in panel
	// TODO:(lukefilewalker) magic number
	main_panel.rect.height =
		f32(num_tile_cols) * tile_height * scale + f32(len(main_panel.items)) + 140

	tiles = make([dynamic]Tile, num_tiles_in_row * num_tiles_in_col)

	xstart := main_panel.content_start_left
	// TODO:(lukefilewalker) magic number
	ystart := y_pos(main_panel.content_start_top, len(main_panel.items) + 4)

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

	// Reshape spritesheet to something that will fit in the UI
	width := f32(panel_tiles_in_row) * tile_width * scale
	height := f32(num_tiles_in_row * num_tiles_in_col) / tile_width * tile_width * scale
	tilemap_tex = rl.LoadRenderTexture(i32(width), i32(height))

	rl.BeginTextureMode(tilemap_tex)
	rl.ClearBackground(rl.BLANK)

	// TODO:(lukefilewalker) do I want to do/can this in the same loop as above?
	for t, i in tiles {
		x := f32(i32(i) % panel_tiles_in_row) * t.size.width * scale
		y := f32(i32(i) / panel_tiles_in_row) * t.size.height * scale
		dst := rl.Rectangle{x, f32(y), t.size.width * scale, t.size.height * scale}
		rl.DrawTexturePro(texture, t.src_rec, dst, {0, 0}, 0, rl.WHITE)
		fmt.printfln("%v %v", x, y)
	}

	rl.EndTextureMode()
}

// TODO:(lukefilewalker) debug
tiles_panel: rl.Rectangle

ui_update :: proc() -> bool {
	// Exit if input is not for the UI panel
	if !rl.CheckCollisionPointRec(input.mouse.px_pos, main_panel.rect) {
		return false
	}

	// Scroll tiles
	if input.mouse.wheel_delta != 0 {
		tile_width := tiles[0].dst_rec.width
		tile_height := tiles[0].dst_rec.height
		num_tiles_in_row := texture.width / i32(tile_width)
		num_tiles_in_col := texture.height / i32(tile_height)
		num_tile_cols := num_tiles_in_row * num_tiles_in_col / panel_tiles_in_row

		tiles_panel = rl.Rectangle {
			x      = tiles[0].dst_rec.x,
			y      = tiles[0].dst_rec.y,
			width  = tiles[0].dst_rec.width * f32(panel_tiles_in_row),
			height = f32(num_tile_cols) * tile_height * scale + 100,
		}

		if rl.CheckCollisionPointRec(input.mouse.px_pos, tiles_panel) {
			scroll_offset += input.mouse.wheel_delta
		}
	}

	// TODO:(lukefilewalker) don't have to loop each tile - convert MouseButton-pos to grid and check tile there
	for t, i in tiles {
		if rl.CheckCollisionPointRec(input.mouse.px_pos, t.dst_rec) {
			hovering_tile = t.dst_rec

			if .LEFT in input.mouse.btns {
				selection = {
					tile     = t,
					selected = true,
				}
			}
		}
	}

	return true
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

	if tilemap_tex.texture.id != 0 {
		src := rl.Rectangle{0, 0, f32(tilemap_tex.texture.width), f32(tilemap_tex.texture.height)}
		xstart := main_panel.content_start_left
		// TODO:(lukefilewalker) magic number
		ystart := y_pos(main_panel.content_start_top, len(main_panel.items) + 4)
		dst := rl.Rectangle {
			xstart,
			ystart,
			f32(tilemap_tex.texture.width),
			f32(tilemap_tex.texture.height),
		}
		fmt.printfln("%v %v", src, dst)
		rl.DrawTexturePro(tilemap_tex.texture, src, dst, {0, 0}, 0, rl.WHITE)
		rl.DrawRectangleLinesEx(dst, 1, rl.GREEN)
	}

	if texture.id != 0 {
		// Draw tiles
		for t, i in tiles {
			dst := t.dst_rec
			dst.y += scroll_offset * 10
			// rl.DrawTexturePro(texture, t.src_rec, dst, {0, 0}, 0, rl.WHITE)

			rl.DrawRectangleLinesEx(t.dst_rec, 1, rl.LIGHTGRAY)
		}

		// Draw selected tile
		dst := rl.Rectangle {
			input.mouse.px_pos.x,
			input.mouse.px_pos.y,
			selection.tile.dst_rec.width,
			selection.tile.dst_rec.height,
		}
		rl.DrawTexturePro(texture, selection.tile.src_rec, dst, {0, 0}, 0, rl.WHITE)

		// Draw hovering tile
		rl.DrawRectangleLinesEx(hovering_tile, 3, rl.RED)
	}

	ui_draw_debug()
}

ui_draw_debug :: proc() {
	rl.DrawText(fmt.ctprintf("num_blocks: %d", len(blocks)), 400, 10, 20, rl.LIGHTGRAY)

	rl.DrawRectangleLines(
		i32(tiles_panel.x),
		i32(tiles_panel.y),
		i32(tiles_panel.width),
		i32(tiles_panel.height),
		rl.RED,
	)
}

y_pos :: proc(y_from_top: f32, n: int) -> f32 {
	return y_from_top + (BTN_HEIGHT * f32(n))
}
