library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.wishbone_pkg.all;

entity wb_slave_deco is
  port(
    clk_i         : in  std_logic;
    rstn_i        : in  std_logic;
    load_i        : in  std_logic;
    error_i       : in  std_logic;
    buffer2wb_i   : in  std_logic_vector(95 downto 0);
    wb_slave_o    : out t_wishbone_slave_out;
    wb_slave_i    : in  t_wishbone_slave_in);
end wb_slave_deco;

architecture rtl of wb_slave_deco is
begin


  wb_trans : process(clk_i, load_i)

  begin

    if rising_edge(clk_i) then
      if rstn_i = '0' then

      else
        if load_i = '1' then



        end if;
      end if;
  end if;

  end process;

end rtl;

