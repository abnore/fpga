library ieee;
use ieee.std_logic_1164.all;

/* SPI master which, for now, only supports the TFT LCD screen on the Tang Nano.
 * Setting up support for 1 slave, this can be changed later, each slave will
 * need its own wire for CS.
 *
 * Also the miso line remains unsupported as we are only interested in sending
 * data _to_ the screen, not get anything back. This is not a full SPI impl.
 */
entity spi_master is
    port(
        clk     : in std_logic;
        rst     : in std_logic;

        -- control signals
        valid   : in std_logic;
        din     : in std_logic_vector(7 downto 0);
        ready   : out std_logic;

        -- spi interface to slave
        sck     : out std_logic;
        mosi    : out std_logic;
        --miso    : in std_logic; -- We are not after information atm
        cs      : out std_logic -- single slave, LCD
        -- cs   : out std_logic_vector(X downto 0) -- support X slaves
        );
end entity;

architecture rtl of spi_master is
    type state_t is (IDLE, SHIFT);
    signal state, next_state : state_t;

    signal data, next_data : std_logic_vector(7 downto 0);
    signal r_mosi, r_next_mosi : std_logic := '0';
    signal r_sck, r_next_sck : std_logic := '0';

    signal r_cnt, r_next_cnt : integer range 0 to 7 := 0;
begin

    reg_update : process(clk) is
    begin
        if rising_edge(clk) then
            if rst then
                state  <= IDLE;
                data   <= (others => '0');
                r_mosi <= '0';
                r_sck  <= '0';
                r_cnt  <= 0;
                cs <= '1';
            else
                state  <= next_state;
                data   <= next_data;
                r_mosi <= r_next_mosi;
                r_sck  <= r_next_sck;
                r_cnt  <= r_next_cnt;

                if state = IDLE and valid = '1' then
                    cs <= '0';
                end if;

            end if;
        end if;
    end process;

    state_update : process(all) is
    begin
        next_state <= state;

        case state is
            when IDLE =>
                if valid then
                    next_state <= SHIFT;
                end if;
            when SHIFT =>
                if r_cnt = 7 and r_sck = '1' then
                    next_state <= IDLE;
                end if;
        end case;
    end process;

    shift_reg : process(all) is
    begin
        next_data   <= data;
        r_next_mosi <= r_mosi;
        r_next_sck  <= r_sck;
        r_next_cnt  <= r_cnt;

        case state is

            when IDLE =>
                r_next_sck <= '0';
                r_next_cnt <= 0;

                if valid then
                    next_data   <= din;
                    r_next_mosi <= din(7);
                end if;

            when SHIFT =>
                if r_sck = '0' then
                    r_next_sck <= '1';
                else
                    r_next_sck <= '0';

                    if r_cnt < 7 then
                        next_data   <= data(6 downto 0) & '0';
                        r_next_mosi <= data(6);
                        r_next_cnt  <= r_cnt + 1;
                    end if;
                end if;
        end case;
    end process;

    mosi  <= r_mosi;
    sck   <= r_sck;
    ready <= '1' when state = IDLE else '0';
    --cs    <= '1' when state = IDLE else '0';

end architecture;
