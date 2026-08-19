#!/usr/bin/env bash

# This file is part of the retropie-xemu-script-module project, an external
# scriptmodule for RetroPie-Setup. It is not part of the RetroPie or xemu
# projects.
#
# Installs a Raspberry Pi 5 optimised build of the xemu original-Xbox
# emulator: Vulkan swapchain presentation (no GL interop), x86-TSO via
# acquire/release accesses, and native-double x87 helpers. Measured on
# Halo 2: native 30 fps; GTA San Andreas: steady 60.

rp_module_id="xemu-pi5"
rp_module_desc="xemu - original Xbox emulator (Pi 5 optimised build)"
rp_module_help="ROM Extensions: .iso .xiso\n\nCopy your Xbox ISOs to $romdir/xbox\n\nYou must supply your own dumps in $biosdir/xemu:\n  mcpx_1.0.bin       (MCPX boot ROM)\n  complex_4627.bin   (flash BIOS)\n  eeprom.bin         (EEPROM)\n  xbox_hdd.qcow2     (HDD image)\n\nThese are copyrighted and cannot be distributed with this module."
rp_module_licence="GPL2 https://raw.githubusercontent.com/jessedye/xemu/vulkan-ui-without-gl4/LICENSE"
rp_module_repo="git https://github.com/jessedye/xemu.git vulkan-ui-without-gl4"
rp_module_section="exp"
rp_module_flags="!all rpi5"

function depends_xemu-pi5() {
    getDepends git ninja-build cmake python3-yaml \
        libepoxy-dev libpixman-1-dev libgtk-3-dev libssl-dev \
        libsamplerate0-dev libpcap-dev libslirp-dev libcurl4-gnutls-dev \
        libglib2.0-dev libdrm-dev libgbm-dev libgl1-mesa-dev libegl1-mesa-dev \
        libvulkan-dev libx11-dev libxext-dev libxrandr-dev libxcursor-dev \
        libxi-dev libxkbcommon-dev libwayland-dev
}

function sources_xemu-pi5() {
    gitPullOrClone
}

function build_xemu-pi5() {
    # ~2 GiB of RAM is not enough for parallel linking without swap.
    rpSwap on 2048
    ./build.sh -j2
    rpSwap off
    md_ret_require="$md_build/dist/xemu"
}

function install_xemu-pi5() {
    md_ret_files=(
        'dist/xemu'
    )
}

function configure_xemu-pi5() {
    mkRomDir "xbox"
    mkUserDir "$biosdir/xemu"

    # xemu keeps its config in the SDL pref path; keep it with the other
    # emulator configs and symlink it back.
    moveConfigDir "$home/.local/share/xemu" "$md_conf_root/xbox/xemu"

    local cfg="$md_conf_root/xbox/xemu/xemu/xemu.toml"
    if [[ ! -f "$cfg" ]]; then
        mkUserDir "$(dirname "$cfg")"
        cp "$md_data/xemu.toml" "$cfg"
        sed -i "s|@BIOSDIR@|$biosdir/xemu|g" "$cfg"
        chown "$__user":"$__group" "$cfg"
    fi

    install -m 0755 "$md_data/launcher.sh" "$md_inst/launcher.sh"
    sed -i "s|@BIN@|$md_inst/xemu|; s|@CFG@|$cfg|" "$md_inst/launcher.sh"

    addEmulator 1 "$md_id" "xbox" "$md_inst/launcher.sh %ROM%"
    addSystem "xbox" "Microsoft Xbox" ".iso .xiso"
}
