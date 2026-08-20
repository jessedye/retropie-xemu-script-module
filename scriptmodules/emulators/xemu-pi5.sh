#!/usr/bin/env bash

# This file is part of the retropie-xemu-script-module project, an external
# scriptmodule for RetroPie-Setup. It is not part of the RetroPie or xemu
# projects.
#
# Installs a Raspberry Pi 5 optimised build of the xemu original-Xbox
# emulator: Vulkan swapchain presentation (no GL interop), x86-TSO via
# acquire/release accesses, native-double x87 helpers, and a renderer that
# keeps repeatedly rewritten vertex data out of the mirrored RAM buffer.
#
# Measured on gameplay, not menus: Morrowind median frame time 115 ms -> 57 ms
# and GTA San Andreas 42 ms -> 34 ms with half the stutters, against the same
# build with those renderer changes disabled.

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

    _theme_xemu-pi5
    _collection_art_xemu-pi5
}

function _collection_art_xemu-pi5() {
    # A custom collection is themed by its own name, so a collection called
    # "N64 HD" makes EmulationStation look for art/systems/N64 HD.svg. When
    # that is missing the fallback miscomputes the font size - a 128x
    # oversized glyph atlas - and ES dies at boot claiming gpu_split is too
    # low. It then restarts and dies again. Give every custom collection art
    # so that path is never taken.
    local settings="$configdir/all/emulationstation/es_settings.cfg"
    local theme name base src

    [[ -f "$settings" ]] || return 0

    local names
    names=$(sed -n 's|.*CollectionSystemsCustom" value="\([^"]*\)".*|\1|p' "$settings")
    [[ -n "$names" ]] || return 0

    for theme in "$configdir/all/emulationstation/themes"/* \
                 /etc/emulationstation/themes/*; do
        [[ -d "$theme/art/systems" ]] || continue
        local IFS=,
        for name in $names; do
            name="${name#"${name%%[![:space:]]*}"}"
            name="${name%"${name##*[![:space:]]}"}"
            [[ -n "$name" ]] || continue
            [[ -f "$theme/art/systems/$name.svg" ]] && continue

            # Prefer the art of the system the collection is built from, so
            # "N64 HD" borrows n64.svg; otherwise fall back to the all-games
            # icon that every carbon derivative ships.
            base=$(echo "${name%% *}" | tr '[:upper:]' '[:lower:]')
            for src in "$theme/art/systems/$base.svg" \
                       "$theme/art/systems/auto-allgames.svg"; do
                [[ -f "$src" ]] && cp -f "$src" "$theme/art/systems/$name.svg" && break
            done
            for src in "$theme/art/controllers/$base.svg" \
                       "$theme/art/controllers/auto-allgames.svg"; do
                [[ -d "$theme/art/controllers" ]] || break
                [[ -f "$src" ]] && cp -f "$src" "$theme/art/controllers/$name.svg" && break
            done
        done
        unset IFS
    done
}

function _theme_xemu-pi5() {
    # Carbon ships no xbox artwork, so EmulationStation falls back to plain
    # text in the default red. Install a logo, a controller and a green accent
    # for every installed theme that has the same layout.
    local theme
    local src="$md_data/theme"

    [[ -d "$src" ]] || return 0

    for theme in "$configdir/all/emulationstation/themes"/* \
                 /etc/emulationstation/themes/*; do
        [[ -d "$theme/art/systems" ]] || continue
        cp -f "$src/xbox-logo.svg" "$theme/art/systems/xbox.svg"
        [[ -d "$theme/art/controllers" ]] &&
            cp -f "$src/xbox-controller.svg" "$theme/art/controllers/xbox.svg"
        mkdir -p "$theme/xbox"
        cp -f "$src/theme.xml" "$theme/xbox/theme.xml"
    done
}
