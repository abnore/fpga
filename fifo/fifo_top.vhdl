library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity fifo_top is
    port (
    clk     : in std_logic;
    rst_n   : in std_logic; -- reset button
    cnt_n   : in std_logic; -- counter button, next to reset
    rd      : in std_logic; -- read button (right)
    wr      : in std_logic; -- write button (left)
    led     : out  std_logic_vector(5 downto 0); -- 6 leds on chip, 4 used
    green   : out std_logic; -- led for empty flag
    red     : out std_logic; -- led for full flag
    seg     : out std_logic_vector(6 downto 0)
);
end entity;

architecture rtl of fifo_top is
    signal rst : std_logic;
    signal cnt : std_logic;
    signal rd_db : std_logic;
    signal wr_db : std_logic;
    signal cnt_db : std_logic;

    signal counter : integer range 0 to 15 := 0;

    signal rd_prev : std_logic := '0';
    signal wr_prev : std_logic := '0';
    signal cnt_prev : std_logic := '0';

    signal wr_en : std_logic;
    signal rd_en : std_logic;
    signal cnt_en : std_logic;
    signal full  : std_logic;
    signal empty : std_logic;
    signal rd_data : std_logic_vector(3 downto 0);
begin

    rst <= not rst_n;
    cnt <= not cnt_n;

    rd_debouncer : entity work.btn_debounce
    port map(
        clk => clk,
        rst => rst,
        btn => not rd,
        btn_db => rd_db
    );

    wr_debouncer : entity work.btn_debounce
    port map(
        clk => clk,
        rst => rst,
        btn => not wr,
        btn_db => wr_db
    );

    cnt_debouncer : entity work.btn_debounce
    port map(
        clk => clk,
        rst => rst,
        btn => cnt,
        btn_db => cnt_db
    );

    edge_detect : process(clk) is
    begin
        if rising_edge(clk) then
            if rst then
                rd_prev <= '0';
                wr_prev <= '0';
                cnt_prev <= '0';
            else
                rd_prev <= rd_db;
                wr_prev <= wr_db;
                cnt_prev <= cnt_db;
            end if;
        end if;
    end process;

    rd_en <= rd_db and (not rd_prev);
    wr_en <= wr_db and (not wr_prev);
    cnt_en <= cnt_db and (not cnt_prev);

    fifo_inst : entity work.fifo
    generic map( DATA_WIDTH => 4)
    port map(
        clk => clk,
        rst => rst,
        wr_en => wr_en,
        wr_data => std_logic_vector(to_unsigned(counter, 4)),
        rd_strb => rd_en,
        rd_data => rd_data,
        full => full,
        empty => empty
    );

    seg_inst : entity work.seg_driver
    port map(
        clk => clk,
        rst => rst,
        din => rd_data,
        seg => seg
    );

    green <= empty;
    red <= full;

    process(clk) is
    begin
        if rising_edge(clk) then
            if rst or wr_en then
                counter <= 0;
            else
                counter <= (counter + 1) mod 16 when cnt_en;
            end if;
        end if;
    end process;

    led <= std_logic_vector(not(to_unsigned(counter, led'length)));

end architecture;
