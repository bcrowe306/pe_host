# Port Engine Device Template

This directory is a minimal Port Engine Device SDK plugin implemented as a
shared library. It exposes one gain audio effect and is intended to be copied
and adapted for a new device.

## Build

From this directory, run:

```sh
./build.sh
```

This creates `template_device.dylib` on macOS. To target another platform,
change the output extension in `build.sh` as appropriate (for example, `.so`
on Linux or `.dll` on Windows).

## Customize

1. Change the package name and the `template_` identifiers.
2. Update `template_descriptor`, especially its stable `id` and metadata.
3. Replace `Template_Device_State` and `template_process_audio` with the
   device's DSP implementation.
4. Add parameters with `device->create_param()` and non-real-time fields with
   `device->create_field()`.

The required ABI export is the global `device_entry : pe.Entry` in
`entry.odin`. Keep its name unchanged: the host uses it to discover the
plugin's factory.
