library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

package circular_buff_pkg is
  component circular_buff is
  port(
    clk_i   : in  std_logic;
    rstn_i  : in  std_logic;
    full_o  : out std_logic;
    empty_o : out std_logic;
    push_i  : in  std_logic_vector(3 downto 0);
    pop_i   : in  std_logic;
    data_o  : out integer);
  end component;
end package circular_buff_pkg;
