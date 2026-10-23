library ieee;
use ieee.std_logic_1164.all;

entity lcd_st7789 is
    generic (
        CLK_FREQ : integer := 27_000_000
    );
    port(
        clk     : in std_logic;
        rst     : in std_logic;

        scl     : out std_logic;
        sda     : out std_logic;
        rst_n   : out std_logic;
        rs      : out std_logic; -- is what the spec calls dc, same pin
        cs      : out std_logic;

        din     : in std_logic_vector(7 downto 0);
        dvalid  : in std_logic;
        dready  : out std_logic;
        ddc     : in std_logic;
    );
end entity;

architecture rtl of lcd_st7789 is
    signal r_valid, r_dc : std_logic := '0';
    signal next_valid, next_dc : std_logic := '0';
    signal spi_din, next_spi_din : std_logic_vector(7 downto 0) := (others => '0');
    signal ready : std_logic; -- driven by the SPI master

    constant CYCLES_PER_MS : positive := CLK_FREQ / 1000;
    constant US_10 : positive := CLK_FREQ / 100_000;
    constant MS_5 : positive := CYCLES_PER_MS * 5;
    constant MS_10 : positive := CYCLES_PER_MS * 10;
    constant MS_100 : positive := CYCLES_PER_MS * 100;
    constant MS_120 : positive := CYCLES_PER_MS * 120;
    constant MS_150 : positive := CYCLES_PER_MS * 150;
    constant MS_200 : positive := CYCLES_PER_MS * 200;

    signal counter, next_counter : natural range 0 to MS_200 := 0;

    type state_t is ( RESET_HOLD, RESET_WAIT, WAKE, WAKE_WAIT, INIT, DRIVING );
    signal state, next_state : state_t := RESET_HOLD;

    type init_cmd is record
        cmd : std_logic_vector(7 downto 0);
        dc  : std_logic;
    end record;

    type init_array is array (natural range <>) of init_cmd;
    -- The sequence assumes we power on or reset, and no interruptions
    -- We only bother with the ones setting something else than the default,
    -- there are many more settings we would do here
    constant init_seq : init_array := (
        (x"11", '0'), -- Sleep out - needs 5ms delay, or 120 delay for sleep in
        (x"36", '0'), -- Mem data access control
        (x"70", '1'), -- mem data access parameter
        (x"3a", '0'), -- RGB Format
        (x"05", '1'), -- 16 bit per pixel, 2 bytes
        (x"bb", '0'), -- VCOMS setting
        (x"19", '1'), -- setting to 0.725V
        (x"c3", '0'), -- VRH setting
        (x"12", '1'), -- 4.45 V -/+
        (x"d0", '0'), -- Power control 1
        (x"a4", '1'), -- mandatory preset param
        (x"a1", '1'), -- setting 3 voltages for internal analog supply
        (x"e0", '0'), -- positive voltage gamma control, 14 params
        (x"D0", '1'), (x"04", '1'), (x"0D", '1'), (x"11", '1'), (x"13", '1'),
        (x"2B", '1'), (x"3F", '1'), (x"54", '1'), (x"4C", '1'), (x"18", '1'),
        (x"0D", '1'), (x"0B", '1'), (x"1F", '1'), (x"23", '1'),
        (x"e1", '0'), -- negative voltage gamma control, 14 params
        (x"D0", '1'), (x"04", '1'), (x"0C", '1'), (x"11", '1'), (x"13", '1'),
        (x"2C", '1'), (x"3F", '1'), (x"44", '1'), (x"51", '1'), (x"2F", '1'),
        (x"1F", '1'), (x"1F", '1'), (x"20", '1'), (x"23", '1'),
        (x"21", '0'), -- display inversion on
        (x"29", '0'), -- display on
    );
    signal init_arr_idx, next_arr_idx : natural range 0 to init_seq'length := 0;

begin
    -- Drive the dc signal
    rs <= r_dc;

    spi : entity work.spi_master
    port map(
        clk => clk,
        rst => rst,
        cs => cs,
        valid => r_valid,
        ready => ready,
        din => spi_din,
        sck => scl,
        mosi => sda
    );

    process(clk) is
    begin
        if rising_edge(clk) then
            if rst then
                state        <= RESET_HOLD;
                r_valid      <= '0';
                r_dc         <= '0';
                spi_din      <= (others => '0');
                counter      <= 0;
                init_arr_idx <= 0;
            else
                state        <= next_state;
                r_valid      <= next_valid;
                r_dc         <= next_dc;
                spi_din      <= next_spi_din;
                counter      <= next_counter;
                init_arr_idx <= next_arr_idx;

            end if;
        end if;
    end process;

    process(all) is
    begin
        -- to not infer latches, we default all registers to what they are,
        -- because its combinational we change them later, or not
        next_valid   <= r_valid;
        next_dc      <= r_dc;
        next_spi_din <= spi_din;
        next_state   <= state;
        next_arr_idx <= init_arr_idx;
        next_counter <= 0;

        rst_n <= '1'; -- default value, normally high, execept in reset_hold
        dready <= '0'; -- only in driving we set this, otherwise its low

        case state is
            /* Here we are sending a hardware reset, cleared all registers and
            * we need to hold rst_n low for at least 10us.
            * */
            when RESET_HOLD =>

                rst_n <= '0'; -- hold reset down for 100us

                if (counter = US_10) then
                    next_state <= RESET_WAIT;
                else
                    next_counter <= counter + 1;
                end if;

            /* Here we need to wait a minimum of 120ms before we send the first
            * command, which is going to be sleep out
            * */
            when RESET_WAIT =>

                if (counter = MS_120) then
                    next_state <= WAKE;
                else
                    next_counter <= counter + 1;
                end if;

            /* In this state we send the sleep out command, waking the screen
            * for configuration. This needs a minimum of 5ms, or 120ms if we
            * are going right back to sleep. We dont support that, so we wait
            * 5ms. And then initialized the screen. The way i chose to do this
            * is the simplest, send the command and move to the next state that
            * waits the appropriate time
            * */
            when WAKE =>

                if ready then
                    next_spi_din <= init_seq(init_arr_idx).cmd;
                    next_dc      <= init_seq(init_arr_idx).dc;
                    next_valid   <= '1';
                else
                    next_valid  <= '0';
                    next_state  <= WAKE_WAIT;
                    next_arr_idx <= init_arr_idx + 1;
                end if;

            when WAKE_WAIT =>

                if ready then
                    if (counter = MS_5) then
                        next_state <= INIT;
                    else
                        next_counter <= counter + 1;
                    end if;
                end if;


            /* Here we cycle through all the commands and parameters, sending
            * one byte at a time through the spi interface. Here we had a bug.
            * It is important not to cycle through while we are waiting for the
            * spi to stream over the bits. Therefore we prepare the next byte
            * while the data isnt valid, and when it is we toggle the array.
            * When data is valid while ready, it means the data is captured
            * and we are in a prepare/hold state
            * */
            when INIT =>

                next_valid <= '0';

                if init_arr_idx = init_seq'length then

                    next_state <= DRIVING if ready;

                elsif ready then
                    if r_valid = '0' then
                        next_spi_din <= init_seq(init_arr_idx).cmd;
                        next_dc      <= init_seq(init_arr_idx).dc;
                        next_valid   <= '1';
                    else
                        next_arr_idx <= init_arr_idx + 1;
                    end if;
                end if;

            /* Once we have initialized we never leave this state, unless we
            * reset. I am not supporting software reset for now.
            * */
            when DRIVING =>

                next_valid      <= '0';

                if ready = '1' and r_valid = '0' then
                    dready          <= '1';
                    next_spi_din    <= din;
                    next_dc         <= ddc;
                    next_valid      <= dvalid;
                end if;

        end case;
    end process;

end architecture;
