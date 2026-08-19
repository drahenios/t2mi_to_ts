-- =============================================================================
-- DVB-T2 MI BBFRAME Extractor and TS Rebuilder (Top-Level)
--
-- Author : Xabier Legaspi Juanatey
-- Date   : 2026-06-04
--
-- This top-level module connects a Transport Stream (TS) parser with a
-- T2-MI parser to extract and decode DVB-T2 Modulator Interface (T2-MI) packets.
--
-- Functionality:
--   - Accepts an MPEG-TS input stream with a selected PID.
--   - Invokes the TS parser to extract packets matching the target PID.
--   - Forwards valid payload bytes to the T2-MI parser.
--   - Handles skip and error signals from the T2-MI parser.
--   - Produces a unit packet (TSUP) stream suitable for further processing.
--
-- Features:
--   - Transport stream synchronization and PID filtering via TS parser
--   - Continuity counter validation and adaptation field handling
--   - T2-MI payload extraction and pointer field processing
--   - Error reporting and flow control between TS parser and T2-MI parser
--
-- Interfaces:
--   - Input: MPEG-TS signals (clk, sync, valid, data, target PID)
--   - Output: Unit packet stream (TSUP) signals
--   - Internal: Control/status handshake with T2-MI parser (run, error, skip)
--
-- Notes:
--   - This module does not modify the TS payload, only extracts T2-MI packets.
--   - Designed for use in FPGA/HDL environments with synchronous TS input.
-- =============================================================================


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity t2mi_to_ts_top is
    port (
        clk_i                       : in  std_logic;
        rst_i                       : in  std_logic;

        -- Input transport stream interface
        ts_clk_i                    : in  std_logic;
        ts_sync_i                   : in  std_logic;
        ts_valid_i                  : in  std_logic;
        ts_data_i                   : in  std_logic_vector(7 downto 0);
        ts_target_pid_i             : in  std_logic_vector(12 downto 0);
        ts_target_pid_received_i    : in  std_logic;

        -- Output unit packet stream interface
        tsup_clk_o                  : out std_logic;
        tsup_sync_o                 : out std_logic;
        tsup_valid_o                : out std_logic;
        tsup_data_o                 : out std_logic_vector(7 downto 0)
    );
end entity;

architecture rtl of t2mi_to_ts_top is

    -----------------------------------------------------------------------------
    -- Inter-Module Signals
    -----------------------------------------------------------------------------
    -- Connect TS parser and T2-MI parser.
    signal s_t2mi_run             : std_logic := '0';
    signal s_t2mi_send_error      : std_logic := '0';

    -- Return status from the T2-MI parser.
    signal s_t2mi_receive_skip    : std_logic := '0';
    signal s_t2mi_receive_error   : std_logic := '0';

begin

    -----------------------------------------------------------------------------
    -- TS Parser Instance
    -----------------------------------------------------------------------------
    -- Extract packets matching the selected PID.
    ts_parser_inst : entity work.ts_parser
        port map (
            clk_i                     => clk_i,
            rst_i                     => rst_i,

            -- Input transport stream interface
            ts_clk_i                  => ts_clk_i,
            ts_sync_i                 => ts_sync_i,
            ts_valid_i                => ts_valid_i,
            ts_data_i                 => ts_data_i,
            ts_target_pid_i           => ts_target_pid_i,
            ts_target_pid_received_i  => ts_target_pid_received_i,

            -- Status from T2-MI parser
            t2mi_receive_skip_i       => s_t2mi_receive_skip,
            t2mi_receive_error_i      => s_t2mi_receive_error,

            -- Control toward T2-MI parser
            t2mi_run_o                => s_t2mi_run,
            t2mi_send_error_o         => s_t2mi_send_error
        );

    -----------------------------------------------------------------------------
    -- T2-MI Parser Instance
    -----------------------------------------------------------------------------
    -- Decode T2-MI packets into unit packet output.
    t2mi_parser_inst : entity work.t2mi_parser
        port map (
            clk_i                    => clk_i,
            rst_i                    => rst_i,

            -- Input transport stream data
            ts_valid_i               => ts_valid_i,
            ts_clk_i                 => ts_clk_i,
            ts_data_i                => ts_data_i,

            -- Control from TS parser
            tsp_run_i                => s_t2mi_run,
            tsp_receive_error_i      => s_t2mi_send_error,

            -- Status toward TS parser
            tsp_send_skip_o          => s_t2mi_receive_skip,
            tsp_send_error_o         => s_t2mi_receive_error,

            -- Output unit packet stream
            tsup_clk_o               => tsup_clk_o,
            tsup_sync_o              => tsup_sync_o,
            tsup_valid_o             => tsup_valid_o,
            tsup_data_o              => tsup_data_o
        );

end architecture;