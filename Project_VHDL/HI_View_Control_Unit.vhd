library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.HI_package.all;
use work.vga_package.all;

entity Hi_View_Control_Unit is 
	port 
	(
		CLOCK				: in	std_logic;
		FRAME_TIME		: in  std_logic;
		RESET_N			: in 	std_logic;
		READY 			: in  std_logic;
		
		DRAW_SPRITE		: out std_logic;
		SHOW				: out std_logic;
		REQ_NEXT_SPRITE: out std_logic
	);
end entity;

architecture RTL of Hi_View_Control_Unit is 

type state_type is (RENDER, SHOW_SPRITES, WAITING, WAITING_2);

signal render_asap		: std_logic;
signal state 				: state_type;
signal next_state 		: state_type;
signal render_counter	: integer;

signal x						: xy_coord_type;
signal y						: xy_coord_type;

signal draw_delayed		: std_logic;

begin
	
	location : process (render_asap, RESET_N) 
	begin
		if (RESET_N = '0') then
			x <= 0;
			y <= 0;
		elsif rising_edge (render_asap) then
			x <= x + 1;
			y <= y + 1;
		end if;
	end process;
	
	main : process(CLOCK, RESET_N)
	begin
		
		if (RESET_N = '0') then
			DRAW_SPRITE <= '0';
			SHOW <= '0';
			REQ_NEXT_SPRITE <= '0';
			render_asap <= '0';
			render_counter <= 0;
			state <= WAITING;
			next_state <= RENDER;
			draw_delayed <= '0';
			
		elsif rising_edge(CLOCK) then
			
			DRAW_SPRITE <= draw_delayed;
			draw_delayed <= '0';
			SHOW <= '0';
			REQ_NEXT_SPRITE <= '0';
		
			if (FRAME_TIME = '1') then
				render_asap <= '1';
			end if;
			
			case (state) is 
				when RENDER =>
					if (READY = '1') then
						state <= WAITING;
					else
						state <= WAITING_2;
					end if;
					REQ_NEXT_SPRITE <= '1';
					next_state <= RENDER;
					render_counter <= render_counter + 1;
					draw_delayed <= '1';
					
					case (render_counter) is
						when ALIENS_PER_COLUMN * COLUMNS_PER_GRID - 1=> 
							next_state <= SHOW_SPRITES;
--						when ALIENS_PER_COLUMN * COLUMNS_PER_GRID => 
--							REQ_NEXT_SPRITE  <= '0';
--						when ALIENS_PER_COLUMN * COLUMNS_PER_GRID + 1=> 
--							REQ_NEXT_SPRITE  <= '0';
--							next_state <= SHOW_SPRITES;
						when others => --UNREACHABLE
							
					end case;
				when SHOW_SPRITES =>
					state <= SHOW_SPRITES;
					next_state <= SHOW_SPRITES;
					if (render_asap = '1') then
						SHOW <= '1';
						render_asap <= '0';
						state <= WAITING;
						next_state <= RENDER;
						render_counter <= 0;
					end if;
				when WAITING =>
					if (READY = '0') then
						state <= WAITING_2;
					end if;
				when WAITING_2 =>
					if (READY = '1') then 
						state <= next_state;
					end if;
				when others => -- UNREACHABLE
			end case;
		end if;
	end process;

end architecture;