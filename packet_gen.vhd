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
   signal s_rate_con         : integer := 0;
   signal s_rate_dis         : integer := 62500000;
   signal s_hdr_cntr         : integer := 0;
   signal s_load_cntr        : integer := 0;   
   signal s_rate_max         : integer := 0;
   signal s_rate_random_cont : integer := 0;
   signal s_rate_time        : integer := 62500000;
   signal s_load_max         : integer := 0;
   signal s_rate_label       : std_logic := '1';
   signal s_old_rate         : integer := 0;
   signal s_random_seq       : integer := 0; 
   signal s_ether_hdr        : t_eth_frame_header;
   signal s_random_seq_o     : std_logic_vector(31 downto 0);
   signal s_first            : integer := 0;
   signal s_pkg_cntr         : integer := 0; 
   signal s_con_count        : integer := 0; 
   signal s_dis_count        : integer := 0; 
   signal s_con_time         : integer := 0; 
   signal s_dis_time         : integer := 0; 
	signal i                  : integer;

 
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
   2 => x"3333",
   3 => x"4444"); 

Procedure rdm_fix_cfg (x: in std_logic_vector(3 downto 0):="0000"; mac_address: out std_logic_vector (47 downto 0);
							ether_type: out std_logic_vector (15 downto 0); payload_length: out integer) is
	 begin

    -- mac address from random or wb
    if (x(0) = '0') then
      mac_address(47 downto 0) := s_ctrl_reg.eth_hdr.eth_des_addr;
    else
      mac_address(47 downto 0) := des_mac_lut(s_random_seq rem 4);
    end if;
    -- ether type from random(1) or wb(0)
    if (x(1) = '0') then
      ether_type(15 downto 0) := s_ctrl_reg.eth_hdr.eth_etherType;
    else
      ether_type(15 downto 0) := ether_type_lut(s_random_seq rem 4); 
    end if;
    -- payload length from random(1) or wb(0)
    if (x(2) = '0') then
      payload_length := to_integer(unsigned(s_ctrl_reg.payload));	
    else
      payload_length := to_integer((unsigned(s_random_seq_o and x"00000fff")) rem 1455 + 46); -- payload length is 46 to 1500
    end if;
  END PROCEDURE rdm_fix_cfg;




begin
   s_ether_hdr.eth_src_addr <= x"333322221111";
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
                      	s_con_time <= 62500000 + (s_random_seq rem 250000001);
                      	s_con_count<= 0;
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
                      	if s_con_time /= s_con_count then
                      		s_pg_fsm <= CONTINUOUS;
                      		s_con_count<= s_con_count + 1;
                      	else
                      		-- gaurantee a whole packet is transfered before switch to discrete mode
                      	  if(s_pg_state.cyc_ended = '1') then
                      	    s_pg_state.new_start <= '1';
                        		s_pg_fsm <= DISCRETE;
                        		s_dis_time <= 312500000 + (s_random_seq rem 312500001);
                        		s_dis_count<= 0;
                      		else
                        	  s_pg_fsm <= CONTINUOUS;
                          end if; 
                        end if;
                      else
                      	-- continue continuous mode
                    		s_pg_fsm <= CONTINUOUS;
                    		s_con_time <= 62500000+ (s_random_seq rem 250000001);
                    		s_con_count<= 0;
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
                    	  if s_dis_time /= s_dis_count then
                    	  	s_pg_fsm  <= DISCRETE;
                    	  	s_dis_count <= s_dis_count + 1;
                    	  else
                    	  -- gaurantee a whole packet is transfered before switch to discrete mode
                      		if(s_pg_state.cyc_ended = '1') then
                        		s_pg_fsm <= CONTINUOUS;
                        		s_con_time <= 62500000+ (s_random_seq rem 250000001);
                        		s_con_count<= 0;
                        		s_pg_state.new_start <= '1';
                       		else
                        	  s_pg_fsm <= DISCRETE;
                          end if; 
                        end if;
                      else
                      -- continue continuous mode
                    		s_pg_fsm <= DISCRETE;
                    		s_dis_time <= 312500000 + (s_random_seq rem 312500001);
                        s_dis_count<= 0;
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
	variable v_payload_length  : integer;

	
   begin
     if rising_edge(clk_i) then       
        if rst_n_i = '0' then
           s_frame_fsm          <= INIT_HDR;
           s_hdr_reg            <= (others => '0');
           s_eth_hdr            <= (others => '0');
           s_pay_load_reg       <= (others => '0');
           s_start_payload      <= '0';
           s_pg_state.cyc_ended <= '1';
           s_hdr_cntr             <= 0;
           s_load_cntr            <= 0;
           s_rate_con             <= 0;
           s_rate_dis             <= 0;
           s_pkg_cntr         	  <= 0;
        else
          if s_pg_state.gen_con_packet = '1' then
            s_old_rate <= 0;
          --get the rate from wb or random
             if s_ctrl_reg.random_fix(3) = '0' and s_rate_label = '1'then
                s_rate_max <= to_integer (unsigned(s_ctrl_reg.rate));
                s_rate_random_cont <= 0;
             else
               if s_ctrl_reg.random_fix(3) = '1' and s_rate_label = '1' then
				      	--gaurantee the runing time for a random rate value
                 if s_rate_random_cont = 0 then
                   s_rate_max <= to_integer((unsigned(s_random_seq_o and x"0fffffff")) rem 62499201 + 800);
                   s_rate_time<= to_integer(unsigned(s_ctrl_reg.random_rate_time));
                   s_rate_random_cont <= s_rate_random_cont + 1;
                 else
                   s_rate_random_cont <= s_rate_random_cont + 1;
                 end if;
               else
                   s_rate_random_cont <= s_rate_random_cont + 1;
               end if;
             end if;

             if s_rate_max /= s_rate_con then
                case s_frame_fsm is
                  when INIT_HDR =>
                       s_rate_label               <= '0';
                       s_pg_state.cyc_ended     <= '0';
                       s_frame_fsm              <= ETH_HDR;
                       -- s_ether_hdr. eth_des_addr  <= des_mac_lut(i rem 4);
                       rdm_fix_cfg(s_ctrl_reg.random_fix,v_mac_address,v_ether_type,v_payload_length);
                       s_ether_hdr. eth_des_addr  <= v_mac_address;
			              s_ether_hdr. eth_etherType <= v_ether_type;
                       s_load_max                 <= v_payload_length;
							  s_load_cntr                <= 0;
                       s_eth_hdr         	      <= f_eth_hdr(s_ether_hdr);
                       s_hdr_reg              	<= f_eth_hdr(s_ether_hdr);
                       s_start_payload          <= '0';
                  when ETH_HDR =>
						--transfer the ether header 6+6+2 bytes
                       if s_hdr_cntr = c_hdr_l   then
                          s_frame_fsm           <= PAY_LOAD;
                          s_hdr_cntr              <= 0;                           
                          s_start_payload       <= '1';
                       else
                          s_frame_fsm           <= ETH_HDR;

                          if pg_src_i.stall /= '1' then
                             s_hdr_reg          <= s_hdr_reg(s_hdr_reg'left -16 downto 0) & x"0000";
                             s_hdr_cntr           <= s_hdr_cntr + 1;

                             if s_hdr_cntr = c_hdr_l - 1 then
                                s_start_payload <= '1';
                             else
                                s_start_payload <= '0';
                             end if;
                          end if;
                       end if;
                   when PAY_LOAD =>
						 --transfer the payload, payload length is decided by s_load_max
                        if s_load_max = s_load_cntr then
                           s_frame_fsm       <= IDLE;
                           s_start_payload   <= '0';
                           s_pay_load_reg    <= (others => '0');
                           s_load_cntr         <= 0;
                        else
                           s_frame_fsm       <= PAY_LOAD;
                           s_start_payload   <= '1';
                           if pg_src_i.stall /= '1' then
                              s_load_cntr      <= s_load_cntr + 1;
                           end if;
                        end if;
                   when IDLE    =>
						 -- IDLE = s_rate_max - 1[Init header]- (6+6+2)/2[Ether header] - s_load_max/2[payload] 
                        s_frame_fsm          <= IDLE;
                        s_pay_load_reg       <= (others => '0');
                        s_hdr_reg            <= (others => '0');
                        s_start_payload      <= '0';
                        s_pg_state.cyc_ended <= '1';
                        --gaurantee change pattern 
                        if s_pg_state.new_start = '1' then
                          s_frame_fsm        <= INIT_HDR;
                          s_rate_random_cont   <= 0;
								          s_rate_label         <= '1';
                        end if;
                 end case;
                 s_rate_con          <= s_rate_con + 1;   
               else
					-- go back to INIT_HDR after one cycle= rate_max * 16ns
                 s_rate_con          <= 0;  
                 s_frame_fsm       <= INIT_HDR;
                 s_rate_label        <= '1';
                 if s_rate_random_cont >= s_rate_time then
                   s_rate_random_cont <= 0;
                 end if;
               end if;
             else
               s_rate_con             <= 0;
             end if;
             
            -- packet generator works on the discrete mode
             if s_pg_state.gen_dis_packet = '1' then
              --get the rate from wb or random
                if s_ctrl_reg.random_fix(3) = '0'and s_rate_label = '1'then
                  s_rate_max <= to_integer (unsigned(s_ctrl_reg.rate));
                  s_rate_random_cont <= 0;
                else
                  if s_ctrl_reg.random_fix(3) = '1' and s_rate_label ='1' then
                    if s_rate_random_cont = 0 then
                       s_rate_max         <= to_integer((unsigned(s_random_seq_o and x"0fffffff")) rem 62499201 + 800);
                       s_rate_time        <= to_integer(unsigned(s_ctrl_reg.random_rate_time));
                       s_rate_random_cont <= s_rate_random_cont + 1;
                    else
                      s_rate_random_cont <= s_rate_random_cont + 1;
                    end if;
                  else
                      s_rate_random_cont <= s_rate_random_cont + 1;
                  end if;
                end if;

                if s_rate_dis /= 62500000 then
                   case s_frame_fsm is
                     when INIT_HDR =>
                          s_rate_label               <= '0';
			                    s_pg_state.cyc_ended       <= '0';
			                    s_pkg_cntr                 <= s_pkg_cntr +1;
                          s_frame_fsm      	         <= ETH_HDR;
                          --configure mac, ether type, length parameters
                          rdm_fix_cfg(s_ctrl_reg.random_fix, v_mac_address, v_ether_type, v_payload_length);
                          s_ether_hdr. eth_des_addr  <= v_mac_address;
			                    s_ether_hdr. eth_etherType <= v_ether_type;
                          s_load_max                 <= v_payload_length;
								          s_eth_hdr         	     <= f_eth_hdr(s_ether_hdr);
                          s_hdr_reg         	     <= f_eth_hdr(s_ether_hdr);
                          s_start_payload   	     <= '0';
                     when ETH_HDR =>
			                    if s_hdr_cntr = c_hdr_l-2   then
                             s_frame_fsm     	      <= PAY_LOAD;
                             s_hdr_cntr             <= 0;                           
                             s_start_payload   	    <= '1';
                          else
                             s_frame_fsm     	      <= ETH_HDR;
  
                           if pg_src_i.stall /= '1' then
                              s_hdr_reg           <= s_hdr_reg(s_hdr_reg'left -16 downto 0) & x"0000";
                              s_hdr_cntr           	<= s_hdr_cntr + 1;

                              if s_hdr_cntr = c_hdr_l - 3 then
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

                        if s_load_max = s_load_cntr then
                           s_frame_fsm       <= IDLE;
                           s_start_payload   <= '0';
                           s_pay_load_reg    <= (others => '0');
                           s_load_cntr         <= 0;
                        else
                           s_frame_fsm       <= PAY_LOAD;
                           s_start_payload   <= '1';
                           if pg_src_i.stall /= '1' then
                              s_load_cntr         <= s_load_cntr + 1;
                           end if;
                        end if;
                     when IDLE    =>
							--judge whether the number of packet reaches to the rate requirement
			                  if (s_pkg_cntr * s_rate_max >= 62500000 ) then
                           s_frame_fsm     <= IDLE;
                           s_rate_label      <= '1';
                           if s_rate_random_cont >= s_rate_time then
                             s_rate_random_cont <= 0;
                           end if;

			                   else
                           s_frame_fsm     <= INIT_HDR ;
			                   end if;
                        s_pay_load_reg  <= (others => '0');
                        s_hdr_reg       <= (others => '0');
                        s_start_payload <= '0';
                        s_pg_state.cyc_ended <= '1';
                        --gaurantee change pattern 
                        if s_pg_state.new_start = '1' then
                          s_frame_fsm <= INIT_HDR;
                          s_rate_random_cont <= 0;
								          s_rate_label       <= '1';
                        end if;
                     end case;
                    -- if s_rate_random_cont = 0 then
                    --   s_rate_dis <= 62500000;
                    if s_rate_max /= s_old_rate then
                      s_rate_dis <= 62500000;
                     else
                       s_rate_dis <= s_rate_dis + 1;   
                     end if;
               else
                  s_old_rate          <= s_rate_max;
                  s_rate_dis        	<= 0;--configure rate
	                s_pkg_cntr    			<= 0;
                  s_frame_fsm 			<= INIT_HDR;
               end if;
            else
                  s_rate_dis       		<= 0;
                  s_pkg_cntr          <= 0;
            end if;

            if s_pg_state.gen_dis_packet = '0' and s_pg_state.gen_con_packet = '0' then
                  s_frame_fsm       <= INIT_HDR;
            end if;
         end if;
    end if;
    end process;

-- random sequence for mac address/ether type
   Random_seq : LFSR_GENERIC 
   generic map(Width    => 32)
   port map(
     clock      => clk_i,
     resetn     => rst_n_i,
     random_out => s_random_seq_o);

   s_random_seq <= to_integer(unsigned(s_random_seq_o));

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
