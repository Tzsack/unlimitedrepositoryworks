library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.vga_package.all;

-- TODO aggiungere bound sulle coordinate

entity VGA_Framebuffer is
	generic
	(
		SCREEN_WIDTH        : positive := 512;
		SCREEN_HEIGHT       : positive := 480;
		COLOR_DEPTH         : positive := 12
	);
	port
	(
		CLOCK               : in    std_logic;
		RESET_N             : in    std_logic;

		-- Commands
		CLEAR               : in    std_logic;
		DRAW_RECT           : in    std_logic;
		DRAW_LINE           : in    std_logic;
		FILL_RECT           : in    std_logic;
		FLIP                : in    std_logic;

		
		-- Commands parameters
		COLOR               : in    color_type;
		X0                  : in    xy_coord_type;
		Y0                  : in    xy_coord_type;
		X1                  : in    xy_coord_type;
		Y1                  : in    xy_coord_type;
		
		-- Outputs		
		READY               : out   std_logic;
		VGA_R               : out   std_logic_vector(3 downto 0);
		VGA_G               : out   std_logic_vector(3 downto 0);
		VGA_B               : out   std_logic_vector(3 downto 0);
		VGA_HS              : out   std_logic;
		VGA_VS              : out   std_logic;
		
		SRAM_ADDR           : out   std_logic_vector(17 downto 0);
		SRAM_DQ             : inout std_logic_vector(15 downto 0);
		SRAM_CE_N           : out   std_logic;
		SRAM_OE_N           : out   std_logic;
		SRAM_WE_N           : out   std_logic;
		SRAM_UB_N           : out   std_logic;
		SRAM_LB_N           : out   std_logic
	);

end;


architecture RTL of VGA_Framebuffer is
	type   state_type       is (IDLE, DRAWING_RECT, FILLING_RECT, DRAWING_LINE);
	type   substate_type    is (INIT, DRAWING, DRAWING_R1, DRAWING_R2);
	signal state            : state_type;
	signal substate         : substate_type;
	
	signal vga_blank        : std_logic;
	signal vga_strobe       : std_logic;
	signal vga_x            : std_logic_vector(10 downto 0);
	signal vga_y            : std_logic_vector(10 downto 0);
	signal vga_vsync        : std_logic;
	
	signal fb_buffer_idx    : std_logic;
	signal fb_wr_req        : std_logic;
	signal fb_wr_ack        : std_logic;
	signal fb_wr_x          : std_logic_vector(10 downto 0);
	signal fb_wr_y          : std_logic_vector(10 downto 0);
	signal fb_wr_color      : std_logic_vector(COLOR_DEPTH-1 downto 0);
	
	signal fb_rd_req        : std_logic;
	signal fb_rd_ack        : std_logic;
	signal fb_rd_x          : std_logic_vector(10 downto 0);
	signal fb_rd_y          : std_logic_vector(10 downto 0);
	signal fb_rd_color      : std_logic_vector(COLOR_DEPTH-1 downto 0);
	
	signal flip_on_next_vs  : std_logic;
	signal latched_color    : std_logic_vector(COLOR_DEPTH-1 downto 0);
	signal x_cursor         : integer range 0 to SCREEN_WIDTH;
	signal y_cursor         : integer range 0 to SCREEN_HEIGHT;
	signal x_start          : integer range 0 to SCREEN_WIDTH;
	signal y_start          : integer range 0 to SCREEN_HEIGHT;
	signal x_end            : integer range 0 to SCREEN_WIDTH;
	signal y_end            : integer range 0 to SCREEN_HEIGHT;
	
begin
	
	vga_timing : entity work.VGA_Timing
		generic map(
			H_DISP          => SCREEN_WIDTH,
			V_DISP          => SCREEN_HEIGHT
		)
		port map(
			CLOCK        => CLOCK,
			RESET_N      => RESET_N,
			H_SYNC       => VGA_HS,
			V_SYNC       => vga_vsync,
			BLANK        => vga_blank,
			PIXEL_STROBE => vga_strobe,
			PIXEL_X      => vga_x,
			PIXEL_Y      => vga_y
		);
			
	vga_fb : entity work.VGA_RAMDAC
		generic map(
			FB_WIDTH    => SCREEN_WIDTH,
			FB_HEIGHT   => SCREEN_HEIGHT
		)
		port map(
			CLOCK        => CLOCK,
			RESET_N      => RESET_N,
			BUFFER_INDEX => fb_buffer_idx,
			WR_REQ       => fb_wr_req,
			WR_ACK       => fb_wr_ack,
			WR_X         => fb_wr_x,
			WR_Y         => fb_wr_y,
			WR_COLOR     => fb_wr_color,

			RD_REQ       => fb_rd_req,
			RD_ACK       => fb_rd_ack,
			RD_X         => fb_rd_x,
			RD_Y         => fb_rd_y,
			RD_COLOR     => fb_rd_color,
			
			SRAM_ADDR    => SRAM_ADDR,
			SRAM_DQ      => SRAM_DQ,
			SRAM_CE_N    => SRAM_CE_N,
			SRAM_OE_N    => SRAM_OE_N,
			SRAM_WE_N    => SRAM_WE_N,
			SRAM_UB_N    => SRAM_UB_N,
			SRAM_LB_N    => SRAM_LB_N
		);

		
	
	fb_rd_x   <= vga_x;
	fb_rd_y   <= vga_y;
	--fb_rd_req <= vga_strobe; --TODO here
	
	                            -- only to avoid synthesis warnings;
	fb_rd_req <= not(vga_blank) and (vga_strobe or fb_rd_ack or '1'); 
	                          
	
	fb_wr_color <= latched_color;
	fb_wr_x     <= std_logic_vector(to_unsigned(x_cursor, fb_wr_x'length));
	fb_wr_y     <= std_logic_vector(to_unsigned(y_cursor, fb_wr_y'length));
	
	VGA_VS  <= vga_vsync;
	VGA_R   <= fb_rd_color(11 downto 8) when (vga_blank = '0') else (others => '0');
	VGA_G   <= fb_rd_color(7 downto 4)  when (vga_blank = '0') else (others => '0');
	VGA_B   <= fb_rd_color(3 downto 0)  when (vga_blank = '0') else (others => '0');
	READY   <= '1' when (state = IDLE and (CLEAR or DRAW_LINE or DRAW_RECT or FILL_RECT or FLIP) = '0') else '0';
	
	draw_logic : process(CLOCK, RESET_N)
	begin
		
		if (RESET_N = '0') then
			
			state           <= IDLE;
			fb_wr_req       <= '0';
			fb_buffer_idx   <= '0';
			flip_on_next_vs <= '0';
			
		elsif (rising_edge(CLOCK)) then

			fb_wr_req <= '0';
			
			case (state) is
				when IDLE =>
					
					latched_color <= COLOR;
					if (CLEAR = '1') then
						x_start   <= 0;
						y_start   <= 0;
						x_end     <= SCREEN_WIDTH-1;
						y_end     <= SCREEN_HEIGHT-1;
						state     <= FILLING_RECT;
						substate  <= INIT;
		
					elsif (DRAW_LINE = '1') then
						x_start   <= X0;
						y_start   <= Y0;
						x_end     <= X1;
						y_end     <= Y1;
						state     <= DRAWING_LINE;
						substate  <= INIT;					
						
					elsif (DRAW_RECT = '1') then
						x_start   <= X0;
						y_start   <= Y0;
						x_end     <= X1;
						y_end     <= Y1;
						state     <= DRAWING_RECT;
						substate  <= INIT;
						
					elsif (FILL_RECT = '1') then
						x_start   <= X0;
						y_start   <= Y0;
						x_end     <= X1;
						y_end     <= Y1;
						state     <= FILLING_RECT;
						substate  <= INIT;			
			
					elsif (FLIP = '1') then
						flip_on_next_vs <= '1';
						
					end if;
					
					if (flip_on_next_vs = '1' and vga_vsync = '0') then
						fb_buffer_idx   <= not(fb_buffer_idx); 
						flip_on_next_vs <= '0';
					end if;

					
				when DRAWING_RECT =>
					fb_wr_req <= '1';				
					if (substate = INIT) then
						x_cursor  <=  x_start;
						y_cursor  <=  y_start;
						substate  <= DRAWING_R1;
					elsif (substate = DRAWING_R1) then
						if (fb_wr_ack = '1') then
							if (x_cursor = x_end) then
								if (y_cursor = y_end) then
									fb_wr_req <= '0';
									substate <= DRAWING_R2;
								else
									y_cursor <= y_cursor + 1;
								end if;
							else
								x_cursor <= x_cursor + 1;
							end if;
						end if;							
					elsif (substate = DRAWING_R2) then
						if (fb_wr_ack = '1') then
							if (x_cursor = x_start) then
								if (y_cursor = y_start) then
									fb_wr_req <= '0';
									state     <= IDLE;
								else
									y_cursor <= y_cursor - 1;
								end if;
							else
								x_cursor <= x_cursor - 1;
							end if;
						end if;							
					end if;
					
					
				when DRAWING_LINE =>
					fb_wr_req <= '1';					
					if (substate = INIT) then											
						x_cursor  <=  x_start;
						y_cursor  <=  y_start;
						substate  <= DRAWING;
					else
						if (fb_wr_ack = '1') then
							if (x_cursor = x_end) then
								if (y_cursor = y_end) then
									fb_wr_req <= '0';
									state <= IDLE;
								else
									y_cursor <= y_cursor + 1;
								end if;
							else
								x_cursor <= x_cursor + 1;
							end if;
						end if;							
					end if;
					
				
				when FILLING_RECT =>
					fb_wr_req <= '1';

					if (substate = INIT) then
						x_cursor  <=  x_start;
						y_cursor  <=  y_start;
						substate  <= DRAWING;
					else
						if (fb_wr_ack = '1') then
							if (x_cursor = x_end) then
								x_cursor <= x_start;
								if (y_cursor = y_end) then
									fb_wr_req <= '0';
									state <= IDLE;
								else
									y_cursor <= y_cursor + 1;
								end if;
							else
								x_cursor <= x_cursor + 1;
							end if;
						end if;				
					end if;
					
			
			when others =>
				assert false severity failure;
			
			end case;
			
		
		end if;
		
	end process;
	
	
	end architecture;