library ieee;
use ieee.std_logic_1164.all;

-- Recieve module of UART 8N1, with no parity and no flow control
-- Basic protocol implemented, and tested on hardware (tang nano 9k)
-- Mirror of the TX version, with some minor modifications

entity uart_rx is
    generic(
               CLK_FREQ : integer := 27_000_000;
               BAUD     : integer := 115_200
           );
    port(
            clk     : in std_logic;
            rst     : in std_logic;
            rx      : in std_logic;
            dout    : out std_logic_vector(7 downto 0);
            strb      : out std_logic
        );
end entity;

architecture rtl of uart_rx is
    constant CLKS_PER_BIT : integer := (CLK_FREQ / BAUD);

    type state_t is (IDLE, START, DATA, STOP);
    signal state, next_state  : state_t := IDLE;

    -- since UART is asynchronous we double flop rx
    signal rx_s1, rx_s2 : std_logic := '1';

    signal r_strb, r_next_strb : std_logic := '0';
    signal r_dout, r_next_dout : std_logic_vector(7 downto 0) := (others => '0');
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
                r_msg   <= (others => '0');
                r_cnt   <= 0;
                r_idx   <= 0;
                state   <= IDLE;
                rx_s1   <= '1';
                rx_s2   <= '1';
                r_dout  <= (others => '0');
                r_strb  <= '0';
            else
                rx_s1   <= rx;
                rx_s2   <= rx_s1;
                r_msg   <= r_next_msg;
                r_cnt   <= r_next_cnt;
                r_idx   <= r_next_idx;
                state   <= next_state;
                r_dout  <= r_next_dout;
                r_strb  <= r_next_strb;
            end if;
        end if;
    end process;

    -----------------------------------------------------------------
    -- UPDATING STATES AND DEFAULT VALUES ----------------------------
    STATE_UPDATE : process(all) is
    begin
        next_state   <= state;
        r_next_msg   <= r_msg;
        r_next_cnt   <= 0;
        r_next_idx   <= r_idx;
        r_next_dout  <= r_dout;
        r_next_strb  <= '0';

        case state is
            when IDLE =>
                r_next_idx <= 0;

                if rx_s2 = '0' then
                    next_state <= START;
                end if;

            when START =>
                if (r_cnt = CLKS_PER_BIT / 2) then
                    if (rx_s2 = '0') then
                        next_state <= DATA;
                    else
                        next_state <= IDLE;
                    end if;
                else
                    r_next_cnt <= r_cnt + 1;
                end if;

            when DATA =>
                if (r_cnt = CLKS_PER_BIT - 1) then
                    r_next_msg(r_idx) <= rx_s2;

                    if r_idx = 7 then
                        r_next_idx <= 0;
                        next_state <= STOP;
                    else
                        r_next_idx <= r_idx + 1;
                    end if;
                else
                    r_next_cnt <= r_cnt + 1;
                end if;

            when STOP =>
                if r_cnt = CLKS_PER_BIT - 1 then
                    if rx_s2 = '1' then
                        r_next_dout <= r_msg;
                        r_next_strb   <= '1';
                    end if;
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
        dout <= r_dout;
        strb <= r_strb;
    end process;

end architecture;
