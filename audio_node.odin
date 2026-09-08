package main
import ped "port_engine_device"

AudioNode :: struct {
	process: proc(node: ^AudioNode, audioContext: ^AudioContext, outputBuffer: []f32, midiBuffer: []MidiEvent),
}

AudioNode_create :: proc(device: ^ped.Device) -> ^AudioNode {
	node := new(AudioNode)
	AudioNode_configure(node)
	return node
}

AudioNode_configure :: proc(node: ^AudioNode){
	node.process = AudioNode_process
}

AudioNode_process :: proc(node: ^AudioNode, audioContext: ^AudioContext, outputBuffer: []f32, midiBuffer: []MidiEvent) {

}
