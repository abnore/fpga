library ieee;
use ieee.std_logic_1164.all;

entity lcd_top is
    port(
        clk, rst_n_in : in std_logic;

        scl     : out std_logic;
        sda     : out std_logic;
        rst_n   : out std_logic;
        rs      : out std_logic; -- is what the spec calls dc, same pin
        cs      : out std_logic
        );
end entity;

architecture rtl of lcd_top is
    signal rst : std_logic;
    signal din : std_logic_vector(7 downto 0);
    signal dvalid, dready, ddc : std_logic;

    constant pixels : positive := 240 * 135;

    signal byte_count : natural range 0 to PIXELS * 2 := 0;
begin

    rst <= not rst_n_in;

    lcd : entity work.lcd_st7789
    port map (
        clk => clk,
        rst => rst,

        scl   => scl,
        sda   => sda,
        rst_n => rst_n,
        rs    => rs,
        cs    => cs,

        din   => din,
        dvalid => dvalid,
        dready => dready,
        ddc   => ddc
        );

    ddc <= '1'; -- Pixel data, not commands for now

    dvalid <= '1' when byte_count < PIXELS * 2 else '0';
    /* 8.7.11 Write data for 16-bit/pixel (RGB 5-6-5-bit input), 65K-Colors, 3Ah=”05h”
    * 2 bytes send all the pixel info.
    * 1. byte RRRRRGGG
    * 2. byte GGGBBBBB
    * So red is 11111000 00000000 00F8
    * while blue is 00000000 00011111 001f
    * and green is 00000111 11100000 03e0
    * */
    --din <= x"F8" when byte_count mod 2 = 0 else x"00"; -- red
    --din <= x"1f" when byte_count mod 2 = 0 else x"00"; -- blue
    din <= x"03" when byte_count mod 2 = 0 else x"e0"; -- green

    red_generator : process(clk)
    begin
        if rising_edge(clk) then
            if rst then
                byte_count <= 0;
            elsif dvalid = '1' and dready = '1' then
                byte_count <= byte_count + 1;
            end if;
        end if;
    end process;

end architecture;
