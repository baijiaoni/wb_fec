library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;


entity linear_block_performance is
    end linear_block_performance;


architecture behaviour of linear_block_performance is

    signal clk  :std_logic  := '0';
    signal data :std_logic_vector (11 downto 0) := (others => '0');
    signal word :std_logic_vector (23 downto 0) := (others => '0'); 
    signal frame:std_logic_vector (120000 downto 0) := (others => '0'); 
    signal data_1,data_2,data_3,data_4,data_5 :std_logic_vector(11 downto 0);
    signal word_1,word_2,word_3,word_4, word_5 :std_logic_vector(23 downto 0);
    shared variable count : integer := 0;

    constant PERIOD : time := 8 ns;
    constant payload: integer := 1;
    constant numEncoder : integer := 5;
    constant sizeword   : integer := 12;
    constant lengthframe: integer := 6000;
    constant zeros : std_logic_vector(23 downto 0) := (others => '0');
    component linear_block_enc
        port(
                clk :       in std_logic;
                data_in:    in std_logic_vector(11 downto 0);
                encoded_out:out std_logic_vector(23 downto 0)
            );
    end component;


begin 

    encoder_1:    linear_block_enc
    port map(
                clk => clk,
                data_in => data_1,
                encoded_out => word_1
            );
    encoder_2:    linear_block_enc
    port map(
                clk => clk,
                data_in => data_2,
                encoded_out => word_2
            );
    encoder_3:    linear_block_enc
    port map(
                clk => clk,
                data_in => data_3,
                encoded_out => word_3
            );

    encoder_4:    linear_block_enc
    port map(
                clk => clk,
                data_in => data_4,
                encoded_out => word_4
            );
    encoder_5:    linear_block_enc
    port map(
                clk => clk,
                data_in => data_5,
                encoded_out => word_5
            );

    clk_proc:   process
    begin
        clk <= '1';
        wait for PERIOD/2;
        clk <= '0';
        wait for PERIOD/2;
    end process;

    data_proc: process(clk)
    begin
        if(count < lengthframe) then
            data_1 <= to_stdlogicvector(x"111");
            data_2 <= to_stdlogicvector(x"111");
            data_3 <= to_stdlogicvector(x"111");
            data_4 <= to_stdlogicvector(x"111");
            data_5 <= to_stdlogicvector(x"111");
            count := count + (numEncoder*sizeword);
        else
            data_1 <= zeros(11 downto 0);
            data_2 <= zeros(11 downto 0);
            data_3 <= zeros(11 downto 0);
            data_4 <= zeros(11 downto 0);
            data_5 <= zeros(11 downto 0);
        end if;
    end process;


    frame_proc: process(clk)
        variable count1:integer :=0;
    begin
        if(count1 < 12000) then
            frame(count*2-1 downto (count*2 - (numEncoder*sizeword))) <= 
            word_5 & word_4 & word_3 & word_2 & word_1;         
            count1 := count1+120;
        else
            frame(count*2-1 downto (count*2 - (numEncoder*sizeword))) <= 
            zeros & zeros & zeros & zeros & zeros;
        end if;
    end process;

end;







