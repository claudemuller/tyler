package tyler

import tfd "../vendor/tinyfiledialogs"
import "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:strconv"
import "core:strings"
import rl "vendor:raylib"

PANEL_PADDING :: 8.0
PANEL_HEADER :: 25
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
	pos:     rl.Vector2,
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
	backing_texture: rl.Texture2D,
	top_offset:      f32,
}

Selection :: struct {
	selected: bool,
	tile:     Tile,
}

scale: f32 = 1.0
main_panel: Panel
ui_font: rl.Font
tileset_panel: rl.Rectangle

imported_tileset: Tileset
tileset: Tileset

tiles_data: [dynamic]Tile
panel_num_tiles_in_row: i32 = 10
selection: Selection
hovering_tile: rl.Rectangle
scroll_offset: f32
tilesheet: cstring

ui_setup :: proc() {
	rl.GuiLoadStyle("res/style_dark.rgs")

	ui_font = rl.LoadFont("res/HackNerdFont-Regular.ttf")

	x: f32 = 20.0
	y: f32 = 20.0
	w: f32 = 300.0
	main_panel = Panel {
		label              = "Spritesheet",
		rect               = {x, y, w, 100},
		padding            = PANEL_PADDING,
		content_start_left = x + PANEL_PADDING,
		content_start_top  = y + PANEL_PADDING + PANEL_HEADER,
		internal_width     = w - PANEL_PADDING * 2,
	}

	// Debug
	scale = 2
	// load_tiles("assets/tilesheets/colored_packed.png", 16, 16, &texture)
	// load_tiles("../that-guy/res/assets/tilemap.png", 16, 16, &texture)
	// _Debug

	append(
		&main_panel.items,
		Item{label = "Scale", type = .Slider, value = &scale, height = BTN_HEIGHT / 2},
	)

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

	recalc_panel_dims(
		&main_panel,
		main_panel.internal_width,
		f32(len(main_panel.items)) * (BTN_HEIGHT + PANEL_PADDING),
	)
}

save_tilemap :: proc(path: cstring) -> bool {
	if tileset.texture == nil {
		return false
	}

	map_data := Map {
		scale     = scale,
		tilesheet = tilesheet,
		tiles     = blocks,
	}
	path_parts := strings.split(string(path), "/")
	fname := strings.split(path_parts[len(path_parts) - 1], ".")
	path := strings.join(path_parts[:len(path_parts) - 1], "/")
	tilemap_fname := fmt.tprintf("%s/%s.json", path, fname[0])
	tilesheet_fname := fmt.ctprintf("%s/%s.png", path, fname[0])

	data, err := json.marshal(map_data, allocator = context.temp_allocator)
	if err != nil {
		rl.TraceLog(.ERROR, fmt.ctprintf("Error marshalling tilemap to json: %v", err))
		return false
	}
	defer free_all(context.temp_allocator)

	if ok := rl.ExportImage(rl.LoadImageFromTexture(tileset.texture^), tilesheet_fname); !ok {
		rl.TraceLog(.ERROR, fmt.ctprintf("Error saving tilesheet to: %s", tilesheet_fname))
		return false
	}

	return os.write_entire_file(tilemap_fname, data)
}

load_tiles :: proc(
	fname: cstring,
	src_tile_width, src_tile_height: f32,
	imported_tileset: ^Tileset,
) {
	imported_tileset.backing_texture = rl.LoadTexture(fname)
	imported_tileset.texture = &imported_tileset.backing_texture

	tex_num_tiles_in_row := imported_tileset.texture.width / i32(src_tile_width)
	tex_num_tiles_in_col := imported_tileset.texture.height / i32(src_tile_height)
	total_num_tiles := tex_num_tiles_in_row * tex_num_tiles_in_col

	dst_tile_width := src_tile_width * scale
	dst_tile_height := src_tile_height * scale

	panel_num_tiles_in_col := total_num_tiles / panel_num_tiles_in_row
	panel_int_height :=
		f32(panel_num_tiles_in_col) * dst_tile_height + f32(len(main_panel.items)) + 140
	panel_int_width := dst_tile_width * f32(panel_num_tiles_in_row)

	recalc_panel_dims(&main_panel, panel_int_width, panel_int_height)

	tiles_data = make([dynamic]Tile, total_num_tiles)

	for i in 0 ..< total_num_tiles {
		src_x := i32(i) % tex_num_tiles_in_row
		src_y := i32(i) / tex_num_tiles_in_row
		dst_x := i32(i) % panel_num_tiles_in_row
		dst_y := i32(i) / panel_num_tiles_in_row

		tiles_data[i] = Tile {
			src_rec = {
				x = f32(src_x) * src_tile_width,
				y = f32(src_y) * src_tile_height,
				width = src_tile_width,
				height = src_tile_height,
			},
			pos = {f32(dst_x), f32(dst_y)},
			dst_rec = {
				x = f32(dst_x) * dst_tile_width,
				y = f32(dst_y) * dst_tile_height,
				width = dst_tile_width,
				height = dst_tile_height,
			},
		}
	}

	// Redraw the new tile layout onto target texture
	tileset_width := f32(panel_num_tiles_in_row) * dst_tile_width
	tileset_height := f32(panel_num_tiles_in_col) * dst_tile_height

	tileset.render_texture = rl.LoadRenderTexture(i32(tileset_width), i32(tileset_height))
	tileset.texture = &tileset.render_texture.texture

	rl.BeginTextureMode(tileset.render_texture)
	rl.ClearBackground(rl.BLANK)

	for tile in tiles_data {
		src := tile.src_rec
		src.height *= -1
		src.x = f32(tex_num_tiles_in_row * 32) - 32 - tile.src_rec.x
		src.y = f32(tex_num_tiles_in_col * 32) - 32 - tile.src_rec.y

		dst := tile.dst_rec
		dst.x = f32(panel_num_tiles_in_row * 64) - 64 - tile.dst_rec.x

		rl.DrawTexturePro(imported_tileset.texture^, src, dst, {0, 0}, 0, rl.WHITE)
	}

	rl.EndTextureMode()

	rl.UnloadTexture(imported_tileset.texture^)
}

ui_update :: proc() -> bool {
	// Exit if input is not for the UI panel
	if !rl.CheckCollisionPointRec(input.mouse.px_pos, main_panel.rect) {
		return false
	}

	// If a tileset hasn't been loaded return
	if tileset.texture == nil {
		return false
	}

	xstart := main_panel.content_start_left
	ystart := calc_ypos(main_panel.content_start_top, len(main_panel.items))
	tileset_panel = rl.Rectangle {
		xstart,
		ystart,
		f32(tileset.texture.width),
		f32(tileset.texture.height),
	}

	// Exit if input is not for the tileset
	if !rl.CheckCollisionPointRec(input.mouse.px_pos, tileset_panel) {
		return false
	}

	// Scroll tiles
	if input.mouse.wheel_delta != 0 {
		scroll_offset += input.mouse.wheel_delta
		// Keep scroll_offset positive
		scroll_offset = scroll_offset < 0 ? 0 : scroll_offset
	}

	// Don't scroll tiles up past the top
	tileset.top_offset = ystart + scroll_offset < ystart ? 0 : 64 * scroll_offset

	// Don't scroll tiles down past the bottom
	// TODO:(lukefilewalker) is the comment says

	x := i32((input.mouse.px_pos.x - xstart) / tiles_data[0].dst_rec.width)
	y := i32((input.mouse.px_pos.y - ystart) / tiles_data[0].dst_rec.height)
	t := tiles_data[y * panel_num_tiles_in_row + x]
	hovering_tile = t.dst_rec
	hovering_tile.x += xstart
	hovering_tile.y += ystart

	if .LEFT in input.mouse.btns {
		selection = {
			tile     = t,
			selected = true,
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
					calc_ypos(main_panel.content_start_top, i),
					main_panel.internal_width,
					item.height,
				},
				item.value == nil ? fmt.ctprint(item.label) : fmt.ctprintf("%s %f", item.label, item.value^),
			)

		case .Button:
			if rl.GuiButton(
				{
					main_panel.content_start_left,
					calc_ypos(main_panel.content_start_top, i),
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
					calc_ypos(main_panel.content_start_top, i),
					main_panel.internal_width,
					item.height,
				},
				item.value == nil ? fmt.ctprint(item.label) : fmt.ctprintf("%s %f", item.label, item.value^),
			)
			rl.GuiSliderBar(
				{
					// TODO:(lukefilewalker) magic num
					main_panel.content_start_left + 120,
					calc_ypos(main_panel.content_start_top, i),
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

	ui_draw_tileset()

	ui_draw_debug()
}

ui_draw_tileset :: proc() {
	if tileset.texture == nil {
		return
	}

	src := rl.Rectangle {
		0,
		tileset.top_offset,
		f32(tileset.texture.width),
		f32(tileset.texture.height),
	}
	dst := rl.Rectangle {
		tileset_panel.x,
		tileset_panel.y,
		f32(tileset.texture.width),
		f32(tileset.texture.height),
	}

	rl.DrawTexturePro(tileset.texture^, src, dst, {0, 0}, 0, rl.WHITE)

	// Draw selected tile next to mouse cursor
	dst_selected := rl.Rectangle {
		input.mouse.px_pos.x,
		input.mouse.px_pos.y,
		selection.tile.dst_rec.width,
		selection.tile.dst_rec.height,
	}
	rl.DrawTexturePro(tileset.texture^, selection.tile.dst_rec, dst_selected, {0, 0}, 0, rl.WHITE)

	// Draw hovering tile
	rl.DrawRectangleLinesEx(hovering_tile, 3, rl.LIGHTGRAY)
}

ui_draw_debug :: proc() {
	rl.DrawText(fmt.ctprintf("num_blocks: %d", len(blocks)), 400, 10, 20, rl.LIGHTGRAY)

	rl.DrawRectangleLines(
		i32(tileset_panel.x),
		i32(tileset_panel.y),
		i32(tileset_panel.width),
		i32(tileset_panel.height),
		rl.RED,
	)
}

calc_ypos :: proc(y_from_top: f32, n: int) -> f32 {
	return y_from_top + ((BTN_HEIGHT + PANEL_PADDING) * f32(n))
}

recalc_panel_dims :: proc(panel: ^Panel, internal_w, internal_h: f32) {
	panel.rect.height = internal_h + PANEL_HEADER + panel.padding * 2
	panel.internal_width = internal_w
	panel.rect.width = panel.internal_width + panel.padding * 2
}
