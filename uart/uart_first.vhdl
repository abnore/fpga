library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- The uart protocol is the sending and receiving of data in serial form
-- We have a start bit, data and a stop bit. We will implement no parity.
-- Out format will be 115200 8/n/1/n
-- Since we just want to stream to a terminal, only the tx will be implemented

-- For simplicity, lets start with one byte at a time
entity UART is
    generic(
        baud_rate : natural := 115200;
        clock_speed : natural := 100_000_000;
    );
    port(
        clk, reset, rx : in std_ulogic;

        input    : in std_ulogic_vector(7 downto 0);
        tx_begin : in std_ulogic;

        tx_wait  : out std_ulogic;
        tx       : out std_ulogic
    );
end entity;

architecture behaviour of UART is
    constant clocks_per_bit : positive := (clock_frequency + baud_rate / 2) / baud_rate;

    type state_type is (IDLE, START_BIT, DATA_BITS, STOP_BIT);

    signal present_state, next_state : state_type;

    signal r_data, next_data : std_ulogic_vector(7 downto 0);
    signal r_baud_count, next_baud_count : natural range 0 to clocks_per_bit - 1;
    signal r_bit_count, next_bit_count : natural range 0 to 7;

begin

    BAUD_REGISTER: process(clk)
    begin
        if rising_edge(clk) then
            if reset then
                r_baud_count <= 0;
            else
                r_baud_count <= next_baud_count;
            end if;
        end if;
    end process;

end architecture;
