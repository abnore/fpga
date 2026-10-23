library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity seg_driver is
    port(
        clk : in std_logic;
        rst : in std_logic;
        din : in std_logic_vector(3 downto 0);
        seg : out std_logic_vector(6 downto 0)
    );
end entity;

architecture rtl of seg_driver is
    type svn_seg is array (0 to 15) of std_logic_vector(6 downto 0);

    constant seg_val : svn_seg := (
        --    gfedcba
        0  => B"0111111",
        1  => B"0000110",
        2  => B"1011011",
        3  => B"1001111",
        4  => B"1100110",
        5  => B"1101101",
        6  => B"1111101",
        7  => B"0000111",
        8  => B"1111111",
        9  => B"1101111",
        10 => B"1110111", -- A
        11 => B"1111100", -- b
        12 => B"0111001", -- C
        13 => B"1011110", -- d
        14 => B"1111001", -- E
        15 => B"1110001"  -- F
    );
begin

    process (clk) is
    begin
        if rising_edge(clk) then
            if rst then
                seg <= seg_val(0);
            else
                seg <= seg_val((to_integer(unsigned(din))));
            end if;
        end if;
    end process;

end architecture;
