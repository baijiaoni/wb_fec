library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;


entity linear_block_testb is
    end linear_block_testb;


architecture behaviour of linear_block_testb is

    signal clk  :std_logic  := '0';
    signal data :std_logic_vector (11 downto 0) := (others => '0');
    signal word :std_logic_vector (23 downto 0) := (others => '0'); 

    constant PERIOD : time := 8 ns;

    component linear_block_enc
        port(
                clk :       in std_logic;
                data_in:    in std_logic_vector(11 downto 0);
                encoded_out:out std_logic_vector(23 downto 0)
            );
    end component;


begin 

    encoder:    linear_block_enc
    port map(
                clk => clk,
                data_in => data,
                encoded_out => word
            );

    clk_proc:   process
    begin
        clk <= '1';
        wait for PERIOD/2;
        clk <= '0';
        wait for PERIOD/2;
    end process;

    data_proc: process
    begin        
        wait for 16 ns;
        data <= to_stdlogicvector(x"111");
        wait;
    end process;

end;




