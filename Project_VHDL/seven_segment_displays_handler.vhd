--library ieee;
--use ieee.numeric_std.all;
--use ieee.std_logic_1164.all;

--entity seven_segment_displays_handler is
--	generic ( 
--		DISPLAYS_NUMBER	: in positive;
--		DECIMAL_DIGITS		: in positive
--	)
--	port 
--	(
--		CLOCK					: in std_logic;
--		DISPLAYS				: in std_logic_vector(7*DISPLAYS_NUMBER-1 downto 0);
--		BCD					: in std_logic_vector(DECIMAL_DIGITS*4-1 downto 0)
--	);
--end entity;
--
--architecture RTL of seven_segment_displays_handler is
--	signal bcd				: in std_logic_vector(DECIMAL_DIGITS*4-1 downto 0);
--
--begin
--	displays_handler : process(CLOCK, RESET_N)
--	if (RESET_N = '0') then
--			---- resetto schermi
--		elsif (rising_edge(CLOCK)) then
--			
--		end if;
--	end if;
--
--end architecture;