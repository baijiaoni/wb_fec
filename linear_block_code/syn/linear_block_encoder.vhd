-------------------------------------------------------------------------------
--! @file    : linear_block_encoder.vhd
--! @author  : Cesar Prados
--! @email   : c.prados@gsi.de
--  Company  : GSI
--  Created  : 2012 03
--  Update   : 2012 03
--  Platfrom : FPGA-generic
--  Standard : VHDL
-------------------------------------------------------------------------------
--!  @brief   : Packet for the Golay family encoder encoder. More
--             information about Golay Code, "Error Correction Coding" Todd K. 
--             Moon. The entity encodes data words following the (24,12,8) Golay Code
--             It is systematic,first 12 bits [23,12] are the original information
--             last 12 bits [11,0] are the redundant bits

-------------------------------------------------------------------------------
--  Copyright (c) 2012 Cesar Prados
-------------------------------------------------------------------------------
--! Revisions    :
--! Date     Version     Author      Description
-------------------------------------------------------------------------------
--! @todo   <next thing to do>
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

library work;
use work.linear_block_pkg.all;

entity linear_block_enc is
    port ( 	clk		    : in std_logic;
            data_in 	: in data_vector;
            encoded_out : out word_vector
        );
end linear_block_enc;


architecture Behavioral of linear_block_enc is
    signal check_bits 			: 	data_vector:=(others =>'0');

    -- b matrix 
    -- 555         1  0  1  0  1  0  1  0  1   0  1   0
    ---------------------------------------------------
    -- 11          0  1  2  3  4  5  6  7  8  9  10  
    -- 10 	          1           5  6  7     9  10  11
    -- 9 	       0     2           6  7  8     10  11  
    -- 8           0  1     3           7  8  9      11  
    -- 7 	          1  2     4           8  9  10  11
    -- 6           0     2  3     5           9  10  11  
    -- 5 	       0  1     3  4     6           10  11  
    -- 4 	       0  1  2     4  5     7            11  
    -- 3 	          1  2  3     5  6     8         11  
    -- 2 	             2  3  4     6  7     9      11  
    -- 1 	               3  4  5     7  8     10  11  
    -- 0     	  0           4  5  6     8  9      11   

begin
    process(data_in,clk)
    begin
        if(clk'event and clk='1') then   -- parity bits c * b      

            check_bits(11) <=  data_in(0) xor data_in(1) xor data_in(2) xor data_in(3) xor data_in(4) xor data_in(5) xor data_in(6) 
                               xor data_in(7) xor data_in(8) xor data_in(9) xor data_in(10);
            check_bits(10) <= data_in(1) xor data_in(5) xor data_in(6) xor data_in(7) xor data_in(9) xor data_in(10) xor data_in(11);
            check_bits(9) <= data_in(0) xor data_in(2) xor data_in(6) xor data_in(7) xor data_in(8) xor data_in(10) xor data_in(11);
            check_bits(8) <= data_in(0) xor data_in(1) xor data_in(3) xor data_in(7) xor data_in(8) xor data_in(9) xor data_in(11);
            check_bits(7) <= data_in(1) xor data_in(2) xor data_in(4) xor data_in(8) xor data_in(9) xor data_in(10) xor data_in(11);	  	  
            check_bits(6) <= data_in(0) xor data_in(2) xor data_in(3) xor data_in(5) xor data_in(9) xor data_in(10) xor data_in(11);
            check_bits(5) <= data_in(0) xor data_in(1) xor data_in(3) xor data_in(4) xor data_in(6) xor data_in(10) xor data_in(11);  
            check_bits(4) <= data_in(0) xor data_in(1) xor data_in(2) xor data_in(4) xor data_in(5) xor data_in(7) xor data_in(11);  
            check_bits(3) <= data_in(1) xor data_in(2) xor data_in(3) xor data_in(5) xor data_in(6) xor data_in(8)  xor data_in(11);
            check_bits(2) <= data_in(2) xor data_in(3) xor data_in(4) xor data_in(6) xor data_in(7) xor data_in(9)  xor data_in(11);
            check_bits(1) <= data_in(3) xor data_in(4) xor data_in(5) xor data_in(7) xor data_in(8) xor data_in(10) xor data_in(11);
            check_bits(0) <= data_in(0) xor data_in(4) xor data_in(5) xor data_in(6) xor data_in(8) xor data_in(9)  xor data_in(11);

        end if;
    end process;

    encoded_out <= data_in & check_bits; -- c = [data,check_bits]

end Behavioral;




