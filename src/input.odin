package tyler

import rl "vendor:raylib"

MOUSE_SCROLL_SPEED :: 30
MOUSE_PAN_SPEED :: 500

MouseButton :: enum {
	LEFT,
	MIDDLE,
	RIGHT,
}

GamepadButton :: enum {
	RIGHT_FACE_UP,
	RIGHT_FACE_RIGHT,
	RIGHT_FACE_DOWN,
	RIGHT_FACE_LEFT,
	LEFT_SHOULDER,
	RIGHT_SHOULDER,
	LEFT_TRIGGER,
	RIGHT_TRIGGER,
}

KeyboardButton :: enum {
	SPACE,
}

Input :: struct {
	kb:      struct {
		axis: rl.Vector2,
		btns: bit_set[KeyboardButton],
	},
	gamepad: struct {
		laxis: rl.Vector2,
		raxis: rl.Vector2,
		btns:  bit_set[GamepadButton],
	},
	mouse:   struct {
		pos:         rl.Vector2,
		px_pos:      rl.Vector2, // This is in camera/screen space
		prev_px_pos: rl.Vector2, // This is in camera/screen space
		btns:        bit_set[MouseButton],
		wheel_delta: f32,
		is_panning:  bool,
	},
}

process_input :: proc() {
	// camera.zoom += rl.GetMouseWheelMove() * 0.1
	input.mouse.wheel_delta = rl.GetMouseWheelMove()
	input.mouse.px_pos = rl.GetMousePosition()

	input.mouse.btns = {}
	if rl.IsMouseButtonDown(.LEFT) do input.mouse.btns += {.LEFT}
	if rl.IsMouseButtonUp(.LEFT) do input.mouse.btns -= {.LEFT}
	if rl.IsMouseButtonDown(.RIGHT) do input.mouse.btns += {.RIGHT}
	if rl.IsMouseButtonUp(.RIGHT) do input.mouse.btns -= {.RIGHT}
	if rl.IsMouseButtonDown(.MIDDLE) do input.mouse.btns += {.MIDDLE}
	if rl.IsMouseButtonUp(.MIDDLE) do input.mouse.btns -= {.MIDDLE}

	input.gamepad.laxis.x = rl.GetGamepadAxisMovement(0, .LEFT_X)
	input.gamepad.laxis.y = rl.GetGamepadAxisMovement(0, .LEFT_Y)
	input.gamepad.raxis.x = rl.GetGamepadAxisMovement(0, .RIGHT_X)
	input.gamepad.raxis.y = rl.GetGamepadAxisMovement(0, .RIGHT_Y)

	input.gamepad.btns = {}
	if rl.IsGamepadButtonPressed(0, .RIGHT_FACE_UP) do input.gamepad.btns += {.RIGHT_FACE_UP}
	if rl.IsGamepadButtonPressed(0, .RIGHT_FACE_RIGHT) do input.gamepad.btns += {.RIGHT_FACE_RIGHT}
	if rl.IsGamepadButtonPressed(0, .RIGHT_FACE_DOWN) do input.gamepad.btns += {.RIGHT_FACE_DOWN}
	if rl.IsGamepadButtonPressed(0, .RIGHT_FACE_LEFT) do input.gamepad.btns += {.RIGHT_FACE_LEFT}
	if rl.IsGamepadButtonPressed(0, .LEFT_TRIGGER_1) do input.gamepad.btns += {.LEFT_SHOULDER}
	if rl.IsGamepadButtonDown(0, .LEFT_TRIGGER_2) do input.gamepad.btns += {.LEFT_TRIGGER}
	if rl.IsGamepadButtonPressed(0, .RIGHT_TRIGGER_1) do input.gamepad.btns += {.RIGHT_SHOULDER}
	if rl.IsGamepadButtonDown(0, .RIGHT_TRIGGER_2) do input.gamepad.btns += {.RIGHT_TRIGGER}

	input.kb.axis.x = btof(rl.IsKeyDown(.RIGHT)) - btof(rl.IsKeyDown(.LEFT))
	input.kb.axis.x += btof(rl.IsKeyDown(.D)) - btof(rl.IsKeyDown(.A))
	input.kb.axis.y = btof(rl.IsKeyDown(.DOWN)) - btof(rl.IsKeyDown(.UP))
	input.kb.axis.y += btof(rl.IsKeyDown(.S)) - btof(rl.IsKeyDown(.W))

	input.kb.btns = {}
	if rl.IsKeyDown(.SPACE) do input.kb.btns += {.SPACE}
}

btof :: proc(b: bool) -> f32 {
	return b ? 1.0 : 0.0
}
