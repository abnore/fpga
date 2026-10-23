library ieee;
use ieee.std_logic_1164.all;
use work.ascii_pkg.all;

-- UART controller for the channels, directing the reading and writing, and in
-- this case, sending a known string when strobing a button, or echoen what is
-- being written in the terminal.
-- Tested on Tang Nano 9k

entity uart_ctrl is
    port(
        clk         : in std_logic;
        rst         : in std_logic;
        btn_l_strb  : in std_logic;
        btn_r_strb  : in std_logic;

        --
        rx_in       : in std_logic_vector(7 downto 0);
        rx_strb     : in std_logic;

        tx_busy     : in std_logic;
        tx_out      : out std_logic_vector(7 downto 0);
        tx_strb     : out std_logic
);
end entity;

architecture rtl of uart_ctrl is
-- echo "Hello World!" | xxd
-- 00000000: 4865 6c6c 6f20  576f 726c 6421 0a         Hello World!.
--            16   16   16   16    16   16  8
--               32        32         40 =  104
--  constant hello_world : std_logic_vector(95 downto 0) := X"48656c6c6f20576f7264210a";

    constant in5200 : string :=
      CR & LF &
      "'####:'##::: ##:'########::'#######::::'#####:::::'#####::: " & CR & LF &
      ". ##:: ###:: ##: ##.....::'##.... ##::'##.. ##:::'##.. ##:: " & CR & LF &
      ": ##:: ####: ##: ##:::::::..::::: ##:'##:::: ##:'##:::: ##: " & CR & LF &
      ": ##:: ## ## ##: #######:::'#######:: ##:::: ##: ##:::: ##: " & CR & LF &
      ": ##:: ##. ####:...... ##:'##:::::::: ##:::: ##: ##:::: ##: " & CR & LF &
      ": ##:: ##:. ###:'##::: ##: ##::::::::. ##:: ##::. ##:: ##:: " & CR & LF &
      "'####: ##::. ##:. ######:: #########::. #####::::. #####::: " & CR & LF &
      "....::..::::..:::......:::.........::::.....::::::.....:::: " & CR & LF;

    constant msg    : string := "Hello, World!" & CR & LF;
    constant hello_world_vec : std_logic_vector(
                             msg'length * 8 - 1 downto 0
                           ) := to_ascii(msg);
    constant MSG_MAX_1 : integer := hello_world_vec'length - 8;
    constant in5200_vec: std_logic_vector(
                             in5200'length * 8 - 1 downto 0
                           ) := to_ascii(in5200);
    constant MSG_MAX_2 : integer :=in5200_vec'length - 8;

    constant MSG_MAX : integer := MSG_MAX_2;

    signal tx_ptr : integer range 0 to MSG_MAX := 0;
    signal tx_busy_i : std_logic := '0';
    signal tx_cont : std_logic := '0';
    signal tx_sel : std_logic := '0'; -- '0' = Hello World, '1' = IN5200
    type ctrl_state_t is (IDLE, SHIFT, BUSY);
    signal ctrl_state : ctrl_state_t := IDLE;

    signal next_state : ctrl_state_t := IDLE;

    signal next_tx_ptr    : integer range 0 to MSG_MAX;
    signal next_tx_busy_i : std_logic;
    signal next_tx_cont   : std_logic;
    signal next_tx_sel    : std_logic;
    signal next_tx_out    : std_logic_vector(7 downto 0);
    signal next_tx_strb   : std_logic;

    signal r_tx_out  : std_logic_vector(7 downto 0) := (others => '0');
    signal r_tx_strb : std_logic := '0';

begin

    -----------------------------------------------------------------
    -- REGISTER UPDATE ----------------------------------------------
    reg_update : process(clk) is
    begin
        if rising_edge(clk) then
            if rst then
                ctrl_state <= IDLE;
                tx_busy_i  <= '0';
                tx_cont    <= '0';
                tx_sel     <= '0';
                tx_ptr     <= 0;
                r_tx_out   <= (others => '0');
                r_tx_strb  <= '0';
            else
                ctrl_state <= next_state;
                tx_busy_i  <= next_tx_busy_i;
                tx_cont    <= next_tx_cont;
                tx_sel     <= next_tx_sel;
                tx_ptr     <= next_tx_ptr;
                r_tx_out   <= next_tx_out;
                r_tx_strb  <= next_tx_strb;
            end if;
        end if;
    end process;


    -----------------------------------------------------------------
    -- STATE UPDATE ----------------------------------------------
    state_update : process(all) is
    begin
        next_state <= ctrl_state;

        case ctrl_state is
            when IDLE =>
                if tx_cont = '1' then
                    next_state <= SHIFT;

                elsif btn_l_strb = '1' and tx_busy = '0' then
                    next_state <= SHIFT;

                elsif btn_r_strb = '1' and tx_busy = '0' then
                    next_state <= SHIFT;
                end if;

            when SHIFT =>
                next_state <= BUSY;

            when BUSY =>
                if tx_busy = '0' and tx_busy_i = '1' then
                    next_state <= IDLE;
                end if;
        end case;
    end process;


    -----------------------------------------------------------------
    -- OUTPUT UPDATE ----------------------------------------------
    output_update : process(all) is
    begin
        next_tx_busy_i <= tx_busy;
        next_tx_cont   <= tx_cont;
        next_tx_sel    <= tx_sel;
        next_tx_ptr    <= tx_ptr;
        next_tx_out    <= r_tx_out;
        next_tx_strb   <= '0';

        case ctrl_state is
            when IDLE =>
                if tx_cont = '1' then
                    if tx_sel = '0' then
                        next_tx_out <= hello_world_vec(tx_ptr + 7 downto tx_ptr);
                    else
                        next_tx_out <= in5200_vec(tx_ptr + 7 downto tx_ptr);
                    end if;

                    next_tx_strb <= '1';

                elsif btn_l_strb = '1' and tx_busy = '0' then
                    next_tx_sel <= '0';
                    next_tx_ptr <= MSG_MAX_1;

                    next_tx_out <= hello_world_vec(MSG_MAX_1 + 7 downto MSG_MAX_1);
                    next_tx_strb <= '1';

                elsif btn_r_strb = '1' and tx_busy = '0' then
                    next_tx_sel <= '1';
                    next_tx_ptr <= MSG_MAX_2;

                    next_tx_out <= in5200_vec(MSG_MAX_2 + 7 downto MSG_MAX_2);
                    next_tx_strb <= '1';

                elsif tx_busy = '0' and rx_strb = '1' then
                    next_tx_out <= rx_in;
                    next_tx_strb <= '1';
                end if;

            when SHIFT =>
                null;

            when BUSY =>
                if tx_busy = '0' and tx_busy_i = '1' then
                    if tx_ptr = 0 then
                        next_tx_cont <= '0';
                    else
                        next_tx_ptr  <= tx_ptr - 8;
                        next_tx_cont <= '1';
                    end if;
                end if;
        end case;
    end process;

    tx_out  <= r_tx_out;
    tx_strb <= r_tx_strb;

end architecture;
