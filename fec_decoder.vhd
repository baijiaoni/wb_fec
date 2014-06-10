library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.wishbone_pkg.all;
use work.wr_fabric_pkg.all;
use work.fec_pkg.all;

entity fec_decoder is
  generic(
    g_dpram_size         : integer  := 90112/4;
    g_init_file          : string   :="";
    g_upper_bridge_sdb   : t_sdb_bridge);
  port(
    clk_i             : in  std_logic;
    rst_n_i           : in  std_logic;
    rst_lm32_n_i      : in  std_logic;
    ctrl_reg_i        : in  t_fec_ctrl_reg;
    stat_reg_o        : out t_fec_dec_stat_reg;
    dec_src_o         : out t_wrf_source_out;
    dec_src_i         : in  t_wrf_source_in;
    dec_snk_i         : in  t_wrf_sink_in;
    dec_snk_o         : out t_wrf_sink_out;
    wb_cross_master_i : in  t_wishbone_master_in;
    wb_cross_master_o : out t_wishbone_master_out);
end fec_decoder;

architecture rtl of fec_decoder is
  constant c_master       : natural := 2;
  constant c_lm32_data    : natural := 0;
  constant c_lm32_add     : natural := 1;

  --constant c_slave        : natural := 4;
  constant c_slave        : natural := 3;
  constant c_lm32_dpram   : natural := 0;
  constant c_upper_bridge : natural := 2;
  constant c_fec_dec      : natural := 4;
  constant c_fabric2wb    : natural := 1;

  -----------------------------------------------------------------------------
  --WB intercon
  -----------------------------------------------------------------------------  
  constant c_layout_req : t_sdb_record_array(c_slave-1 downto 0) :=
     (c_lm32_dpram   => f_sdb_embed_device((f_xwb_dpram(g_dpram_size)), x"00000000"),
      --c_fabric2wb    => f_sdb_embed_device(c_fec_fabric2wb_sdb,         x"3FFFFB00"),
      c_fabric2wb    => f_sdb_embed_device(c_fec_fabric2wb_sdb,         x"00100000"),
      c_upper_bridge => f_sdb_embed_bridge(g_upper_bridge_sdb,          x"80000000"));
 
   constant c_sdb_address : t_wishbone_address := x"3FFFE000";

   signal cbar_slave_i  : t_wishbone_slave_in_array  (c_master-1 downto 0);
   signal cbar_slave_o  : t_wishbone_slave_out_array (c_master-1 downto 0);
   signal cbar_master_i : t_wishbone_master_in_array (c_slave-1 downto 0);
   signal cbar_master_o : t_wishbone_master_out_array(c_slave-1 downto 0);

   -- irq fabric2wb FIFO
   signal s_lm32_irq    : std_logic_vector(31 downto 0) := (others => '0');
   signal s_rst_lm32_n  : std_logic;

begin

  -----------------------------------------------------------------------------
  -- Fabric intercon
  -----------------------------------------------------------------------------

  --dec_src_o    <= dec_snk_i;
  --dec_snk_o    <= dec_src_i;

  -----------------------------------------------------------------------------
  -- FEC Decoder Unit
  -----------------------------------------------------------------------------
  
--  DEC_UNIT : fec_decoder_unit
--    port map(
--      clk_i           => clk_i,
--      rst_n_i         => rst_n_i,
--      dec_src_i       => dec_src_i,  
--      dec_src_o       => dec_src_o,
--      wb_dec_slave_i  => cbar_master_o(c_fec_dec),
--      wb_dec_slave_o  => cbar_master_i(c_fec_dec));
--
--  stat_reg_o <= c_stat_dec_reg_default;
--  
  -----------------------------------------------------------------------------
  -- FEC Decoder Unit
  -----------------------------------------------------------------------------

  F2W_FIFO : fabric2wb_fifo
    port map(
      clk_i           => clk_i,
      rst_n_i         => rst_n_i,
      dec_snk_i       => dec_snk_i,  
      dec_snk_o       => dec_snk_o,
      irq_fwb_o       => s_lm32_irq(0),
      wb_fwb_slave_i  => cbar_master_o(c_fabric2wb),
      wb_fwb_slave_o  => cbar_master_i(c_fabric2wb));
 
  -----------------------------------------------------------------------------
  -- LM32 softCPU
  -----------------------------------------------------------------------------
  
  LM32_CORE : xwb_lm32
    generic map(g_profile => "medium_icache_debug",
                g_sdb_address => c_sdb_address)
    port map(
      clk_sys_i => clk_i,
      rst_n_i   => s_rst_lm32_n,
      irq_i     => s_lm32_irq,
      dwb_o     => cbar_slave_i(c_lm32_data), -- Data bus
      dwb_i     => cbar_slave_o(c_lm32_data),
      iwb_o     => cbar_slave_i(c_lm32_add), -- Instruction bus
      iwb_i     => cbar_slave_o(c_lm32_add));

  s_rst_lm32_n <= rst_n_i and rst_lm32_n_i;
  
  DPRAM : xwb_dpram
    generic map(
      g_size                  => g_dpram_size,
      g_init_file             => g_init_file,
      g_must_have_init_file   => true,
      g_slave1_interface_mode => PIPELINED,
      g_slave2_interface_mode => PIPELINED,
      g_slave1_granularity    => BYTE,
      g_slave2_granularity    => BYTE)  
    port map(
      clk_sys_i => clk_i,
      rst_n_i   => rst_n_i,
      slave1_i  => cbar_master_o(c_lm32_dpram),
      slave1_o  => cbar_master_i(c_lm32_dpram),
      slave2_i  => cc_dummy_slave_in,
      slave2_o  => open);

  -----------------------------------------------------------------------------
  -- WB gateway to the next WB intercon
  -----------------------------------------------------------------------------

  cbar_master_i(c_upper_bridge)	<= wb_cross_master_i;
  wb_cross_master_o  				    <= cbar_master_o(c_upper_bridge);

  -----------------------------------------------------------------------------
  -- WB intercon
  -----------------------------------------------------------------------------
  WB_CON : xwb_sdb_crossbar
    generic map(
      g_num_masters => c_master,
      g_num_slaves  => c_slave,
      g_registered  => true,
      g_wraparound  => true,
      g_layout      => c_layout_req,
      g_sdb_addr    => c_sdb_address)  
    port map(
      clk_sys_i => clk_i,
      rst_n_i   => rst_n_i,
      -- Master connections (INTERCON is a slave)
      slave_i   => cbar_slave_i,
      slave_o   => cbar_slave_o,
      -- Slave connections (INTERCON is a master)
      master_i  => cbar_master_i,
      master_o  => cbar_master_o);

end rtl;
