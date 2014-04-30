library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.wishbone_pkg.all;
use work.wr_fabric_pkg.all;

entity fabric2wb_fifo is
  port(
    clk_i          : in  std_logic;
    rst_n_i        : in  std_logic;
    dec_snk_i      : in  t_wrf_sink_in;
    dec_snk_o      : out t_wrf_sink_out;
    wb_fwb_slave_i : in  t_wishbone_slave_in;
    wb_fwb_slave_o : out t_wishbone_slave_out);
end fabric2wb_fifo;

architecture rtl of fabric2wb_fifo is


begin

  wb_fwb_slave_o <= cc_dummy_slave_out;





end rtl;




