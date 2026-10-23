library ieee;
use ieee.std_logic_1164.all;

entity tb_spi is
end entity;

architecture tb of tb_spi is
    signal clk, rst, valid, ready, sck, mosi, cs : std_logic := '0';
    signal din : std_logic_vector(7 downto 0);
begin
    spi_m : entity work.spi_master port map(
            clk => clk,
            rst => rst,
            din => din,
            valid => valid,
            ready => ready,
            sck => sck,
            mosi => mosi,
            cs => cs
        );

    clk <= not clk after 5 ns;

    stimulus : process
    begin
        rst   <= '1';
        valid <= '0';

        wait for 20 ns;
        wait until falling_edge(clk);
        rst <= '0';

         -- Send a data byte.
        din   <= x"A5";
        valid <= '1';

        wait until rising_edge(clk) and ready = '1';
        valid <= '0';

        -- Present the next byte while the master is busy.
        din   <= x"3C";
        valid <= '1';

        wait until rising_edge(clk) and ready = '1';
        valid <= '0';

        -- Wait for the final transmission to finish.
        wait until rising_edge(clk) and ready = '1';

        report "Stimulus complete";
        std.env.stop;
        wait;

    end process;
end architecture;
