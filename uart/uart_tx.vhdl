library ieee;
use ieee.std_logic_1164.all;

-- Transmit module of UART 8N1, with no parity and no flow control
-- Basic protocol implemented, and tested on hardware (tang nano 9k)

entity uart_tx is
    generic(
               CLK_FREQ : integer := 27_000_000;
               BAUD     : integer := 115_200
           );
    port(
            clk     : in std_logic;
            rst     : in std_logic;
            din     : in std_logic_vector(7 downto 0);
            strb    : in std_logic;
            tx      : out std_logic;
            busy    : out std_logic
        );
end entity;

architecture rtl of uart_tx is
    constant CLKS_PER_BIT : integer := (CLK_FREQ / BAUD);

    type state_t is (IDLE, START, DATA, STOP);

    signal state, next_state  : state_t := IDLE;

    signal r_msg, r_next_msg  : std_logic_vector(7 downto 0) := (others => '0');
    signal r_cnt, r_next_cnt  : integer range 0 to CLKS_PER_BIT - 1 := 0;
    signal r_idx, r_next_idx  : integer range 0 to 7 := 0;
begin

    -----------------------------------------------------------------
    -- UPDATING ALL REGISTERS ----------------------------------------
    REG_UPDATE : process(clk) is
    begin
        if rising_edge(clk) then
            if rst then
                r_msg <= (others => '0');
                r_cnt <= 0;
                r_idx <= 0;
                state <= IDLE;
            else
                r_msg <= r_next_msg;
                r_cnt <= r_next_cnt;
                r_idx <= r_next_idx;
                state <= next_state;
            end if;
        end if;
    end process;

    -----------------------------------------------------------------
    -- UPDATING STATES AND DEFAULT VALUES ----------------------------
    STATE_UPDATE : process(all) is
    begin
        next_state <= state;
        r_next_msg <= r_msg;
        r_next_cnt <= 0;
        r_next_idx <= r_idx;

        case state is
            when IDLE =>
                r_next_idx <= 0;

                if strb then
                    r_next_msg <= din;
                    next_state <= START;
                end if;

            when START =>
                if r_cnt = (CLKS_PER_BIT - 1) then
                    next_state <= DATA;
                else
                    r_next_cnt <= r_cnt + 1;
                end if;

            when DATA =>
                if (r_cnt = CLKS_PER_BIT - 1) then
                    if r_idx = 7 then
                        next_state <= STOP;
                    else
                        r_next_idx <= r_idx + 1;
                    end if;
                else
                    r_next_cnt <= r_cnt + 1;
                end if;

            when STOP =>
                if r_cnt = CLKS_PER_BIT - 1 then
                    next_state <= IDLE;
                else
                    r_next_cnt <= r_cnt + 1;
                end if;
        end case;
    end process;

    -----------------------------------------------------------------
    -- UPDATING OUTPUT VALUES ---------------------------------------
    OUTPUT_UPDATE : process(all) is
    begin
        -- Both of these are active low, high is inactive
        tx      <= '1';
        busy    <= '1';

        case state is
            when IDLE   => busy <= '0';
            when START  => tx   <= '0';
            when DATA   => tx   <= r_msg(r_idx);
            when STOP   => tx   <= '1';
        end case;
    end process;

end architecture;
