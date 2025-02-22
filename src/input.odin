package adventure

import rl "vendor:raylib"

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
		pos:    rl.Vector2,
		px_pos: rl.Vector2, // This is in camera/screen space
		btns:   bit_set[MouseButton],
	},
}

process_input :: proc() {
	camera.zoom += rl.GetMouseWheelMove() * 0.1

	input.mouse.px_pos = rl.GetMousePosition()

	input.mouse.btns = {}
	if rl.IsMouseButtonPressed(.LEFT) do input.mouse.btns += {.LEFT}
	if rl.IsMouseButtonPressed(.MIDDLE) do input.mouse.btns += {.MIDDLE}
	if rl.IsMouseButtonPressed(.RIGHT) do input.mouse.btns += {.RIGHT}

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
