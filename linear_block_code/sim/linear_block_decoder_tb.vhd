library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.linear_block_package.all;


-- The word, "word" is reserved for encoded data 24 bits
-- The word. "data" is reserved for non-encoded data 12 btis
entity linear_block_decoder_tb is
    end linear_block_decoder_tb;



architecture behavioral of linear_block_decoder_tb is

    signal clk_i            : std_logic:= '0';
    signal reset_i          : std_logic:= '1';
    signal data_i           : std_logic_vector(23 downto 0);
    signal decoded_o        : std_logic_vector(11 downto 0):=(others =>'0');
    signal errordecoded_o   : std_logic:= '0';
    signal load_i           : std_logic:= '0';
    signal ok_dec_o         : std_logic:= '0';
    signal dec_stat         : lc_stat;
    constant period : time  := 8 ns;    

begin

    decoder_tb : linear_block_decoder
    port map(
      clk_i     => clk_i,
      rst_i     => reset_i,
      load_i    => load_i,  
      data_i    => data_i,
      dec_stat_o=> dec_stat,
      decoded_o => decoded_o,
      err_dec_o => errordecoded_o,
      ok_dec_o => ok_dec_o);

    clk_i_proc    : process
    begin
      clk_i <= '0';
      wait for period/2;  --for 0.5 ns signal is '0'.
      clk_i <= '1';
      wait for period/2;  --for next 0.5 ns
    end process;

    count_proc: process
    begin   
      reset_i <= '1';      
      load_i  <= '0';
      data_i <= (others=>'0'); 
      wait for period;
      reset_i <= '0';
      load_i  <= '1';
      -- error checks state machine till step 4, three bit error
      data_i <= to_stdlogicvector(x"54524a");
      wait for period*8;
      ------------------------------------------------------------------        
      reset_i <= '1';      
      load_i  <= '0';
      data_i <= (others=>'0'); 
      wait for period;
      reset_i <= '0';
      load_i  <= '1';
      -- error checks state machine till fail, four bit error
      data_i <= to_stdlogicvector(x"54d24a");
      wait for period*8;
      ---------------------------------------------------------------
      reset_i <= '1'; 
      load_i  <= '0';
      data_i <= (others=>'0');      
      wait for period;
      reset_i <= '0';
      load_i  <= '1';
      -- error checks state machine till step 1, one bit error
      data_i <= to_stdlogicvector(x"55725e");
      wait for period*8;
      reset_i <= '1'; 
      load_i  <= '0';
      data_i <= (others=>'0');      
      wait for period;
      reset_i <= '0';
      load_i  <= '1';
      -- error checks state machine till step 1, two bit errors
      data_i <= to_stdlogicvector(x"55f25e");
      wait for period*8;
      reset_i <= '1';       
      load_i  <= '0';
      data_i <= (others=>'0');
      wait for period;
      reset_i <= '0';
      load_i  <= '1';
      -- error checks state machine till step 1, three bit errors
      data_i <= to_stdlogicvector(x"45f25e");
      wait for period*8;
      reset_i <= '1';       
      load_i  <= '0';
      data_i <= (others=>'0');
      wait for period;
      reset_i <= '0';
      load_i  <= '1';
      -- error checks state machine till step 2, one error
      data_i <= to_stdlogicvector(x"55527e");
      wait for period*8;
      reset_i <= '1';
      load_i  <= '0';
      data_i <= (others=>'0');       
      wait for period;
      reset_i <= '0';
      load_i  <= '1';
      -- error checks state machine till step 3, two errors
      data_i <= to_stdlogicvector(x"55537e");
      wait for period*8;
      reset_i <= '1';
      load_i  <= '0';
      data_i <= (others=>'0');       
      wait for period;
      reset_i <= '0';
      load_i  <= '1';
      -- error checks state machine till step 3, three errors
      data_i <= to_stdlogicvector(x"55517e");
      wait for period*8;
      reset_i <= '1';
      load_i  <= '0';
      data_i <= (others=>'0');       
      wait for period;
      reset_i <= '0';
      load_i  <= '1';
      -- error checks state machine till step 2, two errors
      data_i <= to_stdlogicvector(x"55127e");
      wait for period*8;
      reset_i <= '1';
      load_i  <= '0';
      data_i <= (others=>'0');       
      wait for period;
      reset_i <= '0';
      load_i  <= '1';
      -- error checks state machine till step 4, three errors
      data_i <= to_stdlogicvector(x"55107e");
      wait for period*8;
      reset_i <= '1';
      load_i  <= '0';
      data_i <= (others=>'0');       
      wait for period;
      reset_i <= '0';
      load_i  <= '1';
      -- error checks state machine till step fail, four errors
      data_i <= to_stdlogicvector(x"55907e");
      wait for period*8;
    end process;
end behavioral;
