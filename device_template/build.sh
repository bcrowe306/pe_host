#!/usr/bin/env sh
set -eu

odin build . -build-mode:dll -out:template_device.dylib
