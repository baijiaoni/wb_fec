library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.linear_block_pkg.all;
use work.wishbone_pkg.all;


-- The word, "word" is reserved for encoded data 24 bits
-- The word. "data" is reserved for non-encoded data 12 btis
entity tb_linear_block is
end tb_linear_block;



architecture behavioral of tb_linear_block is

    signal clk_i            : std_logic;
    signal reset_i          : std_logic;
    signal data_i           : std_logic_vector(15 downto 0);
    signal data_2i          : std_logic_vector(24 downto 0);
    signal decoded_o        : std_logic_vector(31 downto 0):=(others =>'0');
    signal errordecoded_o   : std_logic:= '0';
    signal load_i           : std_logic:= '0';
    signal ok_dec_o         : std_logic:= '0';
    signal dec_stat         : lc_stat;      
    signal wb_slave_i       : t_wishbone_slave_in;
    signal wb_slave_o       : t_wishbone_slave_out;
    constant period : time  := 8 ns;    

begin

  testing : xlinear_block_decoder 
    port map(
      clk_i       => clk_i,
      clk_fast_i  => clk_i,
      rstn_i      => reset_i,
      load_i      => load_i,
      data_i      => data_i,
      lc_dec_stat => dec_stat,
      wb_lb_slave_i => wb_slave_i,
      wb_lb_slave_o => wb_slave_o);
  
    clk_i_proc    : process
    begin
      clk_i <= '1';
      wait for period/2;  --for 0.5 ns signal is '0'.
      clk_i <= '0';
      wait for period/2;  --for next 0.5 ns
    end process;

    count_proc: process
        variable cnt_process : integer := 0;
    begin   
      reset_i <= '0';      
      load_i  <= '0';
      data_i <= (others=>'0'); 
      wait for period*2;
      reset_i <= '1';
      wait for period*2;
      load_i  <= '1';
      -- simulates a halt from the fabric
      --      load_i  <= '0';      
      --      wait for period*3;
      --      load_i  <= '1';
      --      wait for period;
 
      ---------------------------------------------------------
      -- error checks state machine till step 4, three bit error
      --data_i <= to_stdlogicvector(x"54524a");
      report "STARTING";
      report "FIRST 48 bytes";
     ---------------------------------------------------------------
      report "1 BLOCK";
      --data_i <= to_stdlogicvector(x"55725e")
      --data_i <= to_stdlogicvector(x"55f25e")
      --till step 1, one bit error
      --till step 1, two bit error

      data_i <= to_stdlogicvector(x"5572");
      wait for period;

      data_i <= to_stdlogicvector(x"5E55");
      wait for period;

      data_i <= to_stdlogicvector(x"725e");
      wait for period;

      load_i  <= '0';      
      wait for period;
      ---------------------------------------------------------------
      report "2 BLOCK";
      -- error checks state machine till step 2, one error
      --data_i <= to_stdlogicvector(x"55527e");
      -- error checks state machine till step 3, two errors
      --data_i <= to_stdlogicvector(x"55537e");
      load_i  <= '1';
      data_i <= to_stdlogicvector(x"5572");
      wait for period;

      data_i <= to_stdlogicvector(x"5E55");
      wait for period;      
      
      data_i <= to_stdlogicvector(x"725e");
      wait for period;

      load_i  <= '0';      
      wait for period*1;
      ---------------------------------------------------------------
      report "3 BLOCK";
      --data_i <= to_stdlogicvector(x"55725e")
      --data_i <= to_stdlogicvector(x"55f25e")
      --till step 1, one bit error
      --till step 1, two bit error
      load_i  <= '1';
      data_i <= to_stdlogicvector(x"5572");
      wait for period;

      data_i <= to_stdlogicvector(x"5E55");
      wait for period;

      data_i <= to_stdlogicvector(x"f25e");
      wait for period;

      load_i  <= '0';      
      wait for period*1; 
      ---------------------------------------------------------------
      report "4 BLOCK";
      --data_i <= to_stdlogicvector(x"55725e")
      --data_i <= to_stdlogicvector(x"55f25e")
      --till step 1, one bit error
      --till step 1, two bit error
      load_i  <= '1';
      data_i <= to_stdlogicvector(x"5572");
      wait for period;

      data_i <= to_stdlogicvector(x"5E55");
      wait for period;

      data_i <= to_stdlogicvector(x"f25e");
      wait for period;

      --load_i  <= '0';      
      --wait for period*3;      
      ---------------------------------------------------------------
--      -- simulates a halt from the fabric
--      load_i  <= '1';
--      data_i <= to_stdlogicvector(x"5452");
--      wait for period;      
-- 
--      --data_i <= to_stdlogicvector(x"54524a");
--      data_i <= to_stdlogicvector(x"4a54");
--      wait for period;      
--
--     --data_i <= NEW
--      data_i <= to_stdlogicvector(x"d24a");
--      wait for period;
      ---------------------------------------------------------------      
      report "5 BLOCK";
      --data_i <= to_stdlogicvector(x"55725e")
      --data_i <= to_stdlogicvector(x"55f25e")
      --till step 1, one bit error
      --till step 1, two bit error

      data_i <= to_stdlogicvector(x"5572");
      wait for period;
      data_i <= to_stdlogicvector(x"5E55");
      wait for period;
      data_i <= to_stdlogicvector(x"f25e");
      wait for period;
      --load_i  <= '0';      
      --wait for period;      
      ---------------------------------------------------------------      
      report "6 BLOCK";
      --data_i <= to_stdlogicvector(x"55725e")
      --data_i <= to_stdlogicvector(x"55f25e")
      --till step 1, one bit error
      --till step 1, two bit error

      data_i <= to_stdlogicvector(x"5572");
      wait for period;
      data_i <= to_stdlogicvector(x"5E55");
      wait for period;
      data_i <= to_stdlogicvector(x"f25e");
      wait for period;
      --load_i  <= '0';      
      --wait for period;      

      ---------------------------------------------------------------      
      report "7 BLOCK";
      --data_i <= to_stdlogicvector(x"55725e")
      --data_i <= to_stdlogicvector(x"55f25e")
      --till step 1, one bit error
      --till step 1, two bit error

      data_i <= to_stdlogicvector(x"5572");
      wait for period;
      data_i <= to_stdlogicvector(x"5E55");
      wait for period;
      data_i <= to_stdlogicvector(x"f25e");
      wait for period;
      --load_i  <= '0';      
      --wait for period;      

      ---------------------------------------------------------------      
      report "8 BLOCK";
      --data_i <= to_stdlogicvector(x"55725e")
      --data_i <= to_stdlogicvector(x"55f25e")
      --till step 1, one bit error
      --till step 1, two bit error

      data_i <= to_stdlogicvector(x"5572");
      wait for period;
      data_i <= to_stdlogicvector(x"5E55");
      wait for period;
      data_i <= to_stdlogicvector(x"f25e");
      wait for period;
      --load_i  <= '0';      
      --wait for period;      

      ---------------------------------------------------------------      
      report "9 BLOCK";
      --data_i <= to_stdlogicvector(x"55725e")
      --data_i <= to_stdlogicvector(x"55f25e")
      --till step 1, one bit error
      --till step 1, two bit error

      data_i <= to_stdlogicvector(x"5572");
      wait for period;
      data_i <= to_stdlogicvector(x"5E55");
      wait for period;
      data_i <= to_stdlogicvector(x"f25e");
      wait for period;
      --load_i  <= '0';      
      --wait for period;      

      ---------------------------------------------------------------      
      report "10 BLOCK";
      --data_i <= to_stdlogicvector(x"55725e")
      --data_i <= to_stdlogicvector(x"55f25e")
      --till step 1, one bit error
      --till step 1, two bit error

      data_i <= to_stdlogicvector(x"5572");
      wait for period;
      data_i <= to_stdlogicvector(x"5E55");
      wait for period;
      data_i <= to_stdlogicvector(x"f25e");
      wait for period;
      --load_i  <= '0';      
      --wait for period;      

      ---------------------------------------------------------------      
      report "11 BLOCK";
      --data_i <= to_stdlogicvector(x"55725e")
      --data_i <= to_stdlogicvector(x"55f25e")
      --till step 1, one bit error
      --till step 1, two bit error

      data_i <= to_stdlogicvector(x"5572");
      wait for period;
      data_i <= to_stdlogicvector(x"5E55");
      wait for period;
      data_i <= to_stdlogicvector(x"f25e");
      wait for period;
      --load_i  <= '0';      
      --wait for period;      
      ---------------------------------------------------------------      
      report "12 BLOCK";
      --data_i <= to_stdlogicvector(x"55725e")
      --data_i <= to_stdlogicvector(x"55f25e")
      --till step 1, one bit error
      --till step 1, two bit error

      data_i <= to_stdlogicvector(x"5572");
      wait for period;
      data_i <= to_stdlogicvector(x"5E55");
      wait for period;
      data_i <= to_stdlogicvector(x"f25e");
      wait for period;
      --load_i  <= '0';      
      --wait for period;      
      ---------------------------------------------------------------      
      report "13 BLOCK";
      --data_i <= to_stdlogicvector(x"55725e")
      --data_i <= to_stdlogicvector(x"55f25e")
      --till step 1, one bit error
      --till step 1, two bit error

      data_i <= to_stdlogicvector(x"5572");
      wait for period;
      data_i <= to_stdlogicvector(x"5E55");
      wait for period;
      data_i <= to_stdlogicvector(x"f25e");
      wait for period;
      --load_i  <= '0';      
      --wait for period;      
      ---------------------------------------------------------------      
      --data_i <= to_stdlogicvector(x"55725e")
      --data_i <= to_stdlogicvector(x"55f25e")
      --till step 1, one bit error
      --till step 1, two bit error

      data_i <= to_stdlogicvector(x"5572");
      wait for period;
      data_i <= to_stdlogicvector(x"5E55");
      wait for period;
      data_i <= to_stdlogicvector(x"f25e");
      wait for period;
      --load_i  <= '0';      
      --wait for period;      
      ---------------------------------------------------------------      
      --data_i <= to_stdlogicvector(x"55725e")
      --data_i <= to_stdlogicvector(x"55f25e")
      --till step 1, one bit error
      --till step 1, two bit error

      data_i <= to_stdlogicvector(x"5572");
      wait for period;
      data_i <= to_stdlogicvector(x"5E55");
      wait for period;
      data_i <= to_stdlogicvector(x"f25e");
      wait for period;
      --load_i  <= '0';      
      --wait for period;      
      ---------------------------------------------------------------      
      --data_i <= to_stdlogicvector(x"55725e")
      --data_i <= to_stdlogicvector(x"55f25e")
      --till step 1, one bit error
      --till step 1, two bit error

      data_i <= to_stdlogicvector(x"5572");
      wait for period;
      data_i <= to_stdlogicvector(x"5E55");
      wait for period;
      data_i <= to_stdlogicvector(x"f25e");
      wait for period;
      --load_i  <= '0';      
      --wait for period;      
      ---------------------------------------------------------------      
      --data_i <= to_stdlogicvector(x"55725e")
      --data_i <= to_stdlogicvector(x"55f25e")
      --till step 1, one bit error
      --till step 1, two bit error

      data_i <= to_stdlogicvector(x"5572");
      wait for period;
      data_i <= to_stdlogicvector(x"5E55");
      wait for period;
      data_i <= to_stdlogicvector(x"f25e");
      wait for period;
      --load_i  <= '0';      
      --wait for period;      
      ---------------------------------------------------------------      
      --data_i <= to_stdlogicvector(x"55725e")
      --data_i <= to_stdlogicvector(x"55f25e")
      --till step 1, one bit error
      --till step 1, two bit error

      data_i <= to_stdlogicvector(x"5572");
      wait for period;
      data_i <= to_stdlogicvector(x"5E55");
      wait for period;
      data_i <= to_stdlogicvector(x"f25e");
      wait for period;
      --load_i  <= '0';      
      --wait for period;      
      ---------------------------------------------------------------      
      --data_i <= to_stdlogicvector(x"55725e")
      --data_i <= to_stdlogicvector(x"55f25e")
      --till step 1, one bit error
      --till step 1, two bit error

      data_i <= to_stdlogicvector(x"5572");
      wait for period;
      data_i <= to_stdlogicvector(x"5E55");
      wait for period;
      data_i <= to_stdlogicvector(x"f25e");
      wait for period;
      --load_i  <= '0';      
      --wait for period;      
      ---------------------------------------------------------------      
      --data_i <= to_stdlogicvector(x"55725e")
      --data_i <= to_stdlogicvector(x"55f25e")
      --till step 1, one bit error
      --till step 1, two bit error

      data_i <= to_stdlogicvector(x"5572");
      wait for period;
      data_i <= to_stdlogicvector(x"5E55");
      wait for period;
      data_i <= to_stdlogicvector(x"f25e");
      wait for period;
      --load_i  <= '0';      
      --wait for period;      
      ---------------------------------------------------------------      
      --data_i <= to_stdlogicvector(x"55725e")
      --data_i <= to_stdlogicvector(x"55f25e")
      --till step 1, one bit error
      --till step 1, two bit error

      data_i <= to_stdlogicvector(x"5572");
      wait for period;
      data_i <= to_stdlogicvector(x"5E55");
      wait for period;
      data_i <= to_stdlogicvector(x"f25e");
      wait for period;
      --load_i  <= '0';      
      --wait for period;      


      load_i  <= '0';      
      wait for period;
    end process;
end behavioral;
