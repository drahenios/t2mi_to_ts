library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;

library osvvm;
use osvvm.RandomPkg.all;

library tb_src_lib;
use tb_src_lib.t2mi_to_ts_top_tb_pkg.all;

package t2mi_to_ts_top_tc_pkg is

  procedure test_reset (signal tb_i : in    t_tb_i; signal tb_o : inout t_tb_o);

end package t2mi_to_ts_top_tc_pkg;

package body t2mi_to_ts_top_tc_pkg is

  -----------------------------------------------------------------------------
  -- TEST: RESET BEHAVIOR
  -- Verifies correct DUT behavior after reset and basic configuration
  -----------------------------------------------------------------------------
  procedure test_reset (
    signal tb_i : in    t_tb_i;
    signal tb_o : inout t_tb_o
  ) is
  begin

    -----------------------------------------------------------------------------
    -- TEST START
    -----------------------------------------------------------------------------
    print("Check if reset works correctly");

    -----------------------------------------------------------------------------
    -- TESTBENCH INITIALIZATION
    -----------------------------------------------------------------------------
    init_tb(tb_o);
    wait_clk(tb_i.clk, 10);

    -----------------------------------------------------------------------------
    -- RELEASE RESET AND CONFIGURE DUT
    -----------------------------------------------------------------------------
    tb_o.rst <= '0';

    tb_o.ts_target_pid_i          <= 13x"1000";
    tb_o.ts_target_pid_received_i <= '1';

    tb_o.ts_valid_i <= '1';

    -----------------------------------------------------------------------------
    -- STABILIZATION PHASE
    -----------------------------------------------------------------------------
    wait for 2 us;

    -----------------------------------------------------------------------------
    -- WAIT FOR TRANSPORT STREAM ACTIVITY (TIMEOUT = 10 us)
    -----------------------------------------------------------------------------
    wait until rising_edge(tb_i.ts_clk) for 10 us;

    -----------------------------------------------------------------------------
    -- START STREAM GENERATION
    -----------------------------------------------------------------------------
    tb_o.stream_active <= '1';

    -----------------------------------------------------------------------------
    -- RUN TIME
    -----------------------------------------------------------------------------
    wait for 1 ms;

  end procedure;

end package body t2mi_to_ts_top_tc_pkg;
