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
    irq_fwb_o      : out std_logic;
    wb_fwb_slave_i : in  t_wishbone_slave_in;
    wb_fwb_slave_o : out t_wishbone_slave_out);
end fabric2wb_fifo;

architecture rtl of fabric2wb_fifo is

  signal cnt : integer range 0 to 125000000;

begin

   -- this wb slave doesn't supoort them
   wb_fwb_slave_o.int <= '0';
   wb_fwb_slave_o.rty <= '0';
   wb_fwb_slave_o.err <= '0';
  
  wb_process : process(clk_i)
  begin

    if rising_edge(clk_i) then
      if rst_n_i = '0' then
         wb_fwb_slave_o.ack    <= '0';
         wb_fwb_slave_o.dat    <= (others => '0');
      else

         wb_fwb_slave_o.ack <= wb_fwb_slave_i.cyc and wb_fwb_slave_i.stb;

         if wb_fwb_slave_i.cyc = '1' and wb_fwb_slave_i.stb = '1' then
           wb_fwb_slave_o.dat <= (others => '0');

          --case wb_fwb_slave_i.adr(5 downto 2) is

          --  when "0000"    =>  -- enable/disable encoder 0x0a

          --  when others =>

          --end case;
         end if;      
      end if;
    end if;
   end process;

  interrupt : process(clk_i)
  begin

    if rising_edge(clk_i) then
      if rst_n_i = '0' then
        cnt <= 0;
        irq_fwb_o <= '0';
      else
        if cnt /= 125000000 then
          irq_fwb_o <= '0';
          cnt <= cnt +1;
        else
        cnt <= 0;
        irq_fwb_o <= '1';
        end if;
      end if;
    end if;
  end process;

end rtl;
