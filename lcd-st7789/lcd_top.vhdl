library ieee;
use ieee.std_logic_1164.all;

entity lcd_top is
    port(
        clk, rst_n_in : in std_logic;

        scl     : out std_logic;
        sda     : out std_logic;
        rst_n   : out std_logic;
        rs      : out std_logic; -- is what the spec calls dc, same pin
        cs      : out std_logic;

        debug_led : out std_logic
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
        ddc   => ddc,

        debug_led => debug_led
        );

    ddc <= '1'; -- Pixel data, not commands for now

    dvalid <= '1' when byte_count < PIXELS * 2 else '0';
    din <= x"F8" when byte_count mod 2 = 0 else x"00";

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
