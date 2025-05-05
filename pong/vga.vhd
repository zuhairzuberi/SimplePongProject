library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity vga is
    Port ( clk : in  STD_LOGIC;
           rst : in  STD_LOGIC;
           hsync : out  STD_LOGIC;
           vsync : out  STD_LOGIC;
           dac_clk : out  STD_LOGIC;
           Rout : out  STD_LOGIC_VECTOR (7 downto 0);
           Bout : out  STD_LOGIC_VECTOR (7 downto 0);
           Gout : out  STD_LOGIC_VECTOR (7 downto 0);
           blue_control : in  STD_LOGIC;
           pink_control : in  STD_LOGIC);
end vga;

architecture Behavioral of vga is
	signal clk_div : std_logic := '0';
	
	constant h_display : integer := 639;
	constant h_frontPorch : integer := 16;
	constant h_pulse : integer := 96;
	constant h_backPorch : integer := 48;
	signal h_sync : std_logic := '0';
	
	constant v_display : integer := 479;
	constant v_frontPorch : integer := 10;
	constant v_pulse : integer := 2;
	constant v_backPorch : integer := 33;
	signal v_sync : std_logic := '0';
	
	signal hPosition : integer := 0;
	signal hPositionOutput : std_logic_vector(9 downto 0);
	signal vPosition : integer := 0;
	signal vPositionOutput : std_logic_vector(9 downto 0);
	signal videoToggle : std_logic := '0';
	
	signal blue : integer := 210;
	signal pink : integer := 210;
	signal ballX : integer := 310;
	signal ballY : integer := 230;
	signal ballDirectionX : integer := 2;
	signal ballDirectionY : integer := 2;
	signal counter : integer := 0;
	
	component icon
	PORT (
		CONTROL0 : INOUT STD_LOGIC_VECTOR(35 DOWNTO 0));
	end component;

	component ila
	PORT (
		 CONTROL : INOUT STD_LOGIC_VECTOR(35 DOWNTO 0);
		 CLK : IN STD_LOGIC;
		 DATA : IN STD_LOGIC_VECTOR(99 DOWNTO 0);
		 TRIG0 : IN STD_LOGIC_VECTOR(7 DOWNTO 0));
	end component;
	
	signal control0 : std_logic_vector(35 downto 0);
	signal ila_data : std_logic_vector(99 downto 0);
	signal trig0 : std_logic_vector(7 downto 0);
	
begin

icon_instance : icon
  port map (
    CONTROL0 => control0);
	 
ila_instance : ila
  port map (
    CONTROL => control0,
    CLK => clk,
    DATA => ila_data,
    TRIG0 => trig0);

clk_divider : process(clk, rst)
begin
	if (clk'EVENT and clk = '1') then
		clk_div <= not clk_div;
		dac_clk <= clk_div;
	end if;
end process;

horizontal_counter : process(clk_div, rst)
begin
	if (rst = '1') then
		hPosition <= 0;
	elsif (clk_div'EVENT and clk_div = '1') then
		if (hPosition = (h_display + h_frontPorch + h_pulse + h_backPorch)) then
			hPosition <= 0;
		else
			hPosition <= hPosition + 1;
		end if;
	end if;
end process;

vertical_counter : process(clk_div, rst, hPosition)
begin
	if (rst = '1') then
		vPosition <= 0;
	elsif (clk_div'EVENT and clk_div = '1') then
		if (hPosition = (h_display + h_frontPorch + h_pulse + h_backPorch)) then
			if (vPosition = (v_display + v_frontPorch + v_pulse + v_backPorch)) then
				vPosition <= 0;
			else
				vPosition <= vPosition + 1;
			end if;
		end if;
	end if;
end process;

horizontal_sync : process(clk_div, rst, hPosition)
begin
	if (rst = '1') then
		hsync <= '0';
	elsif (clk_div'EVENT and clk_div = '1') then
		if ((hPosition <= (h_display + h_frontPorch)) or (hPosition > h_display + h_frontPorch + h_pulse)) then
			hsync <= '1';
			h_sync <= '1';
		else
			hsync <= '0';
			h_sync <= '0';
		end if;
	end if;
end process;

vertical_sync : process(clk_div, rst, vPosition)
begin
	if (rst = '1') then
		vsync <= '0';
	elsif (clk_div'EVENT and clk_div = '1') then
		if ((vPosition <= (v_display + v_frontPorch)) or (vPosition > v_display + v_frontPorch + v_pulse)) then
			vsync <= '1';
			v_sync <= '1';
		else
			vsync <= '0';
			v_sync <= '0';
		end if;
	end if;
end process;

video_on : process(clk_div, rst, hPosition, vPosition)
begin
	if (rst = '1') then
		videoToggle <= '0';
	elsif (clk_div'EVENT and clk_div = '1') then
		if (hPosition <= h_display and vPosition <= v_display) then
			videoToggle <= '1';
		else 
			videoToggle <= '0';
		end if;
	end if;
end process;

draw : process(clk_div, rst, hPosition, vPosition, videoToggle)
begin
	if (rst = '1') then
		Rout <= "00000000";
		Gout <= "00000000";
		Bout <= "00000000";
	elsif (clk_div'EVENT and clk_div = '1') then
		counter <= counter + 1;
		if (counter = 480000) then
			if (blue_control = '1' and blue >= 45) then
				blue <= (blue - 2);
			elsif (blue_control = '0' and blue < 435-60) then
				blue <= (blue + 2);
			end if;
			if (pink_control = '1' and pink >= 45) then
				pink <= (pink - 2);
			elsif (pink_control = '0' and pink < 435-60) then
				pink <= (pink + 2);
			end if;
			
			if (ballX+20 >  639) then
				ballX <= 310;
				ballY <= 230;
			elsif (ballX < 5) then
				ballX <= 310;
				ballY <= 230;
			elsif (ballY > 45 and ballY+20 <= 434) then
			
				-- right/left side bar collision
				if (ballX+20 > 598 and (ballY <= 194 or ballY > 288)) then
					ballDirectionX <= -2;
				elsif ((ballX < 41) and (ballY <= 194 or ballY > 288)) then
					ballDirectionX <= 2;
				end if;
				
				-- blue paddle collision
				if (ballX < 56 and ballY < blue + 60 and ballY + 20 > blue) then
					ballDirectionX <= 2;
					if (ballDirectionY = 2) then
						ballDirectionY <= 2;
					else
						ballDirectionY <= -2;
					end if;
				end if;
				
				-- pink paddle collision
				if (ballX+20 > 584 and ballY < pink + 60 and ballY + 20 > pink) then
					ballDirectionX <= -2;
					if (ballDirectionY = 2) then
						ballDirectionY <= 2;
					else
						ballDirectionY <= -2;
					end if;
				end if;
				
				-- top/bottom bar collision
				if (ballY+20 > 430) then
					ballDirectionY <= -2;
				elsif (ballY < 50) then
					ballDirectionY <= 2;
				end if;
				
				
				
				ballX <= ballX + ballDirectionX;
				ballY <= ballY + ballDirectionY;
			end if;
			
		counter <= 0;
		end if;
		
		if (videoToggle = '1') then
			-- top/bottom boundary lines
			if (hPosition >= 25 and hPosition <= 615 and ((vPosition >= 34 and vPosition < 45) or (vPosition >= 435 and vPosition <= 446))) then
				Rout <= "11111111";
				Gout <= "11111111";
				Bout <= "11111111";
			-- left/right boundary lines
			elsif (((hPosition >= 25 and hPosition <= 36) or (hPosition >= 604 and hPosition <= 615)) and ((vPosition >= 34 and vPosition < 194) or (vPosition >= 288 and vPosition <= 446))) then
				Rout <= "11111111";
				Gout <= "11111111";
				Bout <= "11111111";
			-- blue paddle
			elsif ((hPosition >= 40 and hPosition <= 51) and (vPosition >= blue and vPosition <= (blue+60))) then
				Rout <= "00000000";
				Gout <= "00000000";
				Bout <= "11111111";
			-- pink paddle
			elsif ((hPosition >= 589 and hPosition <= 600) and (vPosition >= pink and vPosition <= (pink+60))) then
				Rout <= "11111111";
				Gout <= "00000000";
				Bout <= "11111111";
			-- ball
			elsif ((hPosition >= ballX and hPosition <= ballX + 20) and (vPosition >= ballY and vPosition <= ballY + 20)) then
				if (ballX < 25 or ballx + 20 > 604) then
					Rout <= "11111111";
					Gout <= "00000000";
					Bout <= "00000000";
				else
					Rout <= "11111111";
					Gout <= "11111111";
					Bout <= "00000000";
				end if;
			-- dashed lines in the middle
			elsif ((hPosition > 315 and hPosition < 325) and (vPosition >= 45 and vPosition < 435) and (((vPosition - 25) mod 64) > 32)) then
				Rout <= "00000000";
				Gout <= "00000000";
				Bout <= "00000000";
			--green background
			elsif (hPosition <= h_display and vPosition <= v_display) then
				Rout <= "00000000";
				Gout <= "11111111";
				Bout <= "00000000";
			else
				Rout <= (others => '0');
				Gout <= (others => '0');
				Bout <= (others => '0');
			end if;	
		else 
			Rout <= "00000000";
			Gout <= "00000000";
			Bout <= "00000000";
		end if;
	end if;
end process;

ila_data(9 downto 0) <= std_logic_vector(to_unsigned(hPosition, hPositionOutput'length));
ila_data(19 downto 10) <= std_logic_vector(to_unsigned(vPosition, vPositionOutput'length));
ila_data(20) <= h_sync;
ila_data(21) <= v_sync;
trig0(0) <= not(v_sync);
trig0(7 downto 1) <= (others => '0');
end Behavioral;

