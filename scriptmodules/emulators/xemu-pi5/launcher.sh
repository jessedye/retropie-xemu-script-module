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

# Per-session frame timings and console output. Both streams share one stem so
# a CSV and its log can be paired, and each run is named so that switching
# games never overwrites the previous one - a fixed path loses the run you
# wanted the moment you launch anything else.
#
# Set XEMU_NO_LOG=1 to turn this off.
if [ "${XEMU_NO_LOG:-0}" != "1" ]; then
    LOGDIR="${XEMU_LOG_DIR:-$HOME/perflogs}"
    if mkdir -p "$LOGDIR" 2>/dev/null; then
        name=$(basename "$ROM" | tr -c "A-Za-z0-9._-" "_" | cut -c1-40)
        stamp=$(date +%Y%m%d-%H%M%S)

        # A fixed XEMU_PERFLOG inherited from emulators.cfg would defeat the
        # per-run naming, so only honour one that is not that shared path.
        case "${XEMU_PERFLOG:-}" in
            ""|"$HOME/xemu-perf.csv")
                export XEMU_PERFLOG="$LOGDIR/${name}-${stamp}.csv" ;;
        esac
        export XEMU_FPS=1

        # Bounded, so a long session cannot fill the card.
        ls -1t "$LOGDIR"/*.csv 2>/dev/null | tail -n +61 | xargs -r rm -f
        ls -1t "$LOGDIR"/*.log 2>/dev/null | tail -n +61 | xargs -r rm -f

        LOG="$LOGDIR/${name}-${stamp}.log"
        if : > "$LOG" 2>/dev/null; then
            ln -sfn "$LOG" "$HOME/xemu-last.log" 2>/dev/null || true
            exec "$BIN" -config_path "$CFG" -dvd_path "$ROM" > "$LOG" 2>&1
        fi
    fi
fi

exec "$BIN" -config_path "$CFG" -dvd_path "$ROM"
