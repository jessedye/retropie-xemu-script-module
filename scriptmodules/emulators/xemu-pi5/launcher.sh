#!/usr/bin/env bash
# Launcher installed by the xemu-pi5 scriptmodule.
ROM="${1:-}"
BIN="@BIN@"
CFG="@CFG@"

[ -x "$BIN" ] || { echo "xemu binary not found at $BIN" >&2; exit 1; }
[ -n "$ROM" ] && [ -f "$ROM" ] || { echo "rom not found: $ROM" >&2; exit 1; }

# x86-TSO via acquire/release accesses in the TCG aarch64 backend.
# Measured: median frame time -10%, stutters -17%. Remove to fall back to
# fence-based ordering.
export XEMU_TSO=1

# Native-double x87 helpers in place of floatx80 softfloat. With TSO, takes
# Halo 2 to its native 30 fps. Remove to fall back to bit-exact softfloat.
export XEMU_HARD_FPU=1

exec "$BIN" -config_path "$CFG" -dvd_path "$ROM"
