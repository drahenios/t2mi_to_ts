library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;

library osvvm;
use osvvm.RandomPkg.all;

package t2mi_to_ts_top_tb_pkg is

  -----------------------------------------------------------------------------
  -- CLOCK CONFIGURATION
  -----------------------------------------------------------------------------
  constant clk_period    : integer := 8;   -- ns, 125   MHz
  constant clk_ts_period : integer := 63;  -- ns, 15.87 MHz

  -----------------------------------------------------------------------------
  -- TESTBENCH INPUT INTERFACE
  -----------------------------------------------------------------------------
  type t_tb_i is record
    clk           : std_logic;
    ts_clk        : std_logic;

    tsup_clk_o    : std_logic;
    tsup_sync_o   : std_logic;
    tsup_valid_o  : std_logic;
    tsup_data_o   : std_logic_vector(7 downto 0);

    stream        : integer_array_t;
  end record t_tb_i;

  -----------------------------------------------------------------------------
  -- TESTBENCH OUTPUT INTERFACE
  -----------------------------------------------------------------------------
  type t_tb_o is record
    rst                      : std_logic;

    ts_sync_i                : std_logic;
    ts_valid_i               : std_logic;
    ts_data_i                : std_logic_vector(7 downto 0);

    ts_target_pid_i          : std_logic_vector(12 downto 0);
    ts_target_pid_received_i : std_logic;

    stream_active            : std_logic;
  end record t_tb_o;

  -----------------------------------------------------------------------------
  -- TESTBENCH INITIALIZATION
  -----------------------------------------------------------------------------
  procedure init_tb(
    signal tb_o : inout t_tb_o
  );

  -----------------------------------------------------------------------------
  -- WAIT FOR A GIVEN NUMBER OF CLOCK CYCLES
  -----------------------------------------------------------------------------
  procedure wait_clk(
    signal clk       : in std_logic;
    constant cycles  : integer
  );

end package t2mi_to_ts_top_tb_pkg;

package body t2mi_to_ts_top_tb_pkg is

  -----------------------------------------------------------------------------
  -- INITIALIZE TESTBENCH OUTPUT SIGNALS
  -----------------------------------------------------------------------------
  procedure init_tb(signal tb_o : inout t_tb_o) is
  begin
    tb_o.rst                      <= '1';
    tb_o.ts_valid_i               <= '0';
    tb_o.ts_target_pid_i          <= (others => '0');
    tb_o.ts_target_pid_received_i <= '0';
    tb_o.stream_active            <= '0';
  end procedure;

  -----------------------------------------------------------------------------
  -- WAIT FOR N RISING EDGES OF THE PROVIDED CLOCK
  -----------------------------------------------------------------------------
  procedure wait_clk(
    signal clk      : in std_logic;
    constant cycles : integer
  ) is
  begin
    for i in 0 to cycles loop
      wait until rising_edge(clk);
    end loop;
  end procedure;

end package body t2mi_to_ts_top_tb_pkg;

