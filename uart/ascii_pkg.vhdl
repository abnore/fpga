library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package ascii_pkg is
    function to_ascii(ch : character) return std_logic_vector;
    function to_ascii(str : string) return std_logic_vector;
end package;

package body ascii_pkg is

    -- Function overloading, first to map a character to a 8bit std_logic_vector
    function to_ascii(ch : character) return std_logic_vector is
    begin
        return std_logic_vector(to_unsigned(character'pos(ch), 8));
    end function;

    -- And now we create a std_logic_vector the length of the string.
    -- VHDL indexes strings from left to right, so "ABC". A is index 1.
    -- We need that to be bit 23 to 16 in this example.
    -- We must place the first character at the highest byte position,
    -- because the uart controller send the first character (high byte)
    -- first, in order for them to appear on the screen correctly, but
    -- the uart itself sends the bits LSB first.
    -- Kind of messy, but its a workaround
    function to_ascii(str : string) return std_logic_vector is
        variable ascii_result : std_logic_vector(str'length * 8 - 1 downto 0);
        variable pos : integer;
    begin
        for i in str'range loop
            pos := (str'high - i) * 8;

            ascii_result(pos + 7 downto pos) := to_ascii(str(i));
        end loop;

        return ascii_result;
    end function;

end package body;
