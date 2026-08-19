library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;

library osvvm;
use osvvm.RandomPkg.all;

library src_lib;

library tb_src_lib;
use tb_src_lib.t2mi_to_ts_top_tb_pkg.all;
use tb_src_lib.t2mi_to_ts_top_tc_pkg.all;

entity t2mi_to_ts_top_tb is
  generic (
    runner_cfg : string;
    tb_path    : string
  );
end entity;

architecture tb of t2mi_to_ts_top_tb is

  -----------------------------------------------------------------------------
  -- INPUT STREAM FILE
  -----------------------------------------------------------------------------
  constant c_stream : integer_array_t := load_raw(tb_path & "../input.ts");

  -----------------------------------------------------------------------------
  -- OUTPUT CAPTURE CONFIGURATION
  -- Number of bytes to write out
  -----------------------------------------------------------------------------
  constant c_num_bytes : integer := 188 * 200000;

  -----------------------------------------------------------------------------
  -- CLOCK AND TESTBENCH SIGNALS
  -----------------------------------------------------------------------------
  signal clk              : std_logic := '0';
  signal ts_clk           : std_logic := '0';

  signal tb_i             : t_tb_i;
  signal tb_o             : t_tb_o;

  signal s_stream_active  : std_logic := '0';

  -----------------------------------------------------------------------------
  -- RANDOM GENERATORS
  -----------------------------------------------------------------------------
  shared variable rnd_stimuli  : RandomPType;
  shared variable rnd_expected : RandomPType;

  -----------------------------------------------------------------------------
  -- OUTPUT CAPTURE CONTROL
  -----------------------------------------------------------------------------
  signal capture_done : boolean := false;

begin

  -----------------------------------------------------------------------------
  -- CONNECT INPUT STREAM TO TESTBENCH INTERFACE
  -----------------------------------------------------------------------------
  tb_i.stream <= c_stream;

  -----------------------------------------------------------------------------
  -- MAIN TESTBENCH CONTROL
  -----------------------------------------------------------------------------
  main : process
  begin

    test_runner_setup(runner, runner_cfg);

    rnd_stimuli.InitSeed(rnd_stimuli'instance_name);
    rnd_expected.InitSeed(rnd_stimuli'instance_name);

    while test_suite loop

      if run("test_reset") then
        test_reset(tb_i, tb_o);
      end if;

    end loop;

    -----------------------------------------------------------------------------
    -- KEEP SIMULATION RUNNING FOR OUTPUT CAPTURE
    -----------------------------------------------------------------------------
    wait for 3 sec;

    test_runner_cleanup(runner);
    wait;

  end process;

  -----------------------------------------------------------------------------
  -- TESTBENCH WATCHDOG
  -----------------------------------------------------------------------------
  test_runner_watchdog(runner, 5 sec);

  -----------------------------------------------------------------------------
  -- CLOCK GENERATION
  -----------------------------------------------------------------------------
  clk         <= not clk after (clk_period / 2) * 1 ns;
  ts_clk      <= not ts_clk after (clk_ts_period / 2) * 1 ns;

  tb_i.clk    <= clk;
  tb_i.ts_clk <= ts_clk;

  -----------------------------------------------------------------------------
  -- DEVICE UNDER TEST (DUT)
  -----------------------------------------------------------------------------
  dut : entity src_lib.t2mi_to_ts_top
    port map (
      clk_i                    => tb_i.clk,
      rst_i                    => tb_o.rst,
      ts_clk_i                 => tb_i.ts_clk,
      ts_sync_i                => tb_o.ts_sync_i,
      ts_valid_i               => tb_o.ts_valid_i,
      ts_data_i                => tb_o.ts_data_i,
      ts_target_pid_i          => tb_o.ts_target_pid_i,
      ts_target_pid_received_i => tb_o.ts_target_pid_received_i,
      tsup_clk_o               => tb_i.tsup_clk_o,
      tsup_sync_o              => tb_i.tsup_sync_o,
      tsup_valid_o             => tb_i.tsup_valid_o,
      tsup_data_o              => tb_i.tsup_data_o
    );

  -----------------------------------------------------------------------------
  -- INPUT STREAM GENERATOR
  -- Generates TS packets from the input RAW file
  -----------------------------------------------------------------------------
  process(tb_i.ts_clk, tb_o.rst)

    variable v_cnt      : integer := 0;
    variable v_cnt_word : integer := 0;
    variable v_cnt_file : integer := 0;

    variable v_word     : std_logic_vector(31 downto 0);

  begin

    if tb_o.rst = '1' then

      tb_o.ts_data_i <= (others => '0');
      tb_o.ts_sync_i <= '0';

      v_cnt      := 0;
      v_cnt_word := 0;
      v_cnt_file := 0;

    elsif rising_edge(tb_i.ts_clk) then

      s_stream_active <= tb_o.stream_active;

      tb_o.ts_sync_i  <= '0';

      -----------------------------------------------------------------------------
      -- START OF STREAM
      -----------------------------------------------------------------------------
      if tb_o.stream_active = '1' and s_stream_active = '0' then

        tb_o.ts_sync_i <= '1';

        v_cnt      := 0;
        v_cnt_word := 0;

        v_word     := std_logic_vector(
          to_signed(get(tb_i.stream, v_cnt_file), 32)
        );

        tb_o.ts_data_i <= v_word(7 downto 0);

      -----------------------------------------------------------------------------
      -- ACTIVE STREAM TRANSFER
      -----------------------------------------------------------------------------
      elsif tb_o.stream_active = '1' then

        v_cnt_word := v_cnt_word + 1;

        if v_cnt_word = 4 then

          v_cnt_word := 0;
          v_cnt_file := v_cnt_file + 1;

          v_word := std_logic_vector(
            to_signed(get(tb_i.stream, v_cnt_file), 32)
          );

          tb_o.ts_data_i <= v_word(7 downto 0);

        else

          tb_o.ts_data_i <=
            v_word((v_cnt_word + 1) * 8 - 1 downto v_cnt_word * 8);

        end if;

        v_cnt := v_cnt + 1;

        -----------------------------------------------------------------------------
        -- TS PACKET SYNCHRONIZATION (188 BYTES)
        -----------------------------------------------------------------------------
        if v_cnt = 188 then
          v_cnt := 0;
          tb_o.ts_sync_i <= '1';
        end if;

      end if;

    end if;

  end process;

  -----------------------------------------------------------------------------
  -- OUTPUT STREAM CAPTURE
  -- Captures DUT output stream and stores it into a TS file
  -----------------------------------------------------------------------------
  process(tb_i.tsup_clk_o)

    variable v_index : integer := 0;

    variable v_output_stream : integer_array_t := new_1d(
      length    => c_num_bytes,
      bit_width => 8,
      is_signed => false
    );

  begin

    if tb_o.rst = '1' then

      v_index := 0;

    elsif rising_edge(tb_i.tsup_clk_o) then

      if not capture_done then

        if tb_i.tsup_valid_o = '1' then

          set(
            v_output_stream,
            v_index,
            to_integer(unsigned(tb_i.tsup_data_o))
          );

          v_index := v_index + 1;

          -----------------------------------------------------------------------------
          -- SAVE OUTPUT FILE WHEN BUFFER IS FULL
          -----------------------------------------------------------------------------
          if v_index = c_num_bytes then

            save_raw(
              v_output_stream,
              tb_path & "../tsup_output.ts"
            );

            capture_done <= true;

          end if;

        end if;

      end if;

    end if;

  end process;

end architecture;