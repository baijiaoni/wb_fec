library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.wishbone_pkg.all;
use work.wr_fabric_pkg.all;
use work.fec_pkg.all;
use work.gray_pack.all;
use work.lfsr_pkg.all;

entity packet_gen is
   port (
      clk_i       : in  std_logic;
      rst_n_i     : in  std_logic;
      ctrl_reg_i  : in  t_pg_ctrl_reg;
      stat_reg_o  : out t_pg_stat_reg;
      pg_src_i    : in  t_wrf_source_in;
      pg_src_o    : out t_wrf_source_out);
end packet_gen;

architecture rtl of packet_gen is
   
   ------------ fsm start/stop and frame gen
   signal s_pg_fsm         : t_pg_fsm := IDLE;
   signal s_frame_fsm      : t_frame_fsm := INIT_HDR;
   -- packet gen reg
   signal s_pg_state       : t_pg_state := c_pg_state_default;
   -- wb reg
   signal s_ctrl_reg       : t_pg_ctrl_reg := c_pg_ctrl_default;
  -- signal s_ctrl_reg       : t_pg_ctrl_reg;
   signal s_stat_reg       : t_pg_stat_reg := c_pg_stat_default;

   signal s_frame_gen      : integer := 0;
   signal s_start_payload  : std_logic := '0';
   signal s_pay_load       : t_wrf_bus := (others => '0');
   signal s_pay_load_reg   : t_wrf_bus := (others => '0');
   signal s_hdr_reg        : t_eth_hdr := (others => '0');
   signal s_eth_hdr        : t_eth_hdr := (others => '0');
   signal rate_con         : integer := 0;
   signal rate_dis         : integer := 0;
   signal hdr_cntr         : integer := 0;
   signal load_cntr        : integer := 0;   
   signal rate_max         : integer := 0;
   signal rate_random_cont : integer := 0;
   signal rate_time        : integer := 62500000;
   signal load_max         : integer := 0;
   signal rate_label       : std_logic := '1';
 	 signal last_rate        : integer := 0;
   signal i                : integer := 0; 
   signal ether_hdr        : t_eth_frame_header;
   signal j                : std_logic_vector(30 downto 0);
   signal s_first          : integer := 0;
   signal pkg_cntr         : integer := 0; 
   signal con_count        : integer := 0; 
   signal dis_count        : integer := 0; 
   signal con_time         : integer := 0; 
   signal dis_time         : integer := 0; 
 
   type lut1 is array ( 0 to 3) of std_logic_vector(47 downto 0);
   constant des_mac_lut : lut1 := (
   0 => x"123456789021",
   1 => x"222222222222",
   2 => x"333333333333",
   3 => x"444444444444"); 

   type lut2 is array ( 0 to 3) of std_logic_vector(15 downto 0);
   constant ether_type_lut : lut2 := (
   0 => x"1111",
   1 => x"2222",
   2 => x"0800",
   3 => x"0800"); 

Procedure configure (x: in std_logic_vector(3 downto 0):="0000"; mac_address: out std_logic_vector (47 downto 0);
							ether_type: out std_logic_vector (15 downto 0); payload_length: out std_logic_vector (15 downto 0)) is
  begin
    -- mac address from random or wb
    if (x(0) = '0') then
      mac_address(47 downto 0) := s_ctrl_reg.eth_hdr.eth_des_addr;
    else
      mac_address(47 downto 0) := des_mac_lut(i rem 4);
    end if;
    -- ether type from random(1) or wb(0)
    if (x(1) = '0') then
      ether_type(15 downto 0) := s_ctrl_reg.eth_hdr.eth_etherType;
    else
      ether_type(15 downto 0) := ether_type_lut(i rem 4); 
    end if;
    -- payload length from random(1) or wb(0)
    if (x(2) = '0') then
      payload_length(15 downto 0) := s_ctrl_reg.payload;
    else
      payload_length(15 downto 0) := x"01F6"; -- payload length is 46 to 1500
    end if;
  END PROCEDURE configure;




begin
   ether_hdr.eth_src_addr <= x"333322221111";
  -- Start/Stop fsm Packet Generator
   pg_fsm : process(clk_i)
   begin
      if rising_edge(clk_i) then
         if rst_n_i = '0' then
            s_pg_fsm <= IDLE;
            s_pg_state.gen_con_packet <= '0';
    				s_pg_state.gen_dis_packet <= '0';
            s_pg_state.halt       <= '0';
         else
             case s_pg_fsm is
               when IDLE =>
               	 -- package generator in continuous pattern  1 1 1 1 1 1
                  if( s_ctrl_reg.en_pg = '1'and s_ctrl_reg.mode = "00") then 
                     s_pg_fsm <= CONTINUOUS;
                  else
                    -- package generator in discrete pattern 111    111    111
                    if( s_ctrl_reg.en_pg = '1'and s_ctrl_reg.mode = "01") then 
                      s_pg_fsm <= DISCRETE;
                    else
                       -- package generator in continuous and discrete alternate pattern
                    	if( s_ctrl_reg.en_pg = '1'and s_ctrl_reg.mode = "10") then 
                      	s_pg_fsm <= CONTINUOUS;
                      	-- lasting time of continuous mode in alternate pattern 
                      	con_time <= 62500000;
                      	con_count<= 0;
                    	else
                      s_pg_fsm <= IDLE;
                      end if;
                    end if;
                  end if;
                     s_pg_state.gen_con_packet <= '0';
                     s_pg_state.gen_dis_packet <= '0';
                     s_pg_state.halt           <= '0';
               when CONTINUOUS =>
                  s_pg_state.new_start <= '0';
               		-- stop packet generator
                  if( s_ctrl_reg.en_pg = '0') then 
                    s_pg_fsm <= CON_HALTING;                     
                  else
                    -- switch to discrete mode
                    if( s_ctrl_reg.mode = "01") then
                      -- gaurantee a whole packet is transfered before switch to discrete mode
                      if(s_pg_state.cyc_ended = '1') then
                        s_pg_state.new_start <= '1';
                        s_pg_fsm <= DISCRETE;
                      else
                        s_pg_fsm <= CONTINUOUS;
                      end if;
                    else
                    	-- switch to the alternate pattern
                    	if( s_ctrl_reg.mode = "10") then 
                    	  -- gaurantee continuous mode run a random time before switch
                      	if con_time /= con_count then
                      		s_pg_fsm <= CONTINUOUS;
                      		con_count<= con_count + 1;
                      	else
                      		-- gaurantee a whole packet is transfered before switch to discrete mode
                      	  if(s_pg_state.cyc_ended = '1') then
                      	    s_pg_state.new_start <= '1';
                        		s_pg_fsm <= DISCRETE;
                        		dis_time <= 62500000;
                        		dis_count<= 0;
                      		else
                        	  s_pg_fsm <= CONTINUOUS;
                          end if; 
                        end if;
                      else
                      	-- continue continuous mode
                    		s_pg_fsm <= CONTINUOUS;
                    		con_time <= 62500000;
                    		con_count<= 0;
                    	end if;
                    end if;
                    s_pg_state.gen_con_packet <= '1';
                    s_pg_state.gen_dis_packet <= '0';
                    s_pg_state.halt           <= '0';
                  end if;
               when DISCRETE =>
               		-- stop packet generator
                  s_pg_state.new_start <= '0';
                  if( s_ctrl_reg.en_pg = '0') then 
                    s_pg_fsm <= DIS_HALTING;                     
                  else
                  	-- switch to continuous mode
                    if( s_ctrl_reg.mode = "00") then 
                    	-- gaurantee a whole packet is transfered before switch to continuous mode
                      if(s_pg_state.cyc_ended = '1') then
                        s_pg_state.new_start <= '1';
                        s_pg_fsm <= CONTINUOUS;
                      else
                        s_pg_fsm <= DISCRETE;
                      end if;
                    else
                    	-- switch to the alternate pattern
                    	if ( s_ctrl_reg.mode = "10") then 
                    	-- gaurantee discrete mode run a random time before switch
                    	  if dis_time /= dis_count then
                    	  	s_pg_fsm  <= DISCRETE;
                    	  	dis_count <= dis_count + 1;
                    	  else
                    	  -- gaurantee a whole packet is transfered before switch to discrete mode
                      		if(s_pg_state.cyc_ended = '1') then
                        		s_pg_fsm <= CONTINUOUS;
                        		con_time <= 62500000;
                        		con_count<= 0;
                        		s_pg_state.new_start <= '1';
                       		else
                        	  s_pg_fsm <= DISCRETE;
                          end if; 
                        end if;
                      else
                      -- continue continuous mode
                    		s_pg_fsm <= DISCRETE;
                    		dis_time <= 62500000;
                        dis_count<= 0;
                    	end if;
                    end if;
                    s_pg_state.gen_con_packet <= '0';
                    s_pg_state.gen_dis_packet <= '1';
                    s_pg_state.halt           <= '0';
                  end if;
               when CON_HALTING =>
               -- gaurantee a whole packet is transfered before stop
                  if(s_pg_state.cyc_ended = '1') then
                  	 s_pg_state.new_start <= '1';
                     s_pg_fsm <= IDLE;
                     s_pg_state.gen_con_packet <= '0';

                  else
                     s_pg_fsm <= CON_HALTING;
                     s_pg_state.gen_con_packet <= '1';
                  end if; 
                  s_pg_state.halt <= '1';
               when DIS_HALTING =>
                  if(s_pg_state.cyc_ended = '1') then
                     s_pg_state.new_start <= '1';
                     s_pg_fsm <= IDLE;
                     s_pg_state.gen_dis_packet <= '0';

                  else
                     s_pg_fsm <= DIS_HALTING;
                     s_pg_state.gen_dis_packet <= '1';
                  end if; 
                  s_pg_state.halt <= '1';
            end case;
         end if;
      end if;   
   end process;



   -- Frame Generation
   frame_gen : process(clk_i)
	variable v_mac_address		: std_logic_vector(47 downto 0);
  variable v_ether_type		: std_logic_vector(15 downto 0);
	variable v_payload_length : std_logic_vector(15 downto 0);
	
   begin
     if rising_edge(clk_i) then       
        if rst_n_i = '0' then
           s_frame_fsm          <= INIT_HDR;
           s_hdr_reg            <= (others => '0');
           s_eth_hdr            <= (others => '0');
           s_pay_load_reg       <= (others => '0');
           s_start_payload      <= '0';
           s_pg_state.cyc_ended <= '1';
           hdr_cntr             <= 0;
           load_cntr            <= 0;
           rate_con             <= 0;
           rate_dis             <= 0;
           pkg_cntr         	  <= 0;
        else
          if s_pg_state.gen_con_packet = '1' then
          --get the rate from wb or random
             if s_ctrl_reg.random_fix(3) = '0' and rate_label = '1'then
                rate_max <= to_integer (unsigned(s_ctrl_reg.rate));
                rate_random_cont <= 0;
             else
               if s_ctrl_reg.random_fix(3) = '1' and rate_label = '1' then
                 if rate_random_cont = 0 then
                   rate_max <= 31250000;
                   rate_time<= 62500000;
                   rate_random_cont <= rate_random_cont + 1;
                 else
                   rate_random_cont <= rate_random_cont + 1;
                 end if;
               end if;
             end if;

             if rate_max /= rate_con then
                case s_frame_fsm is
                  when INIT_HDR =>
                       rate_label               <= '0';
                       s_pg_state.cyc_ended     <= '0';
                       s_frame_fsm              <= ETH_HDR;
                       -- ether_hdr. eth_des_addr  <= des_mac_lut(i rem 4);
                       configure(s_ctrl_reg.random_fix,v_mac_address,v_ether_type,v_payload_length);
                       ether_hdr. eth_des_addr  <= v_mac_address;
			              ether_hdr. eth_etherType <= v_ether_type;
                       load_max                 <= to_integer(unsigned(v_payload_length));
                       s_eth_hdr         	      <= f_eth_hdr(ether_hdr);
                       s_hdr_reg              	<= f_eth_hdr(ether_hdr);
                       s_start_payload          <= '0';
                  when ETH_HDR =>
                       if hdr_cntr = c_hdr_l   then
                          s_frame_fsm           <= PAY_LOAD;
                          hdr_cntr              <= 0;                           
                          s_start_payload       <= '1';
                       else
                          s_frame_fsm           <= ETH_HDR;

                          if pg_src_i.stall /= '1' then
                             s_hdr_reg          <= s_hdr_reg(s_hdr_reg'left -16 downto 0) & x"0000";
                             hdr_cntr           <= hdr_cntr + 1;

                             if hdr_cntr = c_hdr_l - 1 then
                                s_start_payload <= '1';
                             else
                                s_start_payload <= '0';
                             end if;
                          end if;
                       end if;
                   when PAY_LOAD =>
                        if load_max = load_cntr then
                           s_frame_fsm       <= IDLE;
                           s_start_payload   <= '0';
                           s_pay_load_reg    <= (others => '0');
                           load_cntr         <= 0;
                        else
                           s_frame_fsm       <= PAY_LOAD;
                           s_start_payload   <= '1';
                           if pg_src_i.stall /= '1' then
                              load_cntr      <= load_cntr + 1;
                           end if;
                        end if;
                   when IDLE    =>
                        s_frame_fsm          <= IDLE;
                        s_pay_load_reg       <= (others => '0');
                        s_hdr_reg            <= (others => '0');
                        s_start_payload      <= '0';
                        s_pg_state.cyc_ended <= '1';
                        --gaurantee change pattern 
                        if s_pg_state.new_start = '1' then
                          s_frame_fsm        <= INIT_HDR;
                          rate_random_cont   <= 0;
								          rate_label         <= '1';
                        end if;
                 end case;
                 rate_con          <= rate_con + 1;   
               else
                 rate_con          <= 0;  --configure rate
                 s_frame_fsm       <= INIT_HDR;
                 rate_label        <= '1';
                 if rate_random_cont >= rate_time then
                   rate_random_cont <= 0;
                 end if;
               end if;
             else
               rate_con             <= 0;
             end if;
             
            -- packet generator works on the discrete mode
             if s_pg_state.gen_dis_packet = '1' then
              --get the rate from wb or random
                if s_ctrl_reg.random_fix(3) = '0'and rate_label = '1'then
                rate_max <= to_integer (unsigned(s_ctrl_reg.rate));
                  rate_random_cont <= 0;
                else
                  if s_ctrl_reg.random_fix(3) = '1' and rate_label ='1' then
                    if rate_random_cont = 0 then
                       rate_max <= 31250000;
                       rate_time<= 62500000;
                       rate_random_cont <= rate_random_cont + 1;
                    else
                      rate_random_cont <= rate_random_cont + 1;
                    end if;
                  end if;
                end if;
					 if (rate_max /= last_rate) then 
                    rate_dis       <= 62500000;
                end if;
                if rate_dis /= 62500000 then
                   case s_frame_fsm is
                     when INIT_HDR =>
                          rate_label               <= '0';
			                    s_pg_state.cyc_ended     <= '0';
			                    pkg_cntr                 <= pkg_cntr +1;
                          s_frame_fsm      	       <= ETH_HDR;
                          --configure mac, ether type, length parameters
                          configure(s_ctrl_reg.random_fix, v_mac_address, v_ether_type, v_payload_length);
                          ether_hdr. eth_des_addr  <= v_mac_address;
			                    ether_hdr. eth_etherType <= v_ether_type;
                          load_max                 <= to_integer(unsigned(v_payload_length));
                          s_eth_hdr         	     <= f_eth_hdr(ether_hdr);
                          s_hdr_reg         	     <= f_eth_hdr(ether_hdr);
                          s_start_payload   	     <= '0';
                     when ETH_HDR =>
			                    if hdr_cntr = c_hdr_l-2   then
                             s_frame_fsm     	      <= PAY_LOAD;
                             hdr_cntr        	      <= 0;                           
                             s_start_payload   	    <= '1';
                          else
                             s_frame_fsm     	      <= ETH_HDR;
  
                           if pg_src_i.stall /= '1' then
                              s_hdr_reg           <= s_hdr_reg(s_hdr_reg'left -16 downto 0) & x"0000";
                              hdr_cntr           	<= hdr_cntr + 1;

                              if hdr_cntr = c_hdr_l - 3 then
                                 s_start_payload   <= '1';
                              else
                                 s_start_payload   <= '0';
                              end if;
                              s_first <= 0;
                           else
			                        if s_first < 2 then
                                 s_hdr_reg       	<= s_hdr_reg(s_hdr_reg'left -16 downto 0) & x"0000";
		                             s_first <= s_first+1;
                              end if;
                           end if;
                        end if;
                     when PAY_LOAD =>

                        if load_max = load_cntr then
                           s_frame_fsm       <= IDLE;
                           s_start_payload   <= '0';
                           s_pay_load_reg    <= (others => '0');
                           load_cntr         <= 0;
                        else
                           s_frame_fsm       <= PAY_LOAD;
                           s_start_payload   <= '1';
                           if pg_src_i.stall /= '1' then
                              load_cntr         <= load_cntr + 1;
                           end if;
                        end if;
                     when IDLE    =>
			                  if (pkg_cntr = (1*1000000000/rate_max/16 )) then
                           s_frame_fsm     <= IDLE;
                           rate_label      <= '1';
                           if rate_random_cont >= rate_time then
                             rate_random_cont <= 0;
                           end if;

			                   else
                           s_frame_fsm     <= INIT_HDR ;
			                   end if;
                        last_rate <= rate_max;
                        s_pay_load_reg  <= (others => '0');
                        s_hdr_reg       <= (others => '0');
                        s_start_payload <= '0';
                        s_pg_state.cyc_ended <= '1';
                        --gaurantee change pattern 
                        if s_pg_state.new_start = '1' then
                          s_frame_fsm <= INIT_HDR;
                          rate_random_cont <= 0;
								  rate_label       <= '1';
                        end if;
                     end case;
                  rate_dis <= rate_dis + 1;   
               else

                  rate_dis        	<= 0;--configure rate
	                pkg_cntr    			<= 0;
                  s_frame_fsm 			<= INIT_HDR;
               end if;
            else
                  rate_dis       		<= 0;
                  pkg_cntr          <= 0;
            end if;

            if s_pg_state.gen_dis_packet = '0' and s_pg_state.gen_con_packet = '0' then
                  s_frame_fsm       <= INIT_HDR;
            end if;
         end if;
    end if;
    end process;

-- random sequence for mac address/ether type
   random_seq : LFSR_GENERIC 
   generic map(Width    => 31)
   port map(
     clock   => clk_i,
     resetn  => rst_n_i,
     random_out => j);

   i <= to_integer(unsigned(j));

   payload_gen : xgray_encoder
   generic map(g_length => 16)
   port map(
     clk_i    => clk_i,
     reset_i  => rst_n_i,
     start_i  => s_start_payload,
     stall_i  => pg_src_i.stall,
     enc_o    => s_pay_load);

   ----- Fabric Interface
   -- Mux between header and payload
   with s_frame_fsm select
   pg_src_o.dat   <= s_pay_load                                            when PAY_LOAD,
                     s_hdr_reg(s_hdr_reg'left downto s_hdr_reg'left - 15)  when ETH_HDR,
                     (others => '0')                                       when others;
   

   pg_src_o.cyc   <= '1' when ( s_frame_fsm = ETH_HDR or s_frame_fsm = PAY_LOAD ) else '0';
   pg_src_o.stb   <= '1' when ( s_frame_fsm = ETH_HDR or s_frame_fsm = PAY_LOAD ) else '0';
   pg_src_o.adr   <= c_WRF_DATA;
   pg_src_o.we    <= '1';
   pg_src_o.sel   <= "11";

   -- WB Register Ctrl/Stat
   ctrl_stat_reg :  process(clk_i)
   begin
     if rising_edge(clk_i) then
       if rst_n_i = '0' then
   	     s_ctrl_reg <= c_pg_ctrl_default;
         s_frame_gen <= 0;
       else
         s_ctrl_reg            <= ctrl_reg_i;
         stat_reg_o.frame_gen  <= std_logic_vector(to_unsigned(s_frame_gen,32));
       end if;
     end if;
   end process;

end rtl;
