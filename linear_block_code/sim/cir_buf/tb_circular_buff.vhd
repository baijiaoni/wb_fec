library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.circular_buff_pkg.all;

entity tb_circular_buff is
end tb_circular_buff;

architecture rtl of tb_circular_buff is
  signal clk    : std_logic;
  signal rstn   : std_logic;
  signal full   : std_logic;
  signal empty  : std_logic;
  signal pop    : std_logic;
  signal data_o : integer;
  signal push   : std_logic_vector(3 downto 0);
  constant period : time  := 8 ns;
begin

  buff : component circular_buff
    port map(
      clk_i   => clk,
      rstn_i  => rstn,
      full_o  => full,
      empty_o => empty,
      push_i  => push,
      pop_i   => pop,
      data_o  => data_o);

  clk_proc : process
  begin
    clk <= '0';
    wait for period/2;
    clk <= '1';
    wait for period/2;
  end process;
 
  proc : process
  begin
    rstn  <= '0';
    pop   <= '0';
    push  <= (others => '0');
    wait for period*2;
    rstn  <= '1';

    report "BUG IN LINEAR CODE";
    push  <= (others => '0');
    pop   <= '1';
    wait for period;    
    push  <= (others => '0');
    pop   <= '1';
    wait for period;    
    push  <= (others => '0');
    pop   <= '0';
    wait for period;    
    push  <= (others => '0');
    pop   <= '1';
    wait for period;    
    pop   <= '1';
    push(0) <= '1';
    push(1) <= '0';
    push(2) <= '0';
    push(3) <= '0';
    wait for period;
    pop   <= '0';
    push(0) <= '0';
    push(1) <= '0';
    push(2) <= '0';
    push(3) <= '1';
    wait for period;
    push <= "0000";
    pop   <= '0';
    wait for period;
    push <= "0100";
    pop   <= '0';
    wait for period*2;


    report "ONLY POPING TILL THE BUFFER IS EMPTY";
    push  <= (others => '0');
    pop   <= '1';
    wait for period;    
    pop   <= '1';
    push  <= (others => '0');
    wait for period;
    pop   <= '1';
    push  <= (others => '0');    
    wait for period;
    pop   <= '1';
    push  <= (others => '0');    
    wait for period;
    push  <= (others => '0');    
    pop   <= '0';
    wait for period*2;

    report "push two in once from empty then popx3, it should be empty high";
    push(0) <= '1';
    push(1) <= '1';
    push(2) <= '0';
    push(3) <= '0';
   wait for period;    
    pop   <= '1';
    push  <= (others => '0');    
    wait for period;
    pop   <= '1';
    push  <= (others => '0');    
    wait for period;
    pop   <= '1';
    wait for period*2;

    report "push four in once";
    push(0) <= '1';
    push(1) <= '1';
    push(2) <= '1';
    push(3) <= '1';
   wait for period*2;

    report "ONLY POPING x2";
    push  <= (others => '0');
    pop   <= '1';
    wait for period;    
    pop   <= '1';
    push  <= (others => '0');
    wait for period;
    pop     <= '0';
    push  <= (others => '0');    
    wait for period*2;
    
    report "POPING x1";    
    pop   <= '1';
    wait for period;
    pop   <= '1';
    wait for period;


    report "POPING x2 PUSH x2";    
    push(0) <= '1';
    push(1) <= '1';
    push(2) <= '0';
    push(3) <= '0';
   pop   <= '1';
    wait for period;
    push  <= (others => '0');    
    pop   <= '1';
    wait for period;
    pop     <= '0';
    push  <= (others => '0');    
    wait for period*2;
    
    report "POPING x1";    
    pop   <= '1';
    wait for period;
    pop   <= '1';
    wait for period;
   
    report "POPING x1 PUSH x2";        
    push(0) <= '1';
    push(1) <= '1';
    push(2) <= '0';
    push(3) <= '0';
    pop   <= '1';
    wait for period;
    pop     <= '0';
    push  <= (others => '0');    
    wait for period*2;

    report "POPING x4, empty high";
    push  <= (others => '0');
    pop   <= '1';
    wait for period;    
    push  <= (others => '0');
    pop   <= '1';
    wait for period;
    push  <= (others => '0');        
    pop     <= '1';    
    wait for period; 
    push  <= (others => '0');        
    pop     <= '1';    
    wait for period;

    push  <= (others => '0');        
    pop     <= '1';

    wait for period;
    push  <= (others => '0');    
    pop     <= '0';

    wait for period*2;
    
    report "POPINGx2 continuo";
    pop   <= '1';
    wait for period;
    pop   <= '1';
    wait for period;
    
    push  <= (others => '0');    
    pop   <= '0';
    wait for period;

    report "POPING & PUSH continuo 1";
    push(0) <= '1';
    push(1) <= '1';
    push(2) <= '0';
    push(3) <= '0';
    pop   <= '1';
    wait for period;
    push  <= (others => '0');    
    pop   <= '0';
    wait for period;

    report "POPING & PUSH continuo 2";
    push(0) <= '0';
    push(1) <= '0';
    push(2) <= '1';
    push(3) <= '0';
    pop   <= '1';
    wait for period;
    push  <= (others => '0');    
    pop   <= '0';
    wait for period;

    push(0) <= '0';
    push(1) <= '1';
    push(2) <= '0';
    push(3) <= '0';
    pop   <= '1';
    wait for period;

    pop     <= '0';
    push  <= (others => '0');    
    wait for period;

    report "THIS IS THE END!!!!";
    wait for period*8;
  end process;
end rtl;
