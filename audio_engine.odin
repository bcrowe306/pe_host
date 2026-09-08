package main

import pa "./portaudio"
import "base:runtime"
import "core:c"
import "core:fmt"
import "core:mem"
import "core:os"
import "core:log"



AudioContext :: struct {
	inputChannels:   u32,
	outputChannels:  u32,
	sampleRate:      f64,
	framesPerBuffer: u32,
}


check_result :: proc(error: i32, loc := #caller_location) {
	if pa.ErrorCode(error) != .NoError {
		fmt.printf("%v - %v", loc, pa.GetErrorText(error))
		os.exit(1)
	}
}

AudioEngine :: struct {
	audioContext:       AudioContext,
	nodes:              [dynamic]^AudioNode,
	addNode:            proc(audioEngine: ^AudioEngine, node: ^AudioNode),
	removeNode:         proc(audioEngine: ^AudioEngine, node: ^AudioNode),
	stream:             ^pa.Stream,
	midiBuffer:         []MidiEvent,
	process:            proc(audioEngine: ^AudioEngine, inputBuffer: []f32, outputBuffer: []f32),
	audioCallback:      proc "c" (
		input: rawptr,
		output: rawptr,
		frameCount: c.ulong,
		timeInfo: ^pa.StreamCallbackTimeInfo,
		statusFlags: pa.StreamCallbackFlags,
		userData: rawptr,
	) -> int,
	init:               proc(audioEngine: ^AudioEngine),
	deinit:             proc(audioEngine: ^AudioEngine),
	start:              proc(audioEngine: ^AudioEngine),
	stop:               proc(audioEngine: ^AudioEngine),
	setSampleRate:      proc(audioEngine: ^AudioEngine, sampleRate: f64),
	setFramesPerBuffer: proc(audioEngine: ^AudioEngine, framesPerBuffer: u32),
	setInputChannels:   proc(audioEngine: ^AudioEngine, channels: u32),
	setOutputChannels:  proc(audioEngine: ^AudioEngine, channels: u32),
}


AudioEngine_process :: proc(audioEngine: ^AudioEngine, inputBuffer: []f32, outputBuffer: []f32) {
	if len(audioEngine.nodes) == 0 {
		// If there are no nodes, mem write zeros to the output buffer
		ctx := audioEngine.audioContext
		mem.set(cast(rawptr)&outputBuffer[0], 0, int(size_of(f32) * ctx.framesPerBuffer * ctx.outputChannels))
	}

	for node in audioEngine.nodes {
		node.process(node, &audioEngine.audioContext, outputBuffer, audioEngine.midiBuffer)
	}
}

AudioEngine_callback :: proc "c" (
	input: rawptr,
	output: rawptr,
	frameCount: c.ulong,
	timeInfo: ^pa.StreamCallbackTimeInfo,
	statusFlags: pa.StreamCallbackFlags,
	userData: rawptr,
) -> int {
	context = runtime.default_context()
	audioEngine := cast(^AudioEngine)userData
	inputBuffer := mem.slice_ptr(cast(^f32)input, int(frameCount) * 2)
	outputBuffer := mem.slice_ptr(cast(^f32)output, int(frameCount) * 2)

	mem.set(cast(rawptr)&outputBuffer[0], 0, int(size_of(f32) * frameCount * auto_cast audioEngine.audioContext.outputChannels))

	audioEngine.process(audioEngine, inputBuffer, outputBuffer)
	return 0
}

AudioEngine_init :: proc(audioEngine: ^AudioEngine) {
	check_result(pa.Initialize())
	log.info("AudioEngine initialized")
}

AudioEngine_deinit :: proc(audioEngine: ^AudioEngine) {
	check_result(pa.Terminate())
	log.info("AudioEngine terminated")
}

AudioEngine_start :: proc(audioEngine: ^AudioEngine) {
	ctx := audioEngine.audioContext
	if ctx.framesPerBuffer == 0 || ctx.sampleRate == 0 || ctx.outputChannels == 0 {
		fmt.println(
			"Cannot start audio engine: framesPerBuffer, sampleRate, and outputChannels must be non-zero",
		)
		os.exit(1)
	}
	check_result(
		pa.OpenDefaultStream(
			&audioEngine.stream,
			auto_cast audioEngine.audioContext.inputChannels,
			auto_cast audioEngine.audioContext.outputChannels,
			pa.Float32,
			audioEngine.audioContext.sampleRate,
			auto_cast audioEngine.audioContext.framesPerBuffer,
			AudioEngine_callback,
			audioEngine,
		),
	)
	check_result(pa.StartStream(audioEngine.stream))
	log.info("AudioEngine started")
}

AudioEngine_stop :: proc(audioEngine: ^AudioEngine) {
	check_result(pa.StopStream(audioEngine.stream))
	log.info("AudioEngine stopped")
}

AudioEngine_Configure :: proc(
	audioEngine: ^AudioEngine,
	inputChannels: u32 = 0,
	outputChannels: u32 = 2,
	sampleRate: f64 = 44100.0,
	framesPerBuffer: u32 = 256,
) {
	audioEngine.audioContext.inputChannels = inputChannels
	audioEngine.audioContext.outputChannels = outputChannels
	audioEngine.audioContext.sampleRate = sampleRate
	audioEngine.audioContext.framesPerBuffer = framesPerBuffer
	audioEngine.audioCallback = AudioEngine_callback
	audioEngine.process = AudioEngine_process
	audioEngine.init = AudioEngine_init
	audioEngine.deinit = AudioEngine_deinit
	audioEngine.start = AudioEngine_start
	audioEngine.stop = AudioEngine_stop
	audioEngine.addNode = AudioEngine_addNode
	audioEngine.removeNode = AudioEngine_removeNode
}

AudioEngine_setSampleRate :: proc(audioEngine: ^AudioEngine, sampleRate: f64) {
	res := pa.IsStreamStopped(audioEngine.stream)
	if res == 1 { 	// Is stopped
		check_result(pa.CloseStream(audioEngine.stream))
	} else if res == 0 { 	// Stream is not stopped
		check_result(pa.StopStream(audioEngine.stream))
		check_result(pa.CloseStream(audioEngine.stream))
	}
	log.info("AudioEngine sample rate set to %v", sampleRate)
	audioEngine.audioContext.sampleRate = sampleRate
	audioEngine->start()
}

AudioEngine_setFramesPerBuffer :: proc(audioEngine: ^AudioEngine, framesPerBuffer: u32) {
	res := pa.IsStreamStopped(audioEngine.stream)
	if res == 1 { 	// Is stopped
		check_result(pa.CloseStream(audioEngine.stream))
	} else if res == 0 { 	// Stream is not stopped
		check_result(pa.StopStream(audioEngine.stream))
		check_result(pa.CloseStream(audioEngine.stream))
	}
	log.info("AudioEngine frames per buffer set to %v", framesPerBuffer)
	audioEngine.audioContext.framesPerBuffer = framesPerBuffer
	audioEngine->start()
}


AudioEngine_setOutputChannels :: proc(audioEngine: ^AudioEngine, outputChannels: u32) {
	res := pa.IsStreamStopped(audioEngine.stream)
	if res == 1 { 	// Is stopped
		check_result(pa.CloseStream(audioEngine.stream))
	} else if res == 0 { 	// Stream is not stopped
		check_result(pa.StopStream(audioEngine.stream))
		check_result(pa.CloseStream(audioEngine.stream))
	}
	log.info("AudioEngine output channels set to %v", outputChannels)
	audioEngine.audioContext.outputChannels = outputChannels
	audioEngine->start()
}
AudioEngine_setInputChannels :: proc(audioEngine: ^AudioEngine, inputChannels: u32) {
	res := pa.IsStreamStopped(audioEngine.stream)
	if res == 1 { 	// Is stopped
		check_result(pa.CloseStream(audioEngine.stream))
	} else if res == 0 { 	// Stream is not stopped
		check_result(pa.StopStream(audioEngine.stream))
		check_result(pa.CloseStream(audioEngine.stream))
	}
	log.info("AudioEngine input channels set to %v", inputChannels)
	audioEngine.audioContext.inputChannels = inputChannels
	audioEngine->start()
}

AudioEngine_addNode :: proc(audioEngine: ^AudioEngine, node: ^AudioNode) {
	append(&audioEngine.nodes, node)
	log.info("AudioEngine node added")
}

AudioEngine_removeNode :: proc(audioEngine: ^AudioEngine, node: ^AudioNode) {
	index : int
	for node, i in audioEngine.nodes {
		if node == node {
			index = i
			break
		}
	}
	if index != -1 {
		ordered_remove(&audioEngine.nodes, index)
	}
	log.info("AudioEngine node removed")
}
