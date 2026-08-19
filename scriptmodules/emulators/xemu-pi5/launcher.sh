#!/usr/bin/env bash
# Launcher installed by the xemu-pi5 scriptmodule.
ROM="${1:-}"
BIN="@BIN@"
CFG="@CFG@"

[ -x "$BIN" ] || { echo "xemu binary not found at $BIN" >&2; exit 1; }
[ -n "$ROM" ] && [ -f "$ROM" ] || { echo "rom not found: $ROM" >&2; exit 1; }

# Vulkan swapchain presentation; without it every frame is read back through
# guest memory and re-uploaded to GL (5-14 ms/frame measured in play).
export XEMU_DISPLAY_BACKEND=vulkan

# x86-TSO via acquire/release accesses in the TCG aarch64 backend.
# Measured: median frame time -10%, stutters -17%. Remove to fall back to
# fence-based ordering.
export XEMU_TSO=1

# Native-double x87 helpers in place of floatx80 softfloat (31 = all helper
# groups). With TSO, takes Halo 2 to its native 30 fps. Remove to fall back
# to bit-exact softfloat.
export XEMU_HARD_FPU=31

# Sample render targets directly as textures instead of copying them.
# Measured: stutters -15%, 1% low +7%. Remove to use the copy path.
export XEMU_SURF_TEX_SAMPLE=1

exec "$BIN" -config_path "$CFG" -dvd_path "$ROM"
