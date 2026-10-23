library ieee;
use ieee.std_logic_1164.all;

-- button debouncer, takes in a button and returnes a decounced signal
-- simple 2 state FSM counting for a specific amount of time, before accepting
-- the press. Using the clk input and counting to 1 million. Which on 100MHz is
-- 1/100th of a second, and even with a slow 27MHz clock, like the tang nano 9k,
-- it is still 1/27th of a second, which is acceptable fast
entity btn_debounce is
    port(
            clk     : in std_logic;
            rst   : in std_logic;
            btn     : in std_logic;
            btn_db  : out std_logic
        );
end entity;

architecture rtl of btn_debounce is
    type button_state is (IDLE, PRESSED);

    constant count_max : integer := 999999;

    -- Double flopped synchronized buttons
    signal btn_s1, btn_s2 : std_logic := '0';

    signal state, next_state : button_state := IDLE;
    signal count, next_count : integer range 0 to count_max := 0;

begin
    process(clk)
    begin
        if rising_edge(clk) then
            if rst then
                state  <= IDLE;
                count  <= 0;
                btn_s1 <= '0';
                btn_s2 <= '0';
            else
                state  <= next_state;
                count  <= next_count;
                btn_s1 <= btn;
                btn_s2 <= btn_s1;
            end if;
        end if;
    end process;

    process(all)
    begin
        next_state <= state;
        next_count <= 0;

        case state is
            when IDLE =>
                if btn_s2 = '1' then
                    if count = count_max then
                        next_state <= PRESSED;
                    else
                        next_count <= count + 1;
                    end if;
                end if;

            when PRESSED =>
                if btn_s2 = '0' then
                    if count = count_max then
                        next_state <= IDLE;
                    else
                        next_count <= count + 1;
                    end if;
                end if;
        end case;
    end process;

    btn_db <= '1' when state = PRESSED else '0';

end architecture;
