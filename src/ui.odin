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
}

Map :: struct {
	scale:     f32,
	tilesheet: cstring,
	tiles:     map[u16]Tile,
}

Tileset :: struct {
	texture:         ^rl.Texture2D,
	render_texture:  rl.RenderTexture2D,
	// TODO:(lukefilewalker) or something?
	backing_texture: rl.Texture2D,
}

Selection :: struct {
	selected: bool,
	tile:     Tile,
}

scale: f32 = 1.0
main_panel: Panel

imported_tileset: Tileset
tileset: Tileset

// original_tileset_ss: rl.Texture2D
// tileset_ss: rl.RenderTexture2D

tiles_data: [dynamic]Tile
panel_num_tiles_in_row: i32 = 10
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
					load_tiles(tilesheet, tile_width, tile_height, &imported_tileset)
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

// TODO:(lukefilewalker) shadowing imported_tileset :(
load_tiles :: proc(
	fname: cstring,
	src_tile_width, src_tile_height: f32,
	imported_tileset: ^Tileset,
) {
	imported_tileset.texture = rl.LoadTexture(fname)
	// TODO:(lukefilewalker) set texture to &backing_texture.texture
	tex_num_tiles_in_row := imported_tileset.texture.width / i32(src_tile_width)
	tex_num_tiles_in_col := imported_tileset.texture.height / i32(src_tile_height)

	total_num_tiles := tex_num_tiles_in_row * tex_num_tiles_in_col

	dst_tile_width := src_tile_width * scale
	dst_tile_height := src_tile_height * scale

	panel_num_tiles_in_col := total_num_tiles / panel_num_tiles_in_row + 1

	// TODO:(lukefilewalker) dynamically add height of items already in panel
	// TODO:(lukefilewalker) magic number
	main_panel.rect.height =
		f32(panel_num_tiles_in_col) * dst_tile_height + f32(len(main_panel.items)) + 140
	main_panel.internal_width = dst_tile_width * f32(panel_num_tiles_in_row)
	main_panel.rect.width = main_panel.internal_width + main_panel.padding * 2

	tiles_data = make([dynamic]Tile, total_num_tiles)

	panel_xstart := main_panel.content_start_left
	// TODO:(lukefilewalker) magic number
	panel_ystart := y_pos(main_panel.content_start_top, len(main_panel.items) + 4)

	// Reshape tile array into something that will fit in the UI
	i: i32
	for y in 0 ..< tex_num_tiles_in_col {
		for x in 0 ..< tex_num_tiles_in_row {
			// TODO:(lukefilewalker) huh? Using i when I have x,y - but these x and y are for the original
			// texture's coords?
			src_x := i32(i) % tex_num_tiles_in_row
			src_y := i32(i) / tex_num_tiles_in_row
			dst_x := i32(i) % panel_num_tiles_in_row
			dst_y := i32(i) / panel_num_tiles_in_row

			tiles_data[y * tex_num_tiles_in_row + x] = Tile {
				src_pos = {f32(x), f32(y)},
				src_rec = {
					x = f32(x) * src_tile_width,
					y = f32(y) * src_tile_height,
					width = src_tile_width,
					height = src_tile_height,
				},
				dst_rec = {
					x = f32(dst_x) * dst_tile_width + panel_xstart,
					y = f32(dst_y) * dst_tile_height + panel_ystart,
					width = dst_tile_width,
					height = dst_tile_height,
				},
			}
			fmt.printfln("%v", tiles_data[i])
			i += 1
		}
	}

	// Redraw the new tile layout onto target texture
	tilemap_width := f32(panel_num_tiles_in_row) * src_tile_width * scale
	// TODO:(lukefilewalker) don't these cancel? the * and /
	tilemap_height := f32(total_num_tiles) / src_tile_width * src_tile_width * scale
	tileset.ren_texture = rl.LoadRenderTexture(i32(tilemap_width), i32(tilemap_height))
	// TODO:(lukefilewalker) free the free the original tilemap tex?
	// TODO:(lukefilewalker) set texture to &ren_texture.texture

	rl.BeginTextureMode(tileset.ren_texture)
	rl.ClearBackground(rl.BLANK)

	// TODO:(lukefilewalker) do I want to do/can this in the same loop as above?
	for t, i in tiles_data {
		t_height := t.dst_rec.height * scale
		t_width := t.dst_rec.width * scale
		x := f32(i32(i) % panel_num_tiles_in_row) * t_width
		y := f32(i32(i) / panel_num_tiles_in_row) * t_height
		dst := rl.Rectangle{x, y, t_width, src_tile_height}

		rl.DrawTexturePro(imported_tileset.texture, t.src_rec, dst, {0, 0}, 0, rl.WHITE)
		// fmt.printfln("%v %v", x, y)
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
		tile_width := tiles_data[0].dst_rec.width
		tile_height := tiles_data[0].dst_rec.height
		num_tiles_in_row := imported_tileset.texture.width / i32(tile_width)
		num_tiles_in_col := imported_tileset.texture.height / i32(tile_height)
		num_tile_cols := num_tiles_in_row * num_tiles_in_col / panel_num_tiles_in_row

		tiles_panel = rl.Rectangle {
			x      = tiles_data[0].dst_rec.x,
			y      = tiles_data[0].dst_rec.y,
			width  = tiles_data[0].dst_rec.width * f32(panel_num_tiles_in_row),
			height = f32(num_tile_cols) * tile_height * scale + 100,
		}

		if rl.CheckCollisionPointRec(input.mouse.px_pos, tiles_panel) {
			scroll_offset += input.mouse.wheel_delta
		}
	}

	// TODO:(lukefilewalker) don't have to loop each tile - convert MouseButton-pos to grid and check tile there
	for t, i in tiles_data {
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
		xstart := main_panel.content_start_left + 700
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

	// TODO:(lukefilewalker) add a "loaded" or something or nil check on Tileset struct/pointer
	if imported_tileset.texture.id != 0 {
		// Draw tiles
		for t, i in tiles_data {
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
		rl.DrawTexturePro(
			imported_tileset.texture,
			selection.tile.src_rec,
			dst,
			{0, 0},
			0,
			rl.WHITE,
		)

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
