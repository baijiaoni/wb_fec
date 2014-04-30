library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.genram_pkg.all;
use work.wishbone_pkg.all;

entity fec_lm32 is
  generic(
   g_dpram_size         : integer  := 90112/4;
   g_init_file          : string   :="";
   g_upper_bridge_sbd   : t_sdb_bridge);
  port(
    clk_i               : in  std_logic;
    rst_n_i             : in  std_logic;
    lm32_irq_i          : in  std_logic_vector(31 downto 0);
    wb_lm32_master_o    : out t_wishbone_master_out;
    wb_lm32_master_i    : in  t_wishbone_master_in);
end fec_lm32;

architecture struct of fec_lm32 is
 -----------------------------------------------------------------------------
  --WB intercon
  -----------------------------------------------------------------------------  
  constant c_layout_req : t_sdb_record_array(1 downto 0) :=
    (c_lm32_upper_bridge => f_sdb_auto_bridge(g_upper_bridge_sbd,           true),
     c_lm32_dpram        => f_sdb_auto_device(f_xwb_dpram(g_dpram_size),    true));
                                                              
  constant c_layout      : t_sdb_record_array(1 downto 0) := f_sdb_auto_layout(c_layout_req);
  constant c_sdb_address : t_wishbone_address := f_sdb_auto_sdb(c_layout_req);

  signal cbar_slave_i  : t_wishbone_slave_in_array  (1 downto 0);
  signal cbar_slave_o  : t_wishbone_slave_out_array (1 downto 0);
  signal cbar_master_i : t_wishbone_master_in_array (1 downto 0);
  signal cbar_master_o : t_wishbone_master_out_array(1 downto 0);

begin 

  -----------------------------------------------------------------------------
  -- LM32
  -----------------------------------------------------------------------------  
  LM32_CORE : xwb_lm32
    generic map(g_profile => "medium_icache_debug")
    port map(
      clk_sys_i => clk_i,
      rst_n_i   => rst_n_i,
      irq_i     => lm32_irq_i,

      dwb_o => cbar_slave_i(0), -- Data bus
      dwb_i => cbar_slave_o(0),
      iwb_o => cbar_slave_i(1), -- Instruction bus
      iwb_i => cbar_slave_o(1)
      );

  -----------------------------------------------------------------------------
  -- Dual-port RAM
  -----------------------------------------------------------------------------  
  DPRAM : xwb_dpram
    generic map(
      g_size                  => g_dpram_size,
      g_init_file             => g_init_file,
      g_must_have_init_file   => false,
      g_slave1_interface_mode => PIPELINED,
      g_slave2_interface_mode => PIPELINED,
      g_slave1_granularity    => BYTE,
      g_slave2_granularity    => WORD)  
    port map(
      clk_sys_i => clk_i,
      rst_n_i   => rst_n_i,

      slave1_i => cbar_master_o(1),
      slave1_o => cbar_master_i(1),
      slave2_i => cc_dummy_slave_in,
      slave2_o => open
      );

  -----------------------------------------------------------------------------
  -- WB gateway to the next WB intercon
  -----------------------------------------------------------------------------

  cbar_master_i(1) <= wb_lm32_master_i;
  wb_lm32_master_o <= cbar_master_o(1);

  -----------------------------------------------------------------------------
  -- WB intercon
  -----------------------------------------------------------------------------
  WB_CON : xwb_sdb_crossbar
    generic map(
      g_num_masters => 2,
      g_num_slaves  => 2,
      g_registered  => true,
      g_wraparound  => true,
      g_layout      => c_layout,
      g_sdb_addr    => c_sdb_address
      )  
    port map(
      clk_sys_i => clk_i,
      rst_n_i   => rst_n_i,
      -- Master connections (INTERCON is a slave)
      slave_i   => cbar_slave_i,
      slave_o   => cbar_slave_o,
      -- Slave connections (INTERCON is a master)
      master_i  => cbar_master_i,
      master_o  => cbar_master_o
      );
end struct;
