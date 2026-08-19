#!/usr/bin/env python3

# =============================================================================
# Imports
# =============================================================================

import os
import sys
from pathlib import Path

sys.path.append("/../../vunit/")

import vunit
from vunit import VUnit

# =============================================================================
# Paths
# =============================================================================

ROOT_PATH = Path(__file__).parent

SRC_PATH = ROOT_PATH / "../../vhdl"
IP_PATH  = ROOT_PATH / "../../vhdl/ram_up"
TB_PATH  = ROOT_PATH / "./tb_src"

ALTERA_LIB_PATH = "./vunit_out/modelsim/libraries/"

# =============================================================================
# VUnit Setup
# =============================================================================

VU = VUnit.from_argv()

VU.add_vhdl_builtins()
VU.add_osvvm()
VU.add_verification_components()

# =============================================================================
# Libraries
# =============================================================================

src_lib = VU.add_library("src_lib")

VU.add_external_library(
    "ram_up",
    ALTERA_LIB_PATH + "ram_up"
)

ram_2port_2000 = VU.add_external_library(
    "ram_2port_2000",
    ALTERA_LIB_PATH + "ram_2port_2000"
)

tb_src_lib = VU.add_library("tb_src_lib")

# =============================================================================
# Source Files
# =============================================================================

# Main design sources
src_lib.add_source_files(os.path.join(SRC_PATH, "*.vhd"))

# IP simulation models
src_lib.add_source_files(os.path.join(IP_PATH, "sim", "*.vhd"))

# External RAM model sources
ram_2port_2000.add_source_files(
    os.path.join(IP_PATH, "ram_2port_2000", "sim", "*.vhd")
)

# Testbench sources
tb_src_lib.add_source_files(os.path.join(TB_PATH, "*.vhd"))

# =============================================================================
# Testbench Configuration
# =============================================================================

tb = tb_src_lib.entity("t2mi_to_ts_top_tb")

# =============================================================================
# Run
# =============================================================================

VU.main()
