library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.wishbone_pkg.all;
use work.wr_fabric_pkg.all;
use work.fec_pkg.all;
use work.gray_pack.all;

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
  -- signal eth_hdr          : t_eth_frame_header;

   type lut is array ( 0 to 3) of std_logic_vector(111 downto 0);
   constant my_lut : lut := (
   0 => x"1111111111110000222200000000",
   1 => x"2222222222220000333300000000",
   2 => x"3333333333334444555522226666",
   3 => x"4444444444440000000000002222"); 

   type lut1 is array ( 0 to 3) of std_logic_vector(47 downto 0);
   constant des_mac_lut : lut1 := (
   0 => x"111111111111",
   1 => x"222222222222",
   2 => x"333333333333",
   3 => x"444444444444"); 

   type lut2 is array ( 0 to 3) of std_logic_vector(15 downto 0);
   constant ether_type_lut : lut2 := (
   0 => x"2222",
   1 => x"3333",
   2 => x"4444",
   3 => x"5555"); 


begin

  -- Start/Stop fsm Packet Generator
   pg_fsm : process(clk_i)
   begin
      if rising_edge(clk_i) then
         if rst_n_i = '0' then
            s_pg_fsm <= IDLE;
            s_pg_state.gen_packet <= '0';
            s_pg_state.halt       <= '0';
         else
            case s_pg_fsm is
               when IDLE =>
                  if( s_ctrl_reg.en_pg = '1') then 
                     s_pg_fsm <= GENERATING;
                  else
                     s_pg_fsm <= IDLE;
                  end if;
                     s_pg_state.gen_packet <= '0';
                     s_pg_state.halt       <= '0';
               when GENERATING =>
                  if( s_ctrl_reg.en_pg = '0') then 
                     s_pg_fsm <= HALTING;                     
                  else
                     s_pg_fsm <= GENERATING;
                  end if;
                     s_pg_state.gen_packet <= '1';
                     s_pg_state.halt       <= '0';
               when HALTING =>
                  if(s_pg_state.cyc_ended = '1') then
                     s_pg_fsm <= IDLE;
                     s_pg_state.gen_packet <= '0';
                  else
                     s_pg_fsm <= HALTING;
                     s_pg_state.gen_packet <= '1';
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
        else
            if s_pg_state.gen_packet = '1'  then
               if rate_max /= rate then
   		  --s_ctrl_reg.eth_hdr.eth_des_addr   <= my_lut(i);
                  case s_frame_fsm is
                     when INIT_HDR =>
                        i <= 0;
                        s_frame_fsm       <= ETH_HDR;
                        ----s_eth_hdr         <= f_eth_hdr(s_ctrl_reg.eth_hdr);
                        --eth_hdr. eth_des_addr <= des_mac_lut(i);
			--eth_hdr. eth_des_addr <= des_mac_lut(i);
 			s_eth_hdr         <= my_lut(i);
			--s_eth_hdr         <= x"1212121212123434565656565656";--des mac+ 0000+ether type+0000 
                        --s_hdr_reg         <= f_eth_hdr(s_ctrl_reg.eth_hdr);
			s_hdr_reg         <= my_lut(i);
			--s_hdr_reg         <= x"1212121212123434565656565656";
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

                        if s_pg_state.halt = '1' then
                           s_pg_state.cyc_ended <= '1';
                        end if;
                     end case;
                  rate <= rate + 1;   
               else
		  i <= (i+1) rem 4;
                  rate        <= 0;
                  s_hdr_reg   <= my_lut(i);
                  s_frame_fsm <= ETH_HDR;
               end if;
            else
                  s_frame_fsm <= INIT_HDR;
            end if;
         end if;
      end if;
    end process;

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
