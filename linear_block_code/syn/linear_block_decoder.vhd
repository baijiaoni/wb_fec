-------------------------------------------------------------------------------
--! @file    : linear_block_decoder.vhd
--! @author  : Cesar Prados
--! @email   : c.prados@gsi.de
--  Company  : GSI
--  Created  : 2012 03
--  Update   : 2012 03
--  Platfrom : FPGA-generic
--  Standard : VHDL
-------------------------------------------------------------------------------
--! @brief   : Packet for the Golay family decoder. More information about Golay 
--             Code, "Error Correction Coding" Todd K. [1] The algorithm implemented
--             is the arithmetic decoding
-------------------------------------------------------------------------------
--  Copyright (c) 2012 Cesar Prados
-------------------------------------------------------------------------------
--! Revisions    :
--! Date     Version     Author      Description
--! June 03     1       C.Prados
-------------------------------------------------------------------------------
--! @todo   <next thing to do>
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.linear_block_pkg.all;

--! The word, "word" is reserved for encoded data 24 bits
--! The word. "data" is reserved for non-encoded data 12 btis

----------------------------------------------------------------------------------
--! @brief Linear Block Decoder
----------------------------------------------------------------------------------
--! @details
--! The entity decodes data words encoded following the (24,12,8) Golay Code
--! It is systematic,first 12 bits [23,12] are the original information
--! last 12 bits [11,0] are the redundant bits
----------------------------------------------------------------------------------

entity linear_block_decoder is
  port(
    clk_i       : in  std_logic;
    rstn_i      : in  std_logic;
    load_i      : in  std_logic;      
    data_i      : in  std_logic_vector(23 downto 0);
    decoded_o   : out std_logic_vector(11 downto 0);
    dec_stat_o  : out lc_stat;
    err_dec_o   : out std_logic;
    done_dec_o  : out std_logic);
  end linear_block_decoder;

architecture behavioral of linear_block_decoder is
    -- vector correction
    signal vector_fixed : word_vector := (others => '0');
    signal deco_state   : fms := idle;
    signal errorDecoded : std_logic;
    signal succeedDeco  : std_logic;
    signal errorVal			: errorValset;
    signal syndCal      : syndCalset;
    signal syndxBCal 		: syndxBCalset;
    signal dec_stat     : lc_stat;
begin

  deco_logic: process(clk_i,rstn_i)

    variable syndCalTemp 	  : syndCalset;
    variable syndxBCalTemp  : syndxBCalset;
    variable errorValTemp	  : errorValset;

  begin


  if(clk_i'event and clk_i='1') then
    if (rstn_i = '0') then
      deco_state  <= idle;
      syndCal     <= ((others=>'0'),0);
      errorVal    <= ((others=>'0'),0);
      syndxBCal   <= ((others=>'0'),0);
      vector_fixed<= (others=>'0');
      errorDecoded<= '0';
      succeedDeco <= '0';
      dec_stat    <= idle;
    else
      case deco_state is
        when idle =>
          errorDecoded  <= '0';
          succeedDeco   <= '0';
          if (load_i = '1') then
            deco_state <= step1;
          else
            deco_state <= idle;
          end if;			
        when step1 =>
          syndCalTemp := syndromeCal(data_i);	 
          syndCal <= syndCalTemp;
          dec_stat   <= step1;
          if (syndCalTemp.hammingW<=3) then 
            deco_state <= deco;
            vector_fixed <= (syndCalTemp.synd&zeros12) xor data_i;
          else
            vector_fixed <= zeros24;
            deco_state <= step2;
          end if;
        when step2 =>
         -- calc error vectors
          dec_stat   <= step2;
          errorValTemp := errorVectorCal(syndCal.synd);
          errorVal <= errorValTemp;
          deco_state <= step2_bis;		 
        when step2_bis =>
          if(errorVal.hammingW <= 2) then
            vector_fixed <= errorVal.errorVector xor data_i;
            deco_state <= deco;						     
          else
            vector_fixed <= zeros24;
            deco_state <= step3;	      
          end if;
        when step3 =>
          -- syndromexB and hammingW(syndromeB)
          syndxBCalTemp := syndromexBCal(syndCal.synd);
          syndxBCal <= syndxBCalTemp;
          dec_stat   <= step3;
          if (syndxBCalTemp.hammingW<=3) then 
            vector_fixed <= (zeros12&syndxBCalTemp.syndxB) xor data_i;
            deco_state <= deco;
          else						        								  
            vector_fixed <= zeros24;
            deco_state <= step4;						 
          end if;				 

        when step4 =>
          -- (Beta*B+rowi) and hammingW					 
          errorValTemp := errorVectorxBCal(syndxBCal.syndxB);
          errorVal      <= errorValTemp;
          deco_state    <= step4_bis;
          dec_stat      <= step4;
        when step4_bis =>		  
          if (errorVal.hammingW <= 2) then 
            deco_state    <= deco;
            vector_fixed  <= errorVal.errorVector xor data_i;
          else
            vector_fixed  <= zeros24;					 
            deco_state    <= fail;
          end if;
        when deco  =>
          deco_state <= idle;			
          errorDecoded  <= '0';	
          succeedDeco   <= '1';
        when fail  =>
          deco_state <= idle;
          errorDecoded  <= '1';					
          succeedDeco   <= '0';
        when others =>
          dec_stat      <= idle; 
          syndCal       <= ((others=>'0'),0);
          syndxBCal     <= ((others=>'0'),0);
          vector_fixed  <= zeros24;	
          --errorVal  <= ((others=>'0'),0);
          syndCalTemp := ((others=>'0'),0);					
        end case;
      end if;
  end if;
  end process;

  -- output
  dec_stat_o  <= dec_stat;
  decoded_o   <= vector_fixed(23 downto 12);
  done_dec_o  <= succeedDeco;
  err_dec_o   <= errorDecoded;

end behavioral;
