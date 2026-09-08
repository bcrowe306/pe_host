package main

import "core:bytes"
import "core:time"
import "base:runtime"
import "core:log"
import "core:fmt"
import "rtmidi"
import pa "./portaudio"
import rl "vendor:raylib"
import ped "port_engine_device"
import "core:os"

import "core:dynlib"



DeviceLibrary :: struct {
	realoadCounte: u32,
	filePath: string,
	library: dynlib.Library,
	device: ^ped.Device,
	device_entry: ^ped.Entry,
	load: proc(device_library: ^DeviceLibrary, filePath: string, device_index: u32) -> ^ped.Device,
	unload: proc(device_library: ^DeviceLibrary),
	deviceState: bytes.Buffer,
}

DeviceLibrary_load :: proc(device_library: ^DeviceLibrary, filePath: string, device_index: u32) -> ^ped.Device {

	// Check for filePath existence
	fileInfor, err := os.stat(filePath, runtime.default_allocator())
	if err != nil {
		fmt.println("Error getting file info: ", err)
		return nil
	}


	library, didLoad := dynlib.load_library(filePath)
	if !didLoad {
		fmt.println("Failed to load ", filePath)
		return nil
	}
	device_entry_ptr, found := dynlib.symbol_address(library, "device_entry")
	if !found {
		fmt.println("Failed to find device_entry symbol in ", filePath)
		return nil
	}
	device_entry := cast(^ped.Entry)device_entry_ptr
	device_factory := device_entry.get_factory()
	device_library.device = device_factory->create_device(device_index)
	if len(device_library.deviceState.buf) > 0 {
		bufStream := bytes.buffer_to_stream(&device_library.deviceState)
		fmt.printfln("Loading device state from buffer of size: %d", len(device_library.deviceState.buf))
		device_library.device->load(&bufStream)
		fmt.println("Device state loaded successfully.")
	}
	device_library.library = library
	device_library.device_entry = device_entry
	device_library.filePath = filePath
	device_library.device->init()

	device_library.device->activate(44100.0, 64, 512)

	device_library.device->start_processing()
	device_library.realoadCounte += 1
	return device_library.device
}

DeviceLibrary_unload :: proc(device_library: ^DeviceLibrary) {
	dev := device_library.device
	bufStream := bytes.buffer_to_stream(&device_library.deviceState)
	dev->stop_processing()
	dev->deactivate()
	device_library.device->save(&bufStream)
	// print device state:
	fmt.printfln("Saving device state to buffer of size: %d", len(device_library.deviceState.buf))
	dev->destroy()
	if device_library.library != nil {
		dynlib.unload_library(device_library.library)
		device_library.library = nil
		device_library.device_entry = nil
	}
}

DeviceLibrary_configure :: proc(device_library: ^DeviceLibrary) {
	device_library.load = DeviceLibrary_load
	device_library.unload = DeviceLibrary_unload
}


WINDOW_WIDTH :: 950
WINDOW_HEIGHT :: 720
OPEN_SANS: rl.Font


draw_waveform :: proc(target: ^rl.RenderTexture2D, waveView: ^WaveView) {
	waveformTexture := target^
	rl.BeginTextureMode(waveformTexture)
	tW := waveformTexture.texture.width
	tH := waveformTexture.texture.height

	rl.ClearBackground(rl.BLACK)
		rl.DrawRectangle(0, 0, auto_cast tW, auto_cast tH, rl.BLACK)

		// draw vertical wave lines
		yStart := f64(tH / 2)
		for view, index in waveView.data {
			x := i32(index) + 1
			y := yStart + auto_cast view[0] * auto_cast (tH / 2)
			rl.DrawLine(x, i32(y), i32(x), i32(yStart + auto_cast view[1] * auto_cast (tH / 2)), rl.SKYBLUE)
		}
	rl.EndTextureMode()
}

mTime : time.Time
paramValues : [128]f32
realoding : bool

main :: proc() {
	logger := log.create_console_logger(.Debug)
	context.logger = logger
	audioEngine : AudioEngine
	AudioEngine_Configure(&audioEngine)
	audioEngine->init()
	defer audioEngine->deinit()

	rtMidiOut := rtmidi.out_create_default()
	midiDevices := rtmidi.get_port_count(rtMidiOut)
	bufLen : i32
	for i in 0..<midiDevices {
		rtmidi.get_port_name(rtMidiOut, i, nil, &bufLen)
		buf := make([]u8, bufLen)
		portName := cast(cstring)(&buf[0])
		rtmidi.get_port_name(rtMidiOut, i, portName, &bufLen)
		fmt.println("MIDI Device: ", portName)
		delete(buf)
	}

	device_library := DeviceLibrary{}
	DeviceLibrary_configure(&device_library)
	device_library->load("device.dylib", 0)
	device := device_library.device
	node := AudioDeviceNode_create(device_library.device)
	node.callbackUserData = &device_library
	audioEngine->addNode(node)
	node.processFinishedCallback = proc(node: ^AudioDeviceNode, user_data: rawptr) {
		device_library := cast(^DeviceLibrary)user_data
		fileInfo, err := os.stat(device_library.filePath, runtime.default_allocator())
		if err != nil {
			fmt.println("Error getting file info: ", err)
		} else {
			if mTime == {} {
				mTime = fileInfo.modification_time
				return
			}
			if fileInfo.modification_time != mTime {
				fmt.println("File modified at: ", fileInfo.modification_time)
				fmt.println("Reloading device...")
				realoding = true
				node.device = nil
				device_library->unload()
				device_library->load("device.dylib", 0)
				node.device = device_library.device
				realoding = false
			}
			mTime = fileInfo.modification_time
			os.file_info_delete(fileInfo, runtime.default_allocator())
		}
	}


	audioEngine->start()
	rl.SetTraceLogLevel(.WARNING)
	rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Audio Player")
	rl.SetWindowPosition(400, 20)
	paramCount := device->get_param_count()

	for i in 0..<paramCount {
		paramValues[i] = f32(device->get_param_info(i)->evaluate())
	}

	knobs : [dynamic]RLKnob
	for i in 0..<paramCount {
		paramInfo := device->get_param_info(i)
		knob := RLKnob{}
		knobBounds := rl.Rectangle{10 + 120 * auto_cast i, 100, 100, 100}
		RLKnob_configure(&knob, paramInfo.name, knobBounds, paramValues[i], auto_cast paramInfo.min, auto_cast paramInfo.max, user_data = &node)
		knob.index = int(i)
		knob.user_data  = node
		knob.onChange = proc(knob: ^RLKnob, value: f32) {
			node := cast(^AudioDeviceNode)knob.user_data
			node->setParameterValue(u32(knob.index), f64(value))
		}
		_, err := append(&knobs, knob)
		if err != nil {
			fmt.println("Error appending knob: ", err)
		}
	}
	OPEN_SANS = rl.LoadFont("OpenSans.ttf")


	// Main loop
	for !rl.WindowShouldClose() {
		rl.BeginDrawing()
		rl.ClearBackground(rl.BLACK)
		if realoding {
			rl.DrawText("Reloading device...", 100, 100, 20, rl.RED)
			rl.EndDrawing()
			continue
		}
		dev := device_library.device
		for &knob in knobs {
			knob.update(cast(^RLWidget)&knob)
			knob.draw(cast(^RLWidget)&knob)
		}



		rl.EndDrawing()
	}

}
