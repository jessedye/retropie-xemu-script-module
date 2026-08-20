# xemu for RetroPie on Raspberry Pi 5

A RetroPie-Setup scriptmodule that builds and installs a Raspberry Pi 5
optimised build of [xemu](https://xemu.app), the original Xbox emulator,
and wires it into EmulationStation as the `xbox` system.

This is an unofficial community module. It is not affiliated with the xemu
project or RetroPie.

## What you get

The build carries measured optimisations on top of upstream xemu, each
developed against per-frame instrumentation on real hardware. Every figure
below comes from a snapshot-resumed **gameplay** scene — menus and attract
demos render two orders of magnitude less geometry and hide the costs that
matter.

| Change | Measured effect |
|---|---|
| Hot vertex regions fetched per draw instead of mirrored | Morrowind median frame −44%, GPU busy −74%; GTA stutters −86% |
| Vulkan swapchain presentation (no GL interop, no readback) | +7% fps, 1%-low +18% |
| x86-TSO via LDAPR/STLR instead of per-access fences | median frame time −10%, stutters −17% |
| Native-double x87 helpers | p99 −8%, 1%-low +14% |
| Direct render-target sampling (no per-frame copies) | stutters −15%, 1%-low +7% |
| Vulkan present loop paced to vblank | p99 −6%, stutters −17% |
| Deferred flip-stall wait | GTA median frame −10% |

End to end, against the same build with the renderer changes disabled:

| Game | Median frame | p99 | 1% low | Stutters |
|---|---|---|---|---|
| Morrowind | 115 ms -> **57 ms** | -40% | +23% | - |
| GTA San Andreas | 42 ms -> **34 ms** | -27% | +32% | **-50%** |
| Tony Hawk 3 | unchanged | - | - | - |

Tony Hawk 3 is the control: it never suffered the vertex stall, so the
changes are inert there. They engage only where a game is paying the cost.

A correctness fix rides along: the renderer could overwrite vertex data while
a recorded draw still referred to it, measured at 3.4 times per frame in
Morrowind.

Compatibility beyond that follows upstream xemu.

Fixes from this work are being upstreamed to xemu
([#2977](https://github.com/xemu-project/xemu/pull/2977),
[#2979](https://github.com/xemu-project/xemu/pull/2979),
[#2980](https://github.com/xemu-project/xemu/pull/2980),
[#2981](https://github.com/xemu-project/xemu/pull/2981)); this module
tracks the integration branch until they land.

## Requirements

- Raspberry Pi 5 (the Vulkan work targets V3DV; 2 GB RAM is enough — the
  build uses temporary swap)
- RetroPie on 64-bit Raspberry Pi OS (Bookworm)
- Your own dumps of the Xbox BIOS and an HDD image (see below). These are
  copyrighted and are not, and will never be, distributed by this module.

## Install

```sh
cd ~/RetroPie-Setup
sudo mkdir -p ext
sudo git clone https://github.com/jessedye/retropie-xemu-script-module.git ext/xemu-pi5
sudo ./retropie_setup.sh
```

Then: Manage packages → exp → xemu-pi5 → Install from source.

The source build takes a while on the Pi (large tree, `-j2` on 2 GB).

## BIOS files

Place in `~/RetroPie/BIOS/xemu/`:

```
mcpx_1.0.bin       MCPX boot ROM
complex_4627.bin   flash BIOS
eeprom.bin         EEPROM
xbox_hdd.qcow2     HDD image
```

ROMs (`.iso` / `.xiso`) go in `~/RetroPie/roms/xbox/`.

## EmulationStation artwork

Carbon and its derivatives ship no `xbox` system art, so EmulationStation
falls back to plain text in the default red. The module installs a logo, a
controller silhouette and a green accent colour into every installed theme
that has the usual `art/systems` layout. Nothing else in the theme is
touched, and a theme without that layout is skipped.

## Performance switches

The launcher enables the runtime optimisations that are not on by default.
Each has an off switch documented inline in
`/opt/retropie/emulators/xemu-pi5/launcher.sh` — delete the relevant `export`
line to fall back to upstream behaviour.

The renderer changes above need no switch: they are the build's default, and
each carries an environment variable to disable it if a title misbehaves
(`XEMU_VTX_HOT_REMAP=0`, `XEMU_VTX_PRECISE=0`, `XEMU_ASYNC_FLIP=0`).

Worth knowing for a 2 GB Pi: `dtoverlay=vc4-kms-v3d,cma-512` in
`/boot/firmware/config.txt` gives the GPU enough contiguous memory, and a
modest V3D overclock (`v3d_freq=1350`) measured +9% fps.

## Troubleshooting

- **Black screen, straight back to EmulationStation**: almost always a
  missing/unreadable BIOS file or HDD image; run the launcher by hand to
  see the error.
- **Game hangs at first loading screen**: try clearing the HDD cache
  partition (mount the qcow2 and clear the X/Y/Z partitions), a stock xemu
  behaviour on dirty cache state.
- **Choppy despite good fps**: make sure nothing else owns the GPU
  (a leftover X server, a compositor).
- **Xbox menu still shows plain red text**: the theme was installed after
  this module. Re-run the module's Configure step, or copy
  `scriptmodules/emulators/xemu-pi5/theme/` into the theme by hand.

## License

The scriptmodule, launcher and config seed in this repository are MIT
licensed. xemu itself is GPLv2+ and its build produces its own license
bundle; the BIOS files are copyrighted by their respective owners and must
be dumped from your own console.
