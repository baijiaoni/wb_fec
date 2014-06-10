------------------------------------------------------------------------------
-- Title    : Golay family Codes
-- Project  : White Rabbit Robustness, Forward Error Correcting Codes
-------------------------------------------------------------------------------
--! @file    : linear_block_pkg.vhd
--! @author  : Cesar Prados
--! @email   : c.prados@gsi.de
--  Company  : GSI
--  Created  : 2012 03
--  Update   : 2012 03
--  Platfrom : FPGA-generic
--  Standard : VHDL
-------------------------------------------------------------------------------
--!  @brief   : Packet for the Golay family encoder decoder, define data types
--             and function for the logic operations of the code. More
--             information about Golay Code, "Error Correction Coding" Todd K. 
--             Moon.
-------------------------------------------------------------------------------
--  Copyright (c) 2012 Cesar Prados
-------------------------------------------------------------------------------
--! Revisions    :
--! Date     Version     Author      Description

-------------------------------------------------------------------------------
--! @todo   <next thing to do>
--  all the "conv_integer" to "to_integer"
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.wishbone_pkg.all;
use work.wr_fabric_pkg.all;

package linear_block_pkg is

  constant word_width :   integer := 24;
  constant data_width :   integer := 12;

  constant c_num_decoders : integer := 4;

  subtype data_vector is std_logic_vector(data_width-1 downto 0);
  subtype word_vector is std_logic_vector(word_width-1 downto 0);

  constant zeros12    :   data_vector :=(others=>'0');
  constant zeros24    :   word_vector :=(others=>'0');
  constant unos24    :   word_vector :=(others=>'1');

  type matrix  is array (natural range <>) of data_vector;
  type matrixl is array (natural range <>) of word_vector;
  type HamingWeight is array (63 downto 0) of integer range 0 to 11;

  type fms is (idle,step1,step2,step2_bis,step3,step4,step4_bis,deco,fail);
  type lc_stat is (idle,step1,step2,step3,step4);

  type magicBinaryNumber is array (4 downto 0) of integer;
  constant S : magicBinaryNumber := (1, 2, 4, 8,16); 

  type error_array is array (data_width-1 downto 0) of word_vector;
  type syndxB_array is array (data_width-1 downto 0) of word_vector;
  type synd_array is array (data_width-1 downto 0) of data_vector;
  type hamingW_array is array (data_width-1  downto 0) of integer range 0 to 11;

  type errorCalset is
  record
    errorVector : error_array;
    hammingW		: integer range 0 to 11;
  end record;

  type errorValset is
  record
    errorVector : word_vector;
    hammingW		: integer range 0 to 11;
  end record;

  constant iniErrorVal : errorValset := ( errorVector =>	(others=>'1'),
    hammingW => 11);
  
  type syndCalset is
  record
    synd : data_vector;
    hammingW		: integer range 0 to 11;
  end record;

  type syndxBCalset is
  record
    syndxB : data_vector;
    hammingW		: integer range 0 to 11;
  end record;

-- hamming weigth lookup table
  constant hammingWLT_1 : HamingWeight :=   ( 6, 5, 5, 4, 5, 4, 4, 3, 5, 4, 4, 3, 4, 3, 3, 2, 5, 
                                              4, 4, 3, 4, 3, 3, 2, 4, 3, 3, 2, 3, 2, 2, 1, 5, 4, 
                                              4, 3, 4, 3, 3, 2, 4, 3, 3, 2, 3, 2, 2, 1, 4, 3, 3, 
                                              2, 3, 2, 2, 1, 3, 2, 2, 1, 2, 1, 1, 0);
  constant hammingWLT_2 : HamingWeight := hammingWLT_1;
  constant hammingWLT_3 : HamingWeight := hammingWLT_1;
  constant hammingWLT_4 : HamingWeight := hammingWLT_1;			

    -- Binary b matrix
    --    constant bMatrix    :   matrix :=  ("011111111111","111011100010","110111000101",
    --     									"101110001011","101110001011","111000101101",
    --										"111000101101","111000101101","111000101101",
    --										"111000101101","111000101101","111000101101");
    -- Binray h matrix													
  constant hMatrix    :   matrixl:=("011111111111100000000000","111011100010010000000000",
                                    "110111000101001000000000","101110001011000100000000",
                                    "111100010110000010000000","111000101101000001000000",
                                    "110001011011000000100000","100010110111000000010000",
                                    "100101101110000000001000","101011011100000000000100",
                                    "110110111000000000000010","101101110001000000000001");
                                      -- binary g matrix												
  constant gMatrix    : matrixl:=("100000000000011111111111","010000000000111011100010",
                                  "001000000000110111000101","000100000000101110001011",
                                  "000010000000111100010110","000001000000111000101101",
                                  "000000100000110001011011","000000010000100010110111",
                                  "000000001000100101101110","000000000100101011011100",
                                  "000000000010110110111000","000000000001101101110001");

  function hammingWCal( row : data_vector) return integer;
  function hammingWCal_l( row : word_vector) return integer; --word_vector;

  function syndromeCal( row : word_vector) return syndCalset;	 
  function errorVectorCal( synd : data_vector) return errorValset;

  function syndromexBCal( synd : data_vector) return syndxBCalset;		 
  function errorVectorxBCal( synd : data_vector) return errorValset;

  function shift_right(row : data_vector; i : integer) return data_vector;
  function shift_right_l(row : word_vector; i : integer) return word_vector;

  component xlinear_block_decoder 
    port(
      clk_i         : in  std_logic;
      clk_fast_i    : in  std_logic;
      rstn_i        : in  std_logic;
      load_i        : in  std_logic;
      data_i        : in  std_logic_vector(15 downto 0);
      lc_dec_stat   : out lc_stat;
      wb_lb_slave_i : in  t_wishbone_slave_in;
      wb_lb_slave_o : out t_wishbone_slave_out);
  end component;

  component linear_block_decoder
    port(
      clk_i       : in  std_logic;
      rstn_i      : in  std_logic;
      load_i      : in  std_logic;      
      data_i      : in  std_logic_vector(23 downto 0);
      decoded_o   : out std_logic_vector(11 downto 0);
      dec_stat_o  : out lc_stat;
      err_dec_o   : out std_logic;
      done_dec_o  : out std_logic);
  end component;

  component wb_slave_deco
    port(
      clk_i         : in  std_logic;
      rstn_i        : in  std_logic;
      load_i        : in  std_logic;
      error_i       : in  std_logic;
      buffer2wb_i   : in  std_logic_vector(95 downto 0);
      wb_slave_o    : out t_wishbone_slave_out;
      wb_slave_i    : in  t_wishbone_slave_in);
  end component;

end linear_block_pkg;

package body linear_block_pkg is
-- calculates the step 1 of the algorithm
-- calc syndrome and hamming(syndrome)
-- G matrix
--11  0  1  2  3  4  5  6  7  8  9  10      23
--10     1           5  6  7     9  10  11  22
--9   0     2           6  7  8     10  11  21
--8   0  1     3           7  8  9      11  20
--7      1  2     4           8  9  10  11  19
--6   0     2  3     5           9  10  11  18
--5   0  1     3  4     6           10  11  17
--4   0  1  2     4  5     7            11  16
--3      1  2  3     5  6     8         11  15
--2         2  3  4     6  7     9      11  14
--1            3  4  5     7  8     10  11  13
--0   0           4  5  6     8  9      11  12

  --============================================================================
  -- syndromeCal
  --! @brief Calculates the syndrome of a vector 24 bit, and the hamming weight
  --! @param vector, "row" with the codeword \n
  --! @return the hamming height of codeword and teh syndrome 
  --============================================================================
  function syndromeCal( row : word_vector) return syndCalset is 
    variable syndTemp : syndCalset;
    variable tempW   : integer range 0 to 12;
  begin

    syndTemp.synd(11) := row(0)  xor row(1)  xor row(2) xor row(3) xor row(4) xor
    row(5)  xor row(6)  xor row(7) xor row(8) xor row(9) xor
    row(10) xor row(23);
    syndTemp.synd(10) := row(1)  xor row(5)  xor row(6) xor row(7) xor row(9) xor
    row(10) xor row(11) xor row(22);
    syndTemp.synd(9)  := row(0)  xor row(2)  xor row(6) xor row(7) xor row(8) xor
    row(10) xor row(11) xor row(21);
    syndTemp.synd(8)  := row(0)  xor row(1)  xor row(3) xor row(7) xor row(8) xor
    row(9)  xor row(11) xor row(20);
    syndTemp.synd(7)  := row(1)  xor row(2)  xor row(4) xor row(8) xor row(9) xor
    row(10) xor row(11) xor row(11);
    syndTemp.synd(6)  := row(0)  xor row(2)  xor row(3) xor row(5) xor row(9) xor
    row(10) xor row(11) xor row(18);
    syndTemp.synd(5)  := row(0)  xor row(1)  xor row(3) xor row(4) xor row(6) xor
    row(10) xor row(11) xor row(17);
    syndTemp.synd(4)  := row(0)  xor row(1)  xor row(2) xor row(4) xor row(5) xor
    row(7)  xor row(11) xor row(16);
    syndTemp.synd(3)  := row(1)  xor row(2)  xor row(3) xor row(5) xor row(6) xor
    row(8)  xor row(11) xor row(15);
    syndTemp.synd(2)  := row(2)  xor row(3)  xor row(4) xor row(6) xor row(7) xor
    row(9)  xor row(11) xor row(14);
    syndTemp.synd(1)  := row(3)  xor row(4)  xor row(5) xor row(7) xor row(8) xor
    row(10) xor row(11) xor row(13);
    syndTemp.synd(0)  := row(0)  xor row(4)  xor row(5) xor row(6) xor row(8) xor
    row(9)  xor row(11) xor row(12);					  

    syndTemp.hammingW  := hammingWCal(syndTemp.synd);---1;

    return syndTemp;
  end syndromeCal;

-- calculates the step 2 of the algorithm
-- calc error and hamming(error)
-- H matrix
--11- 11  12  13  14  15  16  17  18  19  20  21  22     
--10- 10      13              17  18  19      21  22  23  
--9 -  9  12      14              18  19  20      22  23  
--8 -  8  12  13     15               19  20  21      23  
--7 -  7      13  14     16               20  21  22  23  
--6 -  6  12      14 15       17              21  22  23  
--5 -  5  12  13     15  16       18              22  23  
--4 -  4  12  13  14     16  17       19              23  
--3 -  3      13  14 15      17   18      20          23  
--2 -  2          14 15  16       18  19      21      23  
--1 -  1             15  16  17       19  20      22  23  
--0 -     12             16  17   18      20  21      23

  --============================================================================
  -- errorvectorCal
  --! @brief Calculates the error vector for a given syndrome using the h matrix
  --! @param vector, syndrome  \n
  --! @return error vector, the hamming weight is filled with a dummy value 
  --============================================================================
  function errorVectorCal( synd : data_vector) return errorValset is                       
    variable error	  : errorValset;
    variable tmphamWg  : integer range 0 to 12:=0;		
    variable errorTemp : word_vector;
  begin
    error := iniErrorVal;
    for i in 11 downto 0 loop
      errorTemp := (synd&zeros12) xor hMatrix(i);
      tmphamWg := hammingWCal_l(errorTemp);
      --if (tmphamWg <= tresVector) then
      if (tmphamWg <= 3) then
        --error.hammingW := to_integer(unsigned(tmphamWg)-1);
        error.hammingW := tmphamWg-1;					 	  				
        error.errorVector := errorTemp;
      end if;
  end loop;

  return error;

  end errorVectorCal;

  --============================================================================
  -- errorVectorxBCal
  --! @brief calculates the error vector using the g matrix
  --! @param vector, syndrome  \n
  --! @return error vector, the hamming weight is filled with a dummy value 
  --============================================================================
  function errorVectorxBCal( synd : data_vector) return errorValset is                       
    variable error	  : errorValset;
    variable tmphamWg  : integer range 0 to 12:=0;		
    variable errorTemp : word_vector;
  begin
    error := iniErrorVal;
    for i in 11 downto 0 loop
      errorTemp := (zeros12&synd) xor gMatrix(i);
      tmphamWg:= hammingWCal_l(errorTemp);
      if (tmphamWg <= 3) then     
        error.hammingW := tmphamWg-1;	
        error.errorVector := errorTemp;
      end if;
    end loop;
  return error;
  end errorVectorxBCal;

  --============================================================================
  -- shift_right
  --! @brief logic shift of a given data_vector
  --! @param vector
  --! @return the shifted word_vector
  --============================================================================
  function shift_right(row : data_vector; i : integer) return data_vector is
    variable shifted : data_vector;		
  begin
    shifted := zeros24(i-1 downto 0) & row(11 downto i);
    return shifted;
  end shift_right;

  --============================================================================
  -- shift_right_l
  --! @brief logic shift of a given word_vector
  --! @param vector
  --! @return the shifted word_vector
  --============================================================================
  function shift_right_l(row : word_vector; i : integer) return word_vector is
    variable shifted : word_vector;		
  begin
    shifted := zeros24(i-1 downto 0) & row(23 downto i);
    return shifted;
  end shift_right_l;	 

  --============================================================================
  -- hammingWCal
  --! @brief calculates the hamming weight of a vector, inspired in "Bit Twiddling Hacks"
  --! @param data_vector
  --! @return hamming weight
  --============================================================================
  function hammingWCal( row : data_vector) return integer is

    variable hW  : integer range 0 to 12:=0;		  
    variable temp : std_logic_vector(11 downto 0);
  ---------------------------------------------------------
  --  constant five : std_logic_vector(11 downto 0) := x"555";
  --  constant three : std_logic_vector(11 downto 0) := x"333";
  ---------------------------------------------------------
  --  constant S : magicBinaryNumber := (1, 2, 4, 8);
  --	 constant Bi : error_array := (x"555", x"333", x"F0F", x"0FF");




  --	constant B : matrix := ("010101010101",
  --           					"001100110011",
  --			    			"111100001111",
  --							"000011111111");
  begin
    hw := hammingWLT_1(to_integer(unsigned(row(11 downto 6))))
          + hammingWLT_2(to_integer(unsigned(row(5 downto 0))));

    -- 		Other method... 125 Mhz
    --			temp := row - (shift_right(row,1) and B(0));
    --			temp := ((shift_right(temp,S(1)) and B(1)) 
    --					  + (temp and B(1)));
    --			temp := (shift_right(temp,S(2)) + temp) and B(2);
    --			temp := (shift_right(temp,S(3)) + temp) and B(3);	 
    --			hw   := to_integer(unsigned(temp));

    -- 		Other method... slower	 
    --        temp := row;
    --        temp := temp - (shift_right(temp,1) and five);
    --        temp := (temp and three) + (shift_right(temp,2) and three);
    --        temp := temp + shift_right(temp,4) and x"f0f";
    --        templ := (temp * x"1010101") ; Should be improve
    --        hw := to_integer(unsigned(templ(31 downto 24)));

    return hw;
  end hammingWCal;	 
  --============================================================================
  -- hammingWCal_l
  --! @brief calculates the hamming weight of a vector, inspired in "Bit Twiddling Hacks"
  --! @param word_vector
  --! @return hamming weight
  --============================================================================
  function hammingWCal_l( row : word_vector) return integer is -- word_vector is
    variable temp : word_vector;
    variable hW  : integer range 0 to 12:=0;		
  ---------------------------------------------------------
  --  constant five : std_logic_vector(11 downto 0) := x"555";
  --  constant three : std_logic_vector(11 downto 0) := x"333";
  ---------------------------------------------------------

  --constant B : matrixl := (x"555555", x"333333", x"0F0F0F", x"FF00FF");

  --    constant B : matrixl := (	"010101010101010101010101",
  --								"001100110011001100110011",
  --								"000011110000111100001111",
  --								"111111110000000011111111",
  --								"000000001111111111111111");
  begin

    hw :=   hammingWLT_1(to_integer(unsigned(row(23 downto 18))))
          + hammingWLT_2(to_integer(unsigned(row(17 downto 12))))
          + hammingWLT_3(to_integer(unsigned(row(11 downto 6))))+
            hammingWLT_4(to_integer(unsigned(row(5 downto 0))));			

    -- 		Other method... 125 Mhz
    --	     temp := row - (shift_right_l(row,1) and B(0));
    --	     temp := ((shift_right_l(temp,S(1)) and B(1)) 
    --		          + (temp and B(1)));
    --	     temp := (shift_right_l(temp,S(2)) + temp) and B(2);
    --	     temp := (shift_right_l(temp,S(3)) + temp) and B(3);
    --       temp := (shift_right_l(temp,S(4)) + temp) and B(4);		

    -- 		Other method... slower	 
    --        temp := row;
    --        temp := temp - (shift_right(temp,1) and five);
    --        temp := (temp and three) + (shift_right(temp,2) and three);
    --        temp := temp + shift_right(temp,4) and x"f0f";
    --        templ := (temp * x"1010101") ; Should be improve
    --        hw := to_integer(unsigned(templ(31 downto 24)));

    --    return temp;
  return hw;
  end hammingWCal_l;	 

  --============================================================================
  -- syndromeCal
  --! @brief Calculates the syndrome of a vector 24 bit, and the hamming weight
  --! @param vector, "row" with the codeword \n
  --! @return the hamming height of codeword and teh syndrome 
  --============================================================================
  function syndromexBCal( synd : data_vector) return syndxBCalset is

    variable syndBTemp : syndxBCalset;
    variable tempW   : integer range 0 to 12;
  begin

    syndBTemp.syndxB(11) :=  synd(0) xor synd(1) xor synd(2) xor synd(3) xor synd(4) xor                    
                             synd(5) xor synd(6) xor synd(7) xor synd(8) xor synd(9) xor synd(10);
    syndBTemp.syndxB(10) :=  synd(1) xor synd(5) xor synd(6) xor synd(7) xor synd(9) xor 
                             synd(10) xor synd(11);
    syndBTemp.syndxB(9)  :=  synd(0) xor synd(2) xor synd(6) xor synd(7) xor synd(8) xor 
                             synd(10) xor synd(11);
    syndBTemp.syndxB(8)  :=  synd(0) xor synd(1) xor synd(3) xor synd(7) xor synd(8) xor 
                             synd(9)  xor synd(11);
    syndBTemp.syndxB(7)  :=  synd(1) xor synd(2) xor synd(4) xor synd(8) xor synd(9) xor 
                             synd(10) xor synd(11);          
    syndBTemp.syndxB(6)  :=  synd(0) xor synd(2) xor synd(3) xor synd(5) xor synd(9) xor 
                             synd(10) xor synd(11);
    syndBTemp.syndxB(5)  :=  synd(0) xor synd(1) xor synd(3) xor synd(4) xor synd(6) xor 
                             synd(10) xor synd(11);
    syndBTemp.syndxB(4)  :=  synd(0) xor synd(1) xor synd(2) xor synd(4) xor synd(5) xor 
                             synd(7)  xor synd(11);
    syndBTemp.syndxB(3)  :=  synd(1) xor synd(2) xor synd(3) xor synd(5) xor synd(6) xor 
                             synd(8)  xor synd(11);
    syndBTemp.syndxB(2)  :=  synd(2) xor synd(3) xor synd(4) xor synd(6) xor synd(7) xor 
                             synd(9)  xor synd(11);
    syndBTemp.syndxB(1)  :=  synd(3) xor synd(4) xor synd(5) xor synd(7) xor synd(8) xor  
                             synd(10) xor synd(11);
    syndBTemp.syndxB(0)  :=  synd(0) xor synd(4) xor synd(5) xor synd(6) xor synd(8) xor 
                             synd(9)  xor synd(11);								 

    tempW := hammingWCal(syndBTemp.syndxB);---1;
    syndBTemp.hammingW  := tempW;

  return syndBTemp;
  end syndromexBCal;

end linear_block_pkg;
