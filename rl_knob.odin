package main

import "core:fmt"
import rl "vendor:raylib"

RLWidget :: struct {
	bounds: rl.Rectangle,
	update: proc(widget: ^RLWidget),
	draw: proc(widget: ^RLWidget),
	focused: bool,
	user_data: rawptr
}


RLKnob :: struct {
	using widget: RLWidget,
	label: string,
	index: int, // User defined index for the knob
	thickness: f32,
	value: f32,
	value_text: string,
	min: f32,
	max: f32,
	color: rl.Color,
	font_size: f32,
	angle_spread: f32,
	isDragging: bool,
	onChange: proc(knob: ^RLKnob, value: f32),
}

RLKnob_configure :: proc(knob: ^RLKnob, label: string, bounds: rl.Rectangle, value: f32, min: f32 = 0, max: f32 = 1, thickness: f32 = 15.0, color: rl.Color = rl.BLUE, angle_spread: f32 = 300, font_size: f32 = 20.0, user_data : rawptr = nil) {
	knob.label = label
	knob.value = value
	knob.user_data = user_data
	knob.min = min
	knob.max = max
	knob.font_size = font_size
	knob.angle_spread = angle_spread
	knob.bounds = bounds
	knob.thickness = thickness
	knob.color = color
	knob.update = RLKnob_update
	knob.draw = RLKnob_draw
}


RLKnob_update :: proc(widget: ^RLKnob) {
	knob := cast(^RLKnob)widget
	mouse_pos := rl.GetMousePosition()
	if rl.CheckCollisionPointRec(mouse_pos, knob.bounds) && rl.IsMouseButtonPressed(rl.MouseButton.LEFT) {
		knob.isDragging = true
	}
	if knob.isDragging {
		unit_value := (knob.value - knob.min) / (knob.max - knob.min)
		mouseDelta := rl.GetMouseDelta()
		if mouseDelta.y < 0 {
			unit_value += 0.01
		} else if mouseDelta.y > 0 {
			unit_value -= 0.005
		}
		val := unit_value * (knob.max - knob.min) + knob.min
		val = clamp(val, knob.min, knob.max)
		if val != knob.value {
			knob.value = val
			if knob.onChange != nil {
				knob.onChange(knob, val)
			}
		}
	}
	if rl.IsMouseButtonReleased(rl.MouseButton.LEFT) {
		knob.isDragging = false
	}
}

RLKnob_draw :: proc(widget: ^RLKnob) {
	knob := cast(^RLKnob)widget
	unit_value := (knob.value - knob.min) / (knob.max - knob.min)
	value_text := fmt.ctprintf("%.2f", knob.value)
	if knob.value_text != "" {
		value_text = fmt.ctprint(knob.value_text)
	}
	label_text := fmt.ctprint(knob.label)

	label_measure := rl.MeasureTextEx(OPEN_SANS, label_text, knob.font_size, 1)
	value_measure := rl.MeasureTextEx(OPEN_SANS, value_text, knob.font_size, 1)

	// kob placement in the middle
	knob_width := knob.bounds.width
	knob_height := knob.bounds.height - label_measure.y - value_measure.y
	knob_center :rl.Vector2 = {
		knob.bounds.x + knob.bounds.width / 2,
		knob.bounds.y + label_measure.y + knob_height / 2,
	}
	knob_radius := (knob_height - knob.thickness) / 2

	dif := (360 - knob.angle_spread) / 2
	value := clamp(knob.value, 0.0, 1.0)
	angle_start :f32 = -270 + dif
	backing_angle_end :f32 = angle_start + knob.angle_spread
	angle_end :f32 = angle_start + knob.angle_spread * unit_value
	inner_radius := knob_radius - 5
	outer_radius := inner_radius + knob.thickness - 4


	label_x := knob.bounds.x + (knob.bounds.width - label_measure.x) / 2
	value_x := knob.bounds.x + (knob.bounds.width - value_measure.x) / 2
	rl.DrawTextEx(OPEN_SANS, label_text, rl.Vector2{label_x, knob.bounds.y}, knob.font_size, 1, rl.WHITE)

	// Draw the background arc
	rl.DrawRing(knob_center, inner_radius, outer_radius, angle_start, backing_angle_end, i32(knob_radius * 2), rl.DARKGRAY)

	// Draw the value arc
	rl.DrawRing(knob_center, inner_radius, outer_radius, angle_start, angle_end, i32(knob_radius * 3), knob.color)

	// Draw Value Text
	rl.DrawTextEx(OPEN_SANS, value_text, rl.Vector2{value_x, knob.bounds.y + label_measure.y + knob_height}, knob.font_size, 1, rl.WHITE)
}
