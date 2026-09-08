package main

import "core:fmt"
import "vendor:darwin/Metal"
WaveView :: struct {
	data: [][2]f32,
	widthPixels: int,
	buffer: ^AudioBuffer,
	startFrame: u64,
	endFrame: u64,
	cacheInvalidated: bool,
	generate: proc(view: ^WaveView, widthPixels: int, startFrame: u64, endFrame: u64) -> bool,
	setWindow: proc(view: ^WaveView, startFrame: u64, endFrame: u64),
	setWidth: proc(view: ^WaveView, widthPixels: int),
	setBuffer: proc(view: ^WaveView, buffer: ^AudioBuffer),
}

WaveView_configure :: proc(view: ^WaveView, widthPixels: int, startFrame: u64, endFrame: u64) {
	view.setBuffer = WaveView_setBuffer
	view.setWindow = WaveView_setWindow
	view.setWidth = WaveView_setWidth
	view.generate = WaveView_generate
}

WaveView_setWindow :: proc(view: ^WaveView, startFrame: u64, endFrame: u64) {
	if startFrame != view.startFrame || endFrame != view.endFrame {
		view.cacheInvalidated = true
	}
	view.startFrame = clamp(startFrame, 0, view.buffer.frames)
	view.endFrame = clamp(endFrame, 0, view.buffer.frames)
}

WaveView_setWidth :: proc(view: ^WaveView, widthPixels: int) {
	if widthPixels != view.widthPixels {
		view.cacheInvalidated = true
	}
	view.widthPixels = widthPixels
}

WaveView_setBuffer :: proc(view: ^WaveView, buffer: ^AudioBuffer) {
	if buffer != view.buffer {
		view.cacheInvalidated = true
		view.buffer = buffer
		view.startFrame = 0
		view.endFrame = buffer.frames - 1
	}
}


WaveView_generate :: proc(view: ^WaveView, widthPixels: int, startFrame: u64, endFrame: u64) -> bool {
	view->setWidth(widthPixels)
	view->setWindow(startFrame, endFrame)
	if view.cacheInvalidated {
		buffer := view.buffer
		frameCount := view.endFrame - view.startFrame
		interval := u64(f64(frameCount) / f64(view.widthPixels))
		view.data = make([][2]f32, view.widthPixels)

		for pixel in 0..<frameCount {

			index := pixel / interval
			if index >= auto_cast len(view.data) {
				continue
			}
			frame := view.startFrame + pixel
			value := buffer->read(frame)
			view.data[index][0] = min(view.data[index][0], value)
			view.data[index][1] = max(view.data[index][1], value)
		}
		view.cacheInvalidated = false
		return true
	}
	return false
}
