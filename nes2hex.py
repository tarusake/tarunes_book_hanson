#!/usr/bin/env python3

import os
import sys


def save_hex(data, filename):
    with open(filename, "w") as f:
        for value in data:
            f.write(f"{value:02X}\n")


if len(sys.argv) != 2:
    print("Usage: ./nes2hex.py <romfile.nes>")
    sys.exit(1)

rom_path = sys.argv[1]
base_name = os.path.splitext(os.path.basename(rom_path))[0]

with open(rom_path, "rb") as f:
    header = f.read(16)
    if header[:4] != b"NES\x1A":
        print("不正なNESファイルです")
        sys.exit(1)

    prg_size = header[4] * 16 * 1024
    chr_size = header[5] * 8 * 1024
    prg_data = f.read(prg_size)
    chr_data = f.read(chr_size)

# 16KiBのNROM-128は同じプログラムROM bankを2回配置する
if prg_size == 16 * 1024:
    prg_data = prg_data + prg_data

prg_out = f"{base_name}_prg.hex"
chr_out = f"{base_name}_chr.hex"

save_hex(prg_data, prg_out)
if chr_size > 0:
    save_hex(chr_data, chr_out)