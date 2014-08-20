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
   signal rate             : integer := 0;
   signal hdr_cntr         : integer := 0;
   signal load_cntr        : integer := 0;   
   signal rate_max         : integer := 0;
   signal load_max         : integer := 0;
   signal i                : integer := 0;
   signal ether_hdr        : t_eth_frame_header;
   signal j                : std_logic_vector(30 downto 0);
   signal s_first          : integer := 0;
   signal pkg_cntr         : integer := 0; 
 
   type lut1 is array ( 0 to 3) of std_logic_vector(47 downto 0);
   constant des_mac_lut : lut1 := (
   0 => x"123456789021",
   1 => x"222222222222",
   2 => x"333333333333",
   3 => x"444444444444"); 

   type lut2 is array ( 0 to 3) of std_logic_vector(15 downto 0);
   constant ether_type_lut : lut2 := (
   0 => x"0800",
   1 => x"0800",
   2 => x"0800",
   3 => x"0800"); 


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
                  if( s_ctrl_reg.en_pg = '1'and s_ctrl_reg.mode = '0') then 
                     s_pg_fsm <= CONTINUOUS;
                  else
                    if( s_ctrl_reg.en_pg = '1'and s_ctrl_reg.mode = '1') then 
                      s_pg_fsm <= DISCRETE;
                    else
                      s_pg_fsm <= IDLE;
                    end if;
                  end if;
                     s_pg_state.gen_con_packet <= '0';
                     s_pg_state.gen_dis_packet <= '0';
                     s_pg_state.halt           <= '0';
               when CONTINUOUS =>
                  if( s_ctrl_reg.en_pg = '0') then 
                    s_pg_fsm <= CON_HALTING;                     
                  else
                    if( s_ctrl_reg.mode = '1') then 
                      if(s_pg_state.cyc_ended = '1') then
                        s_pg_fsm <= DISCRETE;
                      else
                        s_pg_fsm <= CONTINUOUS;
                      end if;
                    else
                    s_pg_fsm <= CONTINUOUS;
                    end if;
                  end if;
                    s_pg_state.gen_con_packet <= '1';
                    s_pg_state.gen_dis_packet <= '0';
                    s_pg_state.halt       <= '0';
               when DISCRETE =>
                  if( s_ctrl_reg.en_pg = '0') then 
                    s_pg_fsm <= DIS_HALTING;                     
                  else
                    if( s_ctrl_reg.mode = '0') then 
                      if(s_pg_state.cyc_ended = '1') then
                        s_pg_fsm <= CONTINUOUS;
                      else
                        s_pg_fsm <= DISCRETE;
                      end if;
                    else
                    s_pg_fsm <= DISCRETE;
                    end if;
                  end if;
                    s_pg_state.gen_con_packet <= '0';
                    s_pg_state.gen_dis_packet <= '1';
                    s_pg_state.halt       <= '0';
               when CON_HALTING =>
                  if(s_pg_state.cyc_ended = '1') then
                     s_pg_fsm <= IDLE;
                     s_pg_state.gen_con_packet <= '0';

                  else
                     s_pg_fsm <= CON_HALTING;
                     s_pg_state.gen_con_packet <= '1';
                  end if; 
                  s_pg_state.halt <= '1';
               when DIS_HALTING =>
                  if(s_pg_state.cyc_ended = '1') then
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

   rate_max <= to_integer(unsigned(s_ctrl_reg.rate));
   load_max <= to_integer(unsigned(s_ctrl_reg.payload));

   -- Frame Generation
   frame_gen : process(clk_i)

   begin
      if rising_edge(clk_i) then       
         if rst_n_i = '0' then
            s_frame_fsm          <= INIT_HDR;
            s_hdr_reg            <= (others => '0');
            s_eth_hdr            <= (others => '0');
            s_pay_load_reg       <= (others => '0');
            s_start_payload      <= '0';
            s_pg_state.cyc_ended <= '0';
            hdr_cntr             <= 0;
            load_cntr            <= 0;
            rate                 <= 0;
      	    pkg_cntr 		 <= 0;
        else
           if s_pg_state.gen_con_packet = '1' then
               if rate_max /= rate then
                  case s_frame_fsm is
                     when INIT_HDR =>
                        s_pg_state.cyc_ended <= '0';
                        s_frame_fsm       <= ETH_HDR;
                        ether_hdr. eth_des_addr <= des_mac_lut(i rem 4);
			                  ether_hdr. eth_etherType <= ether_type_lut(i rem 4 );
                        s_eth_hdr         	<= f_eth_hdr(ether_hdr);
                        s_hdr_reg         	<= f_eth_hdr(ether_hdr);
                        s_start_payload   <= '0';
                     when ETH_HDR =>
                        if hdr_cntr = c_hdr_l   then
                           s_frame_fsm     <= PAY_LOAD;
                           hdr_cntr        <= 0;                           
                           s_start_payload   <= '1';
                       else
                           s_frame_fsm     <= ETH_HDR;

                           if pg_src_i.stall /= '1' then
                              s_hdr_reg       <= s_hdr_reg(s_hdr_reg'left -16 downto 0) & x"0000";
                              hdr_cntr        <= hdr_cntr + 1;

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
                              load_cntr         <= load_cntr + 1;
                           end if;
                        end if;
                     when IDLE    =>
                        s_frame_fsm     <= IDLE;
                        s_pay_load_reg  <= (others => '0');
                        s_hdr_reg       <= (others => '0');
                        s_start_payload <= '0';

                        s_pg_state.cyc_ended <= '1';

                     end case;
                  rate <= rate + 1;   
               else
                  rate        <= 0;
                  s_frame_fsm <= INIT_HDR;
               end if;
  
            else
              if s_pg_state.gen_dis_packet = '1' then
                if rate /= 62500000 then
                  case s_frame_fsm is
                    when INIT_HDR =>
			                s_pg_state.cyc_ended <= '0';
			                pkg_cntr <= pkg_cntr +1;
                      s_frame_fsm      	<= ETH_HDR;
                      ether_hdr. eth_des_addr <= des_mac_lut(i rem 4);
			                ether_hdr. eth_etherType <= ether_type_lut(i rem 4 );
                      s_eth_hdr         	<= f_eth_hdr(ether_hdr);
                      s_hdr_reg         	<= f_eth_hdr(ether_hdr);
                      s_start_payload   	<= '0';
                    when ETH_HDR =>
			                if hdr_cntr = c_hdr_l-2   then
                        s_frame_fsm     	<= PAY_LOAD;
                        hdr_cntr        	<= 0;                           
                        s_start_payload   	<= '1';
                      else
                        s_frame_fsm     	<= ETH_HDR;

                           if pg_src_i.stall /= '1' then
                              s_hdr_reg       	<= s_hdr_reg(s_hdr_reg'left -16 downto 0) & x"0000";
                              hdr_cntr       	<= hdr_cntr + 1;

                              if hdr_cntr = c_hdr_l - 3 then
                                 s_start_payload <= '1';
                              else
                                 s_start_payload <= '0';
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
			                   else
                           s_frame_fsm     <= INIT_HDR ;
			                   end if;
                        s_pay_load_reg  <= (others => '0');
                        s_hdr_reg       <= (others => '0');
                        s_start_payload <= '0';
                        s_pg_state.cyc_ended <= '1';

                     end case;
                  rate <= rate + 1;   
               else

                  rate        			<= 0;
	          pkg_cntr 			<= 0;
                  s_frame_fsm 			<= INIT_HDR;
               end if;
            else
                  s_frame_fsm <= INIT_HDR;
            end if;
         end if;
      end if;
    end if;
    end process;

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
