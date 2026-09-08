package device_template

import pe "../port_engine_device"

template_factory := pe.DeviceFactory{
	get_device_count = template_get_device_count,
	get_device_info  = template_get_device_info,
	create_device    = template_create_device,
}

template_get_device_count :: proc(factory: ^pe.DeviceFactory) -> u32 {
	return 1
}

template_get_device_info :: proc(
	factory: ^pe.DeviceFactory,
	index: u32,
) -> ^pe.Device_Descriptor {
	if index != 0 {
		return nil
	}

	return &template_descriptor
}
