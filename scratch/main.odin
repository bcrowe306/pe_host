package main

import "core:math"
import "core:strings"

import "core:fmt"
import "gui:skald"

KnobState :: struct {
	value: f32,
	isDragging: bool,
}

State :: struct {
    draft: string,
    knob_value: f32,
    knob_state: KnobState,
}

Msg :: union {
    Draft_Changed,
    Knob_Changed,
    KnobDragChanged
}

Draft_Changed :: distinct string
Knob_Changed :: distinct f32
KnobDragChanged :: distinct bool


init :: proc() -> State {
	return {
		draft = strings.clone(""),
		knob_value = 0.6,
	}
}

update :: proc(s: State, m: Msg) -> (State, skald.Command(Msg)) {
	out := s
	#partial switch v in m {
	case Draft_Changed:
		delete(out.draft)
		out.draft = strings.clone(string(v))
	case Knob_Changed:
		out.knob_value = f32(clamp(f64(v), 0.0, 1.0))
	}
	return out, {}
}

on_draft :: proc(v: string) -> Msg {
	return Draft_Changed(v)
}


view :: proc(s: State, ctx: ^skald.Ctx(Msg)) -> skald.View {
    th := ctx.theme
    center :[2]f32 = {100, 100}
    radius :f32 = 50.0
    thickness :f32 = 15.0
    spread :f32 = 300.0
    value :f32 = s.knob_value
    dif :f32 = (360.0 - spread) / 2.0
    unit :f32 = spread * value
    start := math.to_radians_f32(-270.0 + dif)
    end := math.to_radians_f32(-270.0 + unit + dif)
    endFull := math.to_radians_f32(-270.0 + spread + dif)
    skald.draw_arc(ctx.renderer, center, radius, start, endFull, thickness, {0.01, 0.01, 0.01, 1.0})
    skald.draw_arc(ctx.renderer, center, radius, start, end, thickness, th.color.primary)

    if .Down in ctx.input.keys_pressed{
    	skald.send(ctx, Knob_Changed(s.knob_value - .01))
	}
	if .Up in ctx.input.keys_pressed{
		skald.send(ctx, Knob_Changed(s.knob_value + .01))
	}

	if ctx.input.mouse_pressed[.Left] {
		skald.send(ctx, KnobDragChanged(true))
	}
	else {
		skald.send(ctx, KnobDragChanged(false))
	}

    return skald.col(
    	skald.text_input(ctx, s.draft, on_draft, width = 300)
    )
}

main :: proc() {
	skald.run(skald.App(State, Msg) {
        title  = "Todo",
        size   = {480, 600},
        theme  = skald.theme_dark(),
        init   = init,
        update = update,
        view   = view,
    })
}
