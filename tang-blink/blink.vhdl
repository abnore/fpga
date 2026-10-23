library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity blink is
  port (
    clk : in  std_logic;
    led : out std_logic
  );
end entity;

architecture rtl of blink is
  signal count : unsigned(24 downto 0) := (others => '0');
begin
  process(clk)
  begin
    if rising_edge(clk) then
      count <= count + 1;
    end if;
  end process;

  led <= not count(24);
end architecture;
