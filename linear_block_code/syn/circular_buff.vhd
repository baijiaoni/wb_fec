library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.circular_buff_pkg.all;

entity circular_buff is
  port(
    clk_i   : in  std_logic;
    rstn_i  : in  std_logic;
    full_o  : out std_logic;
    empty_o : out std_logic;
    push_i  : in  std_logic_vector(3 downto 0);
    pop_i   : in  std_logic;
    data_o  : out integer);
end circular_buff;

architecture rtl of circular_buff is
  constant c_size : integer := 4;  
  signal s_write  : integer range 0 to 4 := 4;
  type t_buffer is array (c_size-1 downto 0) of integer;
  signal s_buffer : t_buffer := (4,3,2,1);
  constant s_zero : t_buffer := (0,0,0,0);
  signal s_full   : std_logic := '0';
  signal s_empty  : std_logic := '0';

begin

  full_o <= s_full;

  full_ctrl: process(clk_i)
  begin
    if s_write = c_size then
      s_full <= '1';
    else
      s_full <= '0';
    end if;
  end process;
 
  empty_o <= s_empty;

  empty_ctrl: process(clk_i)
  begin
    if s_write = 0 then
      s_empty   <= '1';
    else
      s_empty   <= '0';
    end if;
  end process;

  read_write: process(clk_i)
    variable v_write    : integer   := 0;
    variable v_read     : integer   := 0;
    variable v_push     : std_logic := '0';
    variable v_new      : t_buffer := (0,0,0,0);
    variable v_buf_idx  : integer := 0;
    variable v_zero_idx : integer := 0;
    variable v_low_idx  : integer := 0;
    variable v_new_idx  : integer := 0;
    variable v_upp_idx  : integer := 0;
  begin

    if rising_edge(clk_i) then
      if rstn_i = '0' then
        --data_o    <= 3;
        s_buffer  <= (4,3,2,1);
        s_write   <= c_size;
      else        
        v_read  := 0;
        v_write := 0;
        v_push  := '0';
        v_new := (0,0,0,0);
        v_low_idx := 0;
        v_upp_idx := 3;
        v_buf_idx := 0;

        -- pop
        if pop_i = '1' and s_empty = '0' then
          --data_o  <= s_buffer(c_size-1)-1;
          v_read  := 1;
        end if;

        -- push
        for i in 0 to (c_size - 1) loop
          if push_i(i) = '1' and s_full = '0' then
            v_new(3-v_write) := i+1;
            v_write := v_write + 1;
            v_push  := '1';
          end if;
        end loop;

        s_write   <= s_write + v_write - v_read;
        v_new_idx   := c_size - v_write; 
        v_zero_idx  := c_size - s_write - v_write + v_read;
        v_buf_idx   := c_size - s_write;
          
        --if (c_size - s_write) = 0 and (pop_i = '1' or v_push = '1') then 
        --  v_buf_idx   := c_size;
        --end if;

        if v_zero_idx = 0 then
          v_low_idx   := c_size;
        end if;

        if pop_i = '1' then
          v_upp_idx := 2;
        end if;
        
        s_buffer <= s_buffer(v_upp_idx downto v_buf_idx) &
                    v_new(3 downto v_new_idx) & 
                    s_zero(v_zero_idx-1 downto v_low_idx);
      end if;
    end if;
  end process;

  data_o  <= s_buffer(c_size-1)-1;

end rtl;
