package device_template

import pe "../port_engine_device"

template_create_fields :: proc(device: ^pe.Device) {
	file_path := device->create_field("filePath", "", "File Path")
	pe.DeviceField_configure(file_path)
}
