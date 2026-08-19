-- =============================================================================
-- DVB-T2 MI BBFRAME Extractor and TS Rebuilder (T2-MI Parser)
--
-- Author : Xabier Legaspi Juanatey
-- Date   : 2026-06-04
--
-- This module decodes DVB-T2 Modulator Interface (T2-MI) BBFRAME packets
-- received from the TS parser. It validates T2-MI header fields, extracts
-- User Packet (UP) payload data, removes BBFRAME overhead, and rebuilds a
-- continuous Transport Stream Unit Packet (TSUP) output stream.
--
-- Features:
--   - T2-MI header parsing and validation
--   - CRC-8 verification of protected header fields
--   - PLP, MATYPE, ISSYI, and NPD field checking
--   - SYNCD offset and BB padding removal
--   - User Packet payload extraction
--   - Internal RAM buffering of recovered payload data
--   - TS packet reconstruction and null packet insertion
--   - Error and skip signaling toward the TS parser
--
-- Interfaces:
--   - Input: T2-MI payload stream and TS parser control signals
--   - Output: TSUP stream (clock, sync, valid, data)
--   - Status: Skip and error indications to TS parser
--
-- State Machines:
--   - Decoder FSM: Header parsing, payload extraction, padding removal,
--                  CRC field handling, and error recovery
--   - Output FSM : TS packet generation, RAM read control, and null packet
--                  insertion
--
-- Notes:
--   - Designed for DVB-T2 BBFRAME packets carried in T2-MI streams.
--   - Uses internal buffering to decouple input and output packet rates.
--   - CRC-32 trailer bytes are skipped but not validated.
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity t2mi_parser is
    port (
        clk_i                    : in  std_logic;
        rst_i                    : in  std_logic;

        -----------------------------------------------------------------------------
        -- Input: Transport Stream interface
        -- Receives raw TS packets from upstream TS parser / demodulator chain
        -----------------------------------------------------------------------------
        ts_valid_i               : in  std_logic;
        ts_clk_i                 : in  std_logic;
        ts_data_i                : in  std_logic_vector(7 downto 0);

        -----------------------------------------------------------------------------
        -- Input: Control from TS parser
        -- Defines execution permission and error propagation context
        -----------------------------------------------------------------------------
        tsp_run_i                : in std_logic;
        tsp_receive_error_i      : in std_logic;

        -- (Reserved input: future timing alignment / rate control interface)
        -- ts_clk_rate_out_i     : in  std_logic;

        -----------------------------------------------------------------------------
        -- Output: Status toward TS parser
        -- Used to indicate skip or error conditions during T2-MI decoding
        -----------------------------------------------------------------------------
        tsp_send_skip_o          : out std_logic := '0';
        tsp_send_error_o         : out std_logic := '0';

        -----------------------------------------------------------------------------
        -- Output: Unit Packet Stream interface
        -- Decoded T2-MI payload converted into byte-aligned stream
        -----------------------------------------------------------------------------
        tsup_clk_o               : out std_logic;
        tsup_sync_o              : out std_logic;
        tsup_valid_o             : out std_logic;
        tsup_data_o              : out std_logic_vector(7 downto 0)
    );
end entity;


architecture rtl of t2mi_parser is

    -----------------------------------------------------------------------------
    -- T2-MI Header constants
    -- Define fixed protocol fields and decoding parameters for DVB-T2 T2-MI frames
    -----------------------------------------------------------------------------
    constant C_PACKET_TYPE          : std_logic_vector(7 downto 0)  := x"00";
    constant C_MIN_PAYLOAD_LEN_BITS : unsigned(15 downto 0)         := to_unsigned(104, 16); 
    -- Includes: T2-MI header (24 bits) + BBHEADER (80 bits)

    constant C_PLP_ID               : std_logic_vector(7 downto 0)  := x"00";
    constant C_TS_GS                : std_logic_vector(1 downto 0)  := "11";
    constant C_ISSYI                : std_logic                     := '0';
    constant C_NPD                  : std_logic                     := '0';

    constant C_MODE                 : std_logic_vector(7 downto 0)  := x"01"; 
    -- High efficiency transmission mode

    constant C_CRC8_POLY            : std_logic_vector(7 downto 0)  := x"D5"; 
    -- DVB-T2 CRC-8 polynomial

    -----------------------------------------------------------------------------
    -- Header field index map
    -- Bit-level mapping of parsed T2-MI header fields
    -----------------------------------------------------------------------------
    constant HDR_PACKET_TYPE    : integer := 18;
    constant HDR_PAYLOAD_LEN_H  : integer := 14;
    constant HDR_PAYLOAD_LEN_L  : integer := 13;
    constant HDR_PLP_ID         : integer := 11;
    constant HDR_MATYPE1        : integer := 9;
    constant HDR_MATYPE2        : integer := 8;
    constant HDR_ISSY_2MSB_H    : integer := 7;
    constant HDR_ISSY_2MSB_L    : integer := 6;
    constant HDR_DFL_H          : integer := 5;
    constant HDR_DFL_L          : integer := 4;
    constant HDR_ISSY_1LSB      : integer := 3;
    constant HDR_SYNCD_H        : integer := 2;
    constant HDR_SYNCD_L        : integer := 1;
    constant HDR_CRC8_MODE      : integer := 0;

    -----------------------------------------------------------------------------
    -- FSM: T2-MI parsing states
    -- Controls decoding pipeline from header parsing to output packet generation
    -----------------------------------------------------------------------------
    type t_state is (
        HDR,               -- Header decoding phase
        SYNCD_SKIP,        -- Skip synchronization padding
        UP,                -- Unit packet processing
        BBPADDING,         -- Baseband padding removal
        CRC32,             -- CRC validation phase
        TSP_RECEIVE_ERROR, -- Error propagation from TS parser
        TSP_SEND_SKIP,     -- Notify upstream skip condition
        TSP_SEND_ERROR     -- Notify upstream error condition
    );

    signal s_state                  : t_state                         := HDR;
    signal s_init                   : std_logic                       := '1';

    -----------------------------------------------------------------------------
    -- Header parsing and payload tracking
    -----------------------------------------------------------------------------
    signal s_hdr_index              : integer range 0 to 18           := HDR_PACKET_TYPE;
    signal s_byte                   : std_logic_vector(7 downto 0)    := (others => '0');

    signal s_cnt_payload_len_bytes  : unsigned(12 downto 0)           := to_unsigned(0, 13);
    signal s_cnt_dfl_bytes          : unsigned(12 downto 0)           := to_unsigned(0, 13);
    signal s_cnt_syncd_bytes        : unsigned(12 downto 0)           := to_unsigned(0, 13);

    signal s_crc8                   : std_logic_vector(7 downto 0)    := (others => '0');

    signal s_cnt_bbpadding_bytes    : unsigned(12 downto 0)           := to_unsigned(0, 13);
    signal s_cnt_crc32_bytes        : unsigned(1 downto 0)            := to_unsigned(3, 2);

    -----------------------------------------------------------------------------
    -- Transport stream pipeline registers
    -- Align incoming TS signals across clock domain stages
    -----------------------------------------------------------------------------
    signal s_ts_clk_reg1      : std_logic := '0';
    signal s_ts_clk_reg2      : std_logic := '0';
    signal s_ts_valid_reg1    : std_logic := '0';
    signal s_ts_data_reg1     : std_logic_vector(7 downto 0)    := (others => '0');

    -----------------------------------------------------------------------------
    -- TS parser interface pipeline
    -----------------------------------------------------------------------------
    signal s_tsp_run_reg1      : std_logic := '0';

    -----------------------------------------------------------------------------
    -- CRC-8 (DVB-T2) function
    -- Computes incremental CRC over incoming byte stream
    -----------------------------------------------------------------------------
    function crc8_update (
        crc_in : std_logic_vector(7 downto 0); 
        data   : std_logic_vector(7 downto 0)
    )   return std_logic_vector is
        variable crc_var  : std_logic_vector(7 downto 0) := crc_in xor data;
    begin
        for i in 0 to 7 loop
            if crc_var(7) = '1' then
                crc_var := (crc_var(6 downto 0) & '0') xor C_CRC8_POLY;
            else
                crc_var := (crc_var(6 downto 0) & '0');
            end if;
        end loop;
        return crc_var;
    end function;

    -----------------------------------------------------------------------------
    -- RAM interface component (packet buffering memory)
    -- Stores multiple TS packets for reordering / null-packet insertion
    -----------------------------------------------------------------------------
    component ram_up is
        port (
            data      : in  std_logic_vector(7 downto 0) := (others => '0'); -- input data
            q         : out std_logic_vector(7 downto 0);                    -- output data

            wraddress : in  std_logic_vector(9 downto 0) := (others => '0'); -- write address
            rdaddress : in  std_logic_vector(9 downto 0) := (others => '0'); -- read address

            wren      : in  std_logic                    := '0';             -- write enable
            wrclock   : in  std_logic                    := '0';             -- write clock
            rdclock   : in  std_logic                    := '0';             -- read clock
            rden      : in  std_logic                    := '0'              -- read enable
        );
    end component ram_up;

    -----------------------------------------------------------------------------
    -- RAM configuration
    -- Defines total buffer capacity (187-byte TS packet × 5)
    -----------------------------------------------------------------------------
    constant C_MAX_RAM_SPACE        : unsigned(9 downto 0) := to_unsigned(935,10);

    -----------------------------------------------------------------------------
    -- RAM pipeline signals
    -- Handle buffered TS storage and retrieval operations
    -----------------------------------------------------------------------------
    signal s_ram_data      : std_logic_vector(7 downto 0)  := (others => '0');
    signal s_ram_q         : std_logic_vector(7 downto 0);

    signal s_ram_wraddress : std_logic_vector(9 downto 0)  := (others => '0');
    signal s_ram_rdaddress : std_logic_vector(9 downto 0)  := (others => '0');

    signal s_ram_wren      : std_logic                     := '0';
    signal s_ram_wrclock   : std_logic                     := '0';
    signal s_ram_rdclock   : std_logic                     := '0';
    signal s_ram_rden      : std_logic                     := '0';

    -----------------------------------------------------------------------------
    -- RAM read FSM
    -- Controls packet reconstruction and null-packet insertion
    -----------------------------------------------------------------------------
    type t_state_ram_rd is (
        SYNC,
        RD_PCK,
        NULL_PCK_PID_H,
        NULL_PCK_PID_L,
        NULL_PCK_CC_AFC,
        NULL_PCK_PAYLOAD
    );

    signal s_flag_ram_space_inc      : std_logic                    := '0';
    signal s_flag_ram_space_dec      : std_logic                    := '0';
    signal s_cnt_ram_space           : unsigned(9 downto 0)         := C_MAX_RAM_SPACE;

    -- Write-side packet counter (TS packet size tracking)
    signal s_cnt_wr_pck              : unsigned(7 downto 0)         := to_unsigned(186,8);

    -- Read-side FSM state
    signal s_state_ram_rd            : t_state_ram_rd               := SYNC;

    signal s_cnt_rd_pck              : unsigned(7 downto 0)         := to_unsigned(186,8);
    signal s_cnt_null_pck_payload    : unsigned(7 downto 0)         := to_unsigned(183,8);

    -----------------------------------------------------------------------------
    -- Clock rate alignment signals (future timing adaptation interface)
    -----------------------------------------------------------------------------
    signal ts_clk_rate_out_i         :  std_logic                    := '0';
    signal ts_clk_rate_out_reg_1     :  std_logic                    := '0';
    signal ts_clk_rate_out_reg_2     :  std_logic                    := '0'; 

    signal s_ram_wraddress_upl       :  std_logic_vector(9 downto 0) := (others => '0');

begin

    -----------------------------------------------------------------------------
    -- Directly forward TS clock to rate output
    -----------------------------------------------------------------------------
    ts_clk_rate_out_i <= ts_clk_i;

    -----------------------------------------------------------------------------
    -- Instantiate RAM for User Packets (UP)
    -----------------------------------------------------------------------------
    u0 : component ram_up
        port map (
            data      => s_ram_data,      -- input data to RAM
            q         => s_ram_q,         -- output data from RAM
            wraddress => s_ram_wraddress, -- write address
            rdaddress => s_ram_rdaddress, -- read address
            wren      => s_ram_wren,      -- write enable
            wrclock   => clk_i,           -- write clock
            rdclock   => clk_i,           -- read clock
            rden      => s_ram_rden       -- read enable
        );

    -----------------------------------------------------------------------------
    -- Main state machine process
    -- Handles T2-MI header parsing, UP storage, BB padding, CRC, and errors
    -----------------------------------------------------------------------------
    process(clk_i, rst_i)
    begin
        if (rst_i = '1') then
            -----------------------------------------------------------------------------
            -- Reset all state, counters, and outputs
            -----------------------------------------------------------------------------
            s_state                 <= HDR;
            s_init                  <= '1';
            s_hdr_index             <= HDR_PACKET_TYPE;
            s_byte                  <= (others => '0');
            s_cnt_payload_len_bytes <= to_unsigned(0, 13);
            s_cnt_dfl_bytes         <= to_unsigned(0, 13);
            s_cnt_syncd_bytes       <= to_unsigned(0, 13);
            s_crc8                  <= (others => '0');
            s_cnt_bbpadding_bytes   <= to_unsigned(0, 13);
            s_cnt_crc32_bytes       <= to_unsigned(3, 2);

            -- reset outputs
            tsp_send_skip_o   <= '0';
            tsp_send_error_o  <= '0';

            -- reset RAM control signals
            s_ram_wren        <= '0';
            s_ram_data        <= (others => '0');
            s_ram_wraddress   <= std_logic_vector(C_MAX_RAM_SPACE - 1);
            s_ram_wraddress_upl <= std_logic_vector(C_MAX_RAM_SPACE - 1);
            s_flag_ram_space_dec    <= '0';
            s_cnt_wr_pck            <= to_unsigned(186,8);

            -- reset TS pipeline registers
            s_ts_clk_reg1   <= '0';
            s_ts_clk_reg2   <= '0';
            s_ts_valid_reg1 <= '0';
            s_ts_data_reg1  <= (others => '0');

        elsif rising_edge(clk_i) then
            -----------------------------------------------------------------------------
            -- Pipeline TS and TS parser inputs
            -----------------------------------------------------------------------------
            s_ts_clk_reg1   <= ts_clk_i;
            s_ts_clk_reg2   <= s_ts_clk_reg1;
            s_ts_valid_reg1 <= ts_valid_i;
            s_ts_data_reg1  <= ts_data_i;

            s_tsp_run_reg1  <= tsp_run_i;

            -----------------------------------------------------------------------------
            -- Check for TS parser receive error
            -----------------------------------------------------------------------------
            if (tsp_receive_error_i = '1') then
                s_state <= TSP_RECEIVE_ERROR;

            else
                -----------------------------------------------------------------------------
                -- Main state machine logic
                -----------------------------------------------------------------------------
                case s_state is

                    -----------------------------------------------------------------------------
                    when HDR =>
                        -- Process header bytes only when TS valid & clock edge detected
                        if (s_ts_clk_reg1   = '1'   and
                            s_ts_clk_reg2   = '0'   and
                            s_ts_valid_reg1 = '1'   and
                            s_tsp_run_reg1  = '1') then

                            case s_hdr_index is
                                when HDR_PACKET_TYPE =>
                                    -- Validate packet type
                                    if (s_ts_data_reg1 /= C_PACKET_TYPE) then
                                        s_state         <= TSP_SEND_SKIP;
                                        s_hdr_index     <= HDR_PACKET_TYPE;
                                        tsp_send_skip_o <= '1';
                                    else
                                        s_state         <= HDR;
                                        s_hdr_index     <= s_hdr_index - 1;
                                        tsp_send_skip_o <= '0';
                                    end if;

                                when HDR_PAYLOAD_LEN_H =>
                                    -- Store high byte of payload length
                                    s_state     <= HDR;
                                    s_hdr_index <= HDR_PAYLOAD_LEN_L;
                                    s_byte      <= s_ts_data_reg1;

                                when HDR_PAYLOAD_LEN_L =>
                                    -- Store low byte and check minimum payload length
                                    if (unsigned(s_byte & s_ts_data_reg1) <= C_MIN_PAYLOAD_LEN_BITS) then
                                        s_state     <= TSP_SEND_ERROR;
                                        s_hdr_index <= HDR_PACKET_TYPE;
                                        tsp_send_error_o  <= '1';
                                    else
                                        s_state     <= HDR;
                                        s_hdr_index <= s_hdr_index - 1;
                                        s_cnt_payload_len_bytes <= unsigned(s_byte & s_ts_data_reg1(7 downto 3));
                                        tsp_send_error_o  <= '0';
                                    end if;

                                when HDR_PLP_ID =>
                                    -- Validate PLP ID
                                    if (s_ts_data_reg1 /= C_PLP_ID) then
                                        s_state     <= TSP_SEND_ERROR;
                                        s_hdr_index <= HDR_PACKET_TYPE;
                                        tsp_send_error_o  <= '1';
                                    else
                                        s_state     <= HDR;
                                        s_hdr_index <= s_hdr_index - 1;
                                        tsp_send_error_o  <= '0';
                                    end if;

                                when HDR_MATYPE1 =>
                                    -- Check GS, ISSYI, NPD bits
                                    if ((s_ts_data_reg1(7 downto 6) /= C_TS_GS) or
                                        (s_ts_data_reg1(3) /= C_ISSYI) or
                                        (s_ts_data_reg1(2) /= C_NPD)) then
                                        s_state     <= TSP_SEND_ERROR;
                                        s_hdr_index <= HDR_PACKET_TYPE;
                                        tsp_send_error_o  <= '1';
                                    else
                                        s_state     <= HDR;
                                        s_hdr_index <= HDR_MATYPE2;
                                        s_crc8      <= crc8_update(s_crc8, s_ts_data_reg1);
                                        tsp_send_error_o  <= '0';
                                    end if;

                                when HDR_MATYPE2 | HDR_ISSY_2MSB_H | HDR_ISSY_2MSB_L | HDR_DFL_H | HDR_DFL_L | HDR_ISSY_1LSB | HDR_SYNCD_H | HDR_SYNCD_L =>
                                    -- Update CRC8 and manage byte-to-counter conversions
                                    s_crc8      <= crc8_update(s_crc8, s_ts_data_reg1);
                                    -- handle counter updates where appropriate
                                    if s_hdr_index = HDR_DFL_H then
                                        s_byte <= s_ts_data_reg1;
                                    elsif s_hdr_index = HDR_DFL_L then
                                        s_cnt_dfl_bytes <= unsigned(s_byte & s_ts_data_reg1(7 downto 3));
                                    elsif s_hdr_index = HDR_SYNCD_H then
                                        s_byte <= s_ts_data_reg1;
                                    elsif s_hdr_index = HDR_SYNCD_L then
                                        s_cnt_syncd_bytes <= unsigned(s_byte & s_ts_data_reg1(7 downto 3));
                                    elsif s_hdr_index = HDR_ISSY_1LSB then
                                        s_cnt_bbpadding_bytes <= s_cnt_payload_len_bytes - s_cnt_dfl_bytes - 3 - 10;
                                    end if;
                                    s_hdr_index <= s_hdr_index - 1;

                                when HDR_CRC8_MODE =>
                                    -- Verify CRC8 and decide next state
                                    s_crc8 <= (others => '0');
                                    if s_ts_data_reg1 /= (s_crc8 xor C_MODE) then
                                        s_state <= TSP_SEND_ERROR;
                                        tsp_send_error_o  <= '1';
                                    else
                                        -- Determine next processing state based on syncd and DFL bytes
                                        if (s_cnt_syncd_bytes = 0 and s_cnt_dfl_bytes = 0) then
                                            s_state <= CRC32;
                                            tsp_send_error_o <= '0';
                                        elsif (s_cnt_syncd_bytes = 0 and s_cnt_dfl_bytes > 0) then
                                            s_state <= UP;
                                            tsp_send_error_o <= '0';
                                        elsif (s_cnt_syncd_bytes > 0 and s_cnt_dfl_bytes = 0) then
                                            s_state <= TSP_SEND_ERROR;
                                            tsp_send_error_o <= '1';
                                        elsif (s_cnt_syncd_bytes > 0 and s_cnt_dfl_bytes > 0) then
                                            s_state <= SYNCD_SKIP;
                                            tsp_send_error_o <= '0';
                                        else
                                            s_state <= TSP_SEND_ERROR;
                                            tsp_send_error_o <= '1';
                                        end if;
                                    end if;

                                when others =>
                                    s_hdr_index <= s_hdr_index - 1;
                            end case;
                        end if;

                    -----------------------------------------------------------------------------
                    when SYNCD_SKIP =>
                        s_ram_wren              <= '0';
                        s_flag_ram_space_dec    <= '0';
                        if (s_ts_clk_reg1 = '1' and
                            s_ts_clk_reg2 = '0' and
                            s_ts_valid_reg1 = '1' and
                            s_tsp_run_reg1 = '1') then

                            if (s_cnt_syncd_bytes = 1 and s_cnt_dfl_bytes = 1 and s_init = '0') then
                                s_state         <= CRC32;
                                s_ram_wren      <= '1';
                                s_ram_data      <= s_ts_data_reg1;
                                if unsigned(s_ram_wraddress) = C_MAX_RAM_SPACE - 1 then
                                    s_ram_wraddress <= (others => '0');
                                else
                                    s_ram_wraddress <= std_logic_vector(unsigned(s_ram_wraddress) + 1);
                                end if;
                                -- Crear funcion
                                if (s_cnt_wr_pck  = 0) then
                                    s_cnt_wr_pck    <= to_unsigned(186, 8);
                                    s_flag_ram_space_dec <= '1';
                                else
                                    s_cnt_wr_pck    <= s_cnt_wr_pck - 1;
                                end if;
                            elsif (s_cnt_syncd_bytes = 1 and s_cnt_dfl_bytes = 1 and s_init = '1') then
                                s_state <= CRC32;
                                s_init  <= '0';                             
                            elsif (s_cnt_syncd_bytes = 1 and s_cnt_dfl_bytes > 1 and s_init = '0') then
                                s_state         <= UP;
                                s_ram_wren      <= '1';
                                s_ram_data      <= s_ts_data_reg1;
                                if unsigned(s_ram_wraddress) = C_MAX_RAM_SPACE - 1 then
                                    s_ram_wraddress <= (others => '0');
                                else
                                    s_ram_wraddress <= std_logic_vector(unsigned(s_ram_wraddress) + 1);
                                end if;
                                if (s_cnt_wr_pck  = 0) then
                                    s_cnt_wr_pck    <= to_unsigned(186, 8);
                                    s_flag_ram_space_dec <= '1';
                                else
                                    s_cnt_wr_pck    <= s_cnt_wr_pck - 1;
                                end if;
                            elsif (s_cnt_syncd_bytes = 1 and s_cnt_dfl_bytes > 1 and s_init = '1') then
                                s_state <= UP;
                                s_init  <= '0';
                            elsif (s_cnt_syncd_bytes > 1 and s_cnt_dfl_bytes > 1 and s_init = '0') then
                                s_state         <= SYNCD_SKIP;
                                s_ram_wren      <= '1';
                                s_ram_data      <= s_ts_data_reg1;
                                if unsigned(s_ram_wraddress) = C_MAX_RAM_SPACE - 1 then
                                    s_ram_wraddress <= (others => '0');
                                else
                                    s_ram_wraddress <= std_logic_vector(unsigned(s_ram_wraddress) + 1);
                                end if;
                                if (s_cnt_wr_pck = 0) then
                                    s_cnt_wr_pck    <= to_unsigned(186, 8);
                                    s_flag_ram_space_dec <= '1';
                                else
                                    s_cnt_wr_pck    <= s_cnt_wr_pck - 1;
                                end if;
                            elsif (s_cnt_syncd_bytes > 1 and s_cnt_dfl_bytes > 1 and s_init = '1') then
                                s_state <= SYNCD_SKIP;
                            else
                                s_state <= TSP_SEND_ERROR;
                                tsp_send_error_o  <= '1';
                            end if;

                            s_cnt_syncd_bytes <= s_cnt_syncd_bytes - 1;
                            s_cnt_dfl_bytes   <= s_cnt_dfl_bytes   - 1;

                        end if;

                    -----------------------------------------------------------------------------
                    when UP =>
                        -----------------------------------------------------------------------------
                        -- UP (User Packet) state
                        -- Stores decoded payload bytes into RAM buffer
                        -- Handles packet boundary detection and transition
                        -----------------------------------------------------------------------------
                        s_ram_wren           <= '0';
                        s_ram_data           <= (others => '0');
                        s_flag_ram_space_dec <= '0';
                        if (s_ts_clk_reg1   = '1'     and
                            s_ts_clk_reg2   = '0'     and
                            s_ts_valid_reg1 = '1'     and
                            s_tsp_run_reg1  = '1')    then
                            
                             -----------------------------------------------------------------------------
                            -- End of DFL region handling
                            -- Decide next state: CRC32 or BBPADDING
                            -----------------------------------------------------------------------------
                            if (s_cnt_dfl_bytes = 1) then
                                if (s_cnt_bbpadding_bytes = 0) then 
                                    s_state <= CRC32;
                                else
                                    s_state <= BBPADDING;
                                end if;
                                tsp_send_error_o  <= '0';
                            elsif (s_cnt_dfl_bytes > 1) then
                                s_state <= UP;
                                tsp_send_error_o  <= '0';
                            else
                                s_state           <= TSP_SEND_ERROR;
                                tsp_send_error_o  <= '1';
                            end if;
                            s_cnt_dfl_bytes     <= s_cnt_dfl_bytes - 1;

                            -----------------------------------------------------------------------------
                            -- Write current byte into RAM buffer
                            -----------------------------------------------------------------------------
                            s_ram_wren          <= '1';
                            s_ram_data          <= s_ts_data_reg1;
                            if unsigned(s_ram_wraddress) = C_MAX_RAM_SPACE - 1 then
                                s_ram_wraddress <= (others => '0');
                            else
                                s_ram_wraddress <= std_logic_vector(unsigned(s_ram_wraddress) + 1);
                            end if;
                            if (s_cnt_wr_pck  = 0) then
                                s_cnt_wr_pck         <= to_unsigned(186, 8);
                                s_flag_ram_space_dec <= '1';
                                s_ram_wraddress_upl <= std_logic_vector(unsigned(s_ram_wraddress) + 1);
                            else
                                s_cnt_wr_pck         <= s_cnt_wr_pck - 1;
                            end if;

                        end if;
                    
                    when BBPADDING =>
                        -----------------------------------------------------------------------------
                        -- BBPADDING state
                        -- Skips BaseBand padding bytes after payload section
                        -----------------------------------------------------------------------------
                        s_ram_wren              <= '0';
                        s_ram_data              <= (others => '0');
                        s_flag_ram_space_dec    <= '0';
                        if (s_ts_clk_reg1 = '1' and
                            s_ts_clk_reg2 = '0' and
                            s_ts_valid_reg1 = '1' and
                            s_tsp_run_reg1 = '1') then
                            
                            if (s_cnt_bbpadding_bytes = 1) then 
                                s_state <= CRC32;
                            else
                                s_state <= BBPADDING;
                                s_cnt_bbpadding_bytes <=  s_cnt_bbpadding_bytes - 1;
                            end if;
                            
                    end if;

                    -----------------------------------------------------------------------------
                    when CRC32 =>
                        -----------------------------------------------------------------------------
                        -- CRC32 state
                        -- Final packet integrity phase before returning to HDR
                        -- Consumes CRC bytes and resets packet parsing cycle
                        -----------------------------------------------------------------------------
                        s_ram_wren              <= '0';
                        s_ram_data              <= (others => '0');
                        s_flag_ram_space_dec    <= '0';
                        if (s_ts_clk_reg1 = '1' and
                            s_ts_clk_reg2 = '0' and
                            s_ts_valid_reg1 = '1' and
                            s_tsp_run_reg1 = '1') then

                            if (s_cnt_crc32_bytes = 0) then
                                s_state     <= HDR;
                                s_hdr_index <= HDR_PACKET_TYPE;
                                tsp_send_error_o  <= '0';
                            elsif (s_cnt_crc32_bytes > 0) then
                                s_state <= CRC32;
                                tsp_send_error_o  <= '0';
                            else
                                s_state <= TSP_SEND_ERROR;
                                tsp_send_error_o  <= '1';
                            end if;

                            if (s_cnt_crc32_bytes = 0) then
                                s_cnt_crc32_bytes <= to_unsigned(3,2);
                            else
                                s_cnt_crc32_bytes <= s_cnt_crc32_bytes - 1;
                            end if;
                        end if;
                   -----------------------------------------------------------------------------
                    when TSP_RECEIVE_ERROR | TSP_SEND_ERROR =>
                        -----------------------------------------------------------------------------
                        -- Error recovery state
                        -- Resets parser to initial HDR state on reception or send error
                        -- Clears all counters, CRC, and outputs to ensure deterministic restart
                        -----------------------------------------------------------------------------
                        s_state                 <= HDR;
                        s_init                  <= '1';
                        s_hdr_index             <= HDR_PACKET_TYPE;
                        s_byte                  <= (others => '0');
                        s_cnt_payload_len_bytes <= to_unsigned(0, 13);
                        s_cnt_dfl_bytes         <= to_unsigned(0, 13);
                        s_cnt_syncd_bytes       <= to_unsigned(0, 13);
                        s_crc8                  <= (others => '0');
                        s_cnt_bbpadding_bytes   <= to_unsigned(0, 13);
                        s_cnt_crc32_bytes       <= to_unsigned(3, 2);

                        -----------------------------------------------------------------------------
                        -- Reset outputs
                        -- Clears skip/error flags and RAM write interface
                        -----------------------------------------------------------------------------
                        tsp_send_skip_o   <= '0';
                        tsp_send_error_o  <= '0';

                        s_ram_wren        <= '0';
                        s_ram_data        <= (others => '0');
                        s_ram_wraddress   <= s_ram_wraddress_upl;
                        s_cnt_wr_pck      <= to_unsigned(186, 8);

                        -----------------------------------------------------------------------------
                        -- RAM space tracker
                        -- Ensure no unintended decrements during error recovery
                        -----------------------------------------------------------------------------
                        s_flag_ram_space_dec <= '0';
                    -----------------------------------------------------------------------------
                    when TSP_SEND_SKIP  =>
                        -----------------------------------------------------------------------------
                        -- Skip send state
                        -- Resets parser state after intentionally skipping a packet
                        -- Counters and outputs restored to initial HDR state
                        -----------------------------------------------------------------------------
                        s_state                 <= HDR;
                        s_hdr_index             <= HDR_PACKET_TYPE;
                        s_byte                  <= (others => '0');
                        s_cnt_payload_len_bytes <= to_unsigned(0, 13);
                        s_cnt_dfl_bytes         <= to_unsigned(0, 13);
                        s_cnt_syncd_bytes       <= to_unsigned(0, 13);
                        s_crc8                  <= (others => '0');
                        s_cnt_bbpadding_bytes   <= to_unsigned(0, 13);
                        s_cnt_crc32_bytes       <= to_unsigned(3, 2);

                        -----------------------------------------------------------------------------
                        -- Reset outputs
                        -- Clears skip/error flags before next HDR processing
                        -----------------------------------------------------------------------------
                        tsp_send_skip_o   <= '0';
                        tsp_send_error_o  <= '0';                                   

                end case;
            end if;
        end if;
    end process;

    process(clk_i, rst_i)
begin
    if (rst_i = '1') then

        -----------------------------------------------------------------------------
        -- Reset: RAM read controller and output stream interface
        -- Restores deterministic start state for TS regeneration
        -----------------------------------------------------------------------------
        s_ram_rdaddress         <= std_logic_vector(C_MAX_RAM_SPACE - 1);
        s_ram_rden              <= '0';

        -----------------------------------------------------------------------------
        -- Reset RAM read FSM and counters
        -----------------------------------------------------------------------------
        s_state_ram_rd          <= SYNC;
        s_cnt_rd_pck            <= to_unsigned(186,8);
        s_cnt_null_pck_payload  <= to_unsigned(183,8);
        s_flag_ram_space_inc    <= '0';

        -----------------------------------------------------------------------------
        -- Reset output transport stream packet interface
        -----------------------------------------------------------------------------
        tsup_clk_o   <= ts_clk_rate_out_reg_1;
        tsup_sync_o  <= '0';
        tsup_valid_o <= '0';
        tsup_data_o  <= (others => '0');

        -----------------------------------------------------------------------------
        -- Reset clock domain alignment registers
        -----------------------------------------------------------------------------
        ts_clk_rate_out_reg_1   <= '0';
        ts_clk_rate_out_reg_2   <= '0';

        -----------------------------------------------------------------------------
        -- Initialize available RAM space tracker
        -----------------------------------------------------------------------------
        s_cnt_ram_space         <= C_MAX_RAM_SPACE;

    elsif rising_edge(clk_i) then

        -----------------------------------------------------------------------------
        -- Clock domain synchronization for TS output timing
        -----------------------------------------------------------------------------
        ts_clk_rate_out_reg_1 <= ts_clk_rate_out_i;
        ts_clk_rate_out_reg_2 <= ts_clk_rate_out_reg_1;

        -----------------------------------------------------------------------------
        -- Output TS clock forwarding
        -- Maintains alignment with incoming transport stream rate
        -----------------------------------------------------------------------------
        tsup_clk_o <= ts_clk_rate_out_reg_1;

        -----------------------------------------------------------------------------
        -- RAM occupancy tracking
        -- Updates available buffer space based on write/read activity
        -----------------------------------------------------------------------------
        if (s_flag_ram_space_inc = '0' and s_flag_ram_space_dec = '1') then
            s_cnt_ram_space <= s_cnt_ram_space - to_unsigned(187,10);

        elsif (s_flag_ram_space_inc = '1' and s_flag_ram_space_dec = '0') then
            s_cnt_ram_space <= s_cnt_ram_space + to_unsigned(187,10);
        end if;

        -----------------------------------------------------------------------------
        -- RAM read FSM
        -- Controls packet reconstruction and null packet insertion
        -----------------------------------------------------------------------------
        case s_state_ram_rd is

            ----------------------------------------------------------------
            when SYNC =>
                ------------------------------------------------------------------------------
                -- SYNC state
                -- Emits TS sync byte and decides between real or null packets
                ------------------------------------------------------------------------------
                s_ram_rden           <= '0';
                s_flag_ram_space_inc <= '0';

                if (ts_clk_rate_out_reg_1 = '1' and
                    ts_clk_rate_out_reg_2 = '0') then

                    if (s_cnt_ram_space <= to_unsigned(748,10)) then 
                        s_state_ram_rd <= RD_PCK;
                        s_ram_rden     <= '1';

                        if unsigned(s_ram_rdaddress) = C_MAX_RAM_SPACE - 1 then
                            s_ram_rdaddress <= (others => '0');
                        else
                            s_ram_rdaddress <= std_logic_vector(unsigned(s_ram_rdaddress)+1);
                        end if;

                    else
                        s_state_ram_rd <= NULL_PCK_PID_H;
                    end if;

                    tsup_data_o  <= x"47";
                    tsup_sync_o   <= '1';
                    tsup_valid_o  <= '1';
                end if;

            ----------------------------------------------------------------
            when RD_PCK =>
                ------------------------------------------------------------------------------
                -- RD_PCK state
                -- Reads valid TS packets from RAM buffer
                ------------------------------------------------------------------------------
                s_ram_rden           <= '0';
                s_flag_ram_space_inc <= '0';

                if (ts_clk_rate_out_reg_1 = '1' and
                    ts_clk_rate_out_reg_2 = '0') then

                    if (s_cnt_rd_pck = 0) then
                        s_state_ram_rd       <= SYNC;
                        s_cnt_rd_pck         <= to_unsigned(186, 8);
                        s_flag_ram_space_inc <= '1';

                    else
                        s_state_ram_rd <= RD_PCK;
                        s_cnt_rd_pck   <= s_cnt_rd_pck - 1;

                        s_ram_rden <= '1';

                        if unsigned(s_ram_rdaddress) = C_MAX_RAM_SPACE - 1 then
                            s_ram_rdaddress <= (others => '0');
                        else
                            s_ram_rdaddress <= std_logic_vector(unsigned(s_ram_rdaddress)+1);
                        end if;
                    end if;

                    tsup_sync_o  <= '0';
                    tsup_data_o  <= s_ram_q;
                    tsup_valid_o <= '1';
                end if;

            ----------------------------------------------------------------
            when NULL_PCK_PID_H =>
                ------------------------------------------------------------------------------
                -- NULL packet generation (PID high byte)
                -- Inserts null TS packet when RAM is under threshold
                ------------------------------------------------------------------------------
                if (ts_clk_rate_out_reg_1 = '1' and
                    ts_clk_rate_out_reg_2 = '0') then

                    s_state_ram_rd <= NULL_PCK_PID_L;
                    tsup_sync_o    <= '0';
                    tsup_data_o    <= x"1F";
                    tsup_valid_o   <= '1';

                end if;

            ----------------------------------------------------------------
            when NULL_PCK_PID_L =>
                ------------------------------------------------------------------------------
                -- NULL packet generation (PID low byte)
                ------------------------------------------------------------------------------
                if (ts_clk_rate_out_reg_1 = '1' and
                    ts_clk_rate_out_reg_2 = '0') then

                    s_state_ram_rd <= NULL_PCK_CC_AFC;
                    tsup_data_o    <= x"FF";
                    tsup_valid_o   <= '1';

                end if;

            ----------------------------------------------------------------
            when NULL_PCK_CC_AFC =>
                ------------------------------------------------------------------------------
                -- NULL packet continuity / adaptation field control
                ------------------------------------------------------------------------------
                if (ts_clk_rate_out_reg_1 = '1' and
                    ts_clk_rate_out_reg_2 = '0') then

                    s_state_ram_rd <= NULL_PCK_PAYLOAD;
                    tsup_data_o    <= x"10";
                    tsup_valid_o   <= '1';

                end if;

            ----------------------------------------------------------------
            when NULL_PCK_PAYLOAD =>
                ------------------------------------------------------------------------------
                -- NULL packet payload generation
                -- Fills remaining bytes with stuffing (0xFF)
                ------------------------------------------------------------------------------
                if (ts_clk_rate_out_reg_1 = '1' and
                    ts_clk_rate_out_reg_2 = '0') then

                    if (s_cnt_null_pck_payload = 0) then
                        s_state_ram_rd         <= SYNC;
                        s_cnt_null_pck_payload <= to_unsigned(183, 8);
                    else
                        s_state_ram_rd         <= NULL_PCK_PAYLOAD;
                        s_cnt_null_pck_payload <= s_cnt_null_pck_payload - 1;
                    end if;

                    tsup_data_o  <= x"FF";
                    tsup_valid_o <= '1';

                end if;

        end case;

    end if;

end process;

end architecture;