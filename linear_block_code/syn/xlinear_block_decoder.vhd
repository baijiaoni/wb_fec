library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.wishbone_pkg.all;
use work.circular_buff_pkg.all;
use work.linear_block_pkg.all;
use work.wr_fabric_pkg.all;

entity xlinear_block_decoder is
  port(
    clk_i         : in  std_logic;
    clk_fast_i    : in  std_logic;
    rstn_i        : in  std_logic;
    load_i        : in  std_logic;
    data_i        : in  std_logic_vector(15 downto 0);
    lc_dec_stat   : out lc_stat;
    wb_lb_slave_i : in  t_wishbone_slave_in;
    wb_lb_slave_o : out t_wishbone_slave_out);
end xlinear_block_decoder;

architecture rtl of xlinear_block_decoder is
  
  signal s_done_dec : std_logic_vector(3 downto 0)  := (others => '0');
  signal s_err_dec  : std_logic_vector(3 downto 0)  := (others => '0');
  signal s_wb_err_dec  : std_logic;
  signal s_load     : std_logic_vector(3 downto 0)  := (others => '0');
  signal s_load_data: std_logic := '0';
  signal s_load_wb  : std_logic := '0';
  type t_lc_dec_stat  is array (3 downto 0) of lc_stat;
  signal s_lc_dec_stat : t_lc_dec_stat;

  constant ones : unsigned(7 downto 0) := "00000001";

  signal s_data     : std_logic_vector(23 downto 0) := (others => '0');
  type   t_deco is array (3 downto 0) of std_logic_vector(11 downto 0);
  signal s_deco  : t_deco;

  signal s_buffer : std_logic_vector(15 downto 0) := (others => '0');
  signal s_deco_shovel  : std_logic_vector(23 downto 0) := (others => '0');
  signal s_testing_o  : std_logic_vector(23 downto 0) := (others => '0');

  type t_deco_buffer is array (1 downto 0) of std_logic_vector(95 downto 0);
  signal s_deco_buffer  : t_deco_buffer;
  signal s_deco_buffer_tmp  : std_logic_vector(95 downto 0);

  type t_deco_block is array (1 downto 0) of std_logic_vector(8 downto 1);
  signal s_deco_block  : t_deco_block;



  signal buf_idx      : std_logic_vector(0 downto 0) := "0";

  signal s_slot_free : integer := 0;
  signal s_slot_pre  : integer := 0;

  type t_deco_slot  is array (3 downto 0) of integer range 1 to 8; 
  signal s_deco_slot : t_deco_slot;

  signal s_cntr_deco_slot : integer range 1 to 8;

  type t_fsm_16to24 is (LOAD, EVEN_LOAD, ODD_LOAD, HALT_LOAD);
  signal fsm_16to24  : t_fsm_16to24;
  
  signal s_full_slot_buff : std_logic;
  signal s_empty_slot_buff : std_logic;
  
begin

  fabric2decoder : process(clk_i)
  begin

    if rising_edge(clk_i) then
      if rstn_i = '0' then
        s_buffer    <= (others => '0');
        s_load_data <= '0';
        fsm_16to24  <= LOAD;
      else

        if load_i = '1' then
          s_buffer    <= data_i;
        end if;

        case fsm_16to24 is
          when LOAD =>
            if load_i = '1' then
              fsm_16to24  <= EVEN_LOAD;
            end if;
            s_load_data <= '0';
          when EVEN_LOAD =>              
            if load_i = '1' then            
              s_buffer(15 downto 8) <= data_i(7 downto 0);
              s_deco_shovel         <= s_buffer & data_i(15 downto 8);
              fsm_16to24            <= ODD_LOAD;
              s_load_data           <= '1';
            else
              fsm_16to24            <= LOAD;
              s_load_data           <= '0';
            end if;
          when ODD_LOAD =>
            if load_i = '1' then
              s_deco_shovel <= s_buffer(15 downto 8) & data_i;
              fsm_16to24    <= LOAD;
              s_load_data   <= '1';
            else
              fsm_16to24    <= HALT_LOAD;
              s_load_data   <= '0';
            end if;
          when HALT_LOAD =>            
            if load_i = '1' then
            s_buffer(15 downto 8) <= s_buffer(7 downto 0);
              fsm_16to24    <= ODD_LOAD;
            end if;
        end case;
      end if;
    end if;
  end process;

  distributor : process(clk_i)
    variable upper : integer;
    variable lower : integer;
    variable v_buf_idx : integer := 0;
    variable v_deco_block  : t_deco_block := (others => (others => '0'));
  begin

    if rising_edge(clk_i) then
      if rstn_i = '0' then
        --s_slot_free   <= 0;
        --s_slot_pre    <= 3;
        s_data        <= (others => '0');
        s_deco_block  <= (others => (others => '0'));
        s_deco_buffer <= (others => (others => '0'));
        buf_idx(0 downto 0) <= "0";
        --s_deco_buffer_tmp <= (others => '0');
        --s_done_dec    <= (others => '0');

      else          
        -- loading the decoders 16bit to 24 bit
        if s_load_data = '1' then
          s_data              <=  s_deco_shovel;

          -- counter
          if s_cntr_deco_slot /= 8 then
            s_cntr_deco_slot  <= s_cntr_deco_slot + 1;
          else
            s_cntr_deco_slot  <= 1;
          end if;

          -- decoded slot assignment
          s_deco_slot(s_slot_free)  <= s_cntr_deco_slot;

          -- s_load pulse
          s_load(s_slot_free) <= '1';
          s_slot_pre <= s_slot_free;

        end if;
        -- negates previous load pulse 
        s_load(s_slot_pre)  <= '0';
 
        -- decoder just finished, next decoder free
        --for i in 0 to c_num_decoders-1 loop
        --  if s_done_dec(i) = '1' or s_err_dec(i) = '1' then
        --    free <= free + 1;
        --  end if;
        --end loop;

        --if s_load_data = '1' then
        --  s_next <= s_next + 1;
        --end if;

        -- gathering from decoders 12 bits outputs to 96 bit buffer (3 x wb 32bits) 


        v_deco_block  := (others => (others => '0'));

        for k in 0 to c_num_decoders-1 loop
          if s_done_dec(k) = '1' then
            upper := (12 * s_deco_slot(k)) - 1;
            lower := 12 * (s_deco_slot(k)  - 1);

            v_buf_idx := to_integer(unsigned(buf_idx));

            if s_deco_block(v_buf_idx)(s_deco_slot(k)) = '1' then 
              v_buf_idx := to_integer(unsigned(not buf_idx));
            end if;
            
            v_deco_block(v_buf_idx) := std_logic_vector(unsigned(v_deco_block(v_buf_idx)) xor 
                                       (ones sll s_deco_slot(k)-1));
            s_deco_buffer(v_buf_idx)(upper downto lower) <= s_deco(k);              

          end if;
        end loop;

        s_deco_block(to_integer(unsigned(buf_idx))) <= v_deco_block(to_integer(unsigned(buf_idx)))
                                                       xor s_deco_block(to_integer(unsigned(buf_idx)));
        s_deco_block(to_integer(unsigned(not buf_idx))) <= v_deco_block(to_integer(unsigned(not buf_idx)))
                                                       xor s_deco_block(to_integer(unsigned(not buf_idx)));
        
        -- when the buffer is full the buffer goes to the wb module
        if s_deco_block(v_buf_idx) = x"FF" then -- the 96 bits buffer is ready
          buf_idx <= std_logic_vector(unsigned(buf_idx)+1);
          s_load_wb   <= '1';
          s_deco_block(v_buf_idx)  <= x"00";
          s_deco_buffer(v_buf_idx) <= (others => '0');
          s_deco_buffer_tmp <= s_deco_buffer(v_buf_idx);
        else
          s_load_wb   <= '0';
        end if;
      end if;
    end if;
  end process;


  slot_free : circular_buff
    port map(
      clk_i   => clk_i,  
      rstn_i  => rstn_i,
      full_o  => s_full_slot_buff,
      empty_o => s_empty_slot_buff,
      push_i  => s_done_dec,
      pop_i   => s_load_data,
      data_o  => s_slot_free);

  deco2wb : wb_slave_deco
    port map(
      clk_i         => clk_i,
      rstn_i        => rstn_i,
      load_i        => s_load_wb,
      error_i       => s_wb_err_dec,
      buffer2wb_i   => s_deco_buffer_tmp,
      wb_slave_o    => wb_lb_slave_o,
      wb_slave_i    => wb_lb_slave_i);

  s_wb_err_dec <= s_err_dec(0) or s_err_dec(1) or s_err_dec(2) or s_err_dec(3);
  
  gen_lb_decoder : for l in 0 to c_num_decoders-1 generate
  lb_decoder : linear_block_decoder 
    port map (
      clk_i       => clk_fast_i,
      rstn_i      => rstn_i, 
      load_i      => s_load(l),
      data_i      => s_data,
      decoded_o   => s_deco(l),
      dec_stat_o  => s_lc_dec_stat(l),
      err_dec_o   => s_err_dec(l),
      done_dec_o  => s_done_dec(l));
  end generate;

end rtl;
