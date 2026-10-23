library ieee;
use ieee.std_logic_1164.all;

entity uart is
    port(
            clk     : in std_logic;
            rst_n   : in std_logic;
            btn_l   : in std_logic;
            btn_r   : in std_logic;
            rx      : in std_logic;
            tx      : out std_logic
        );
end entity;

architecture rtl of uart is
    signal rst : std_logic;

    signal rx_strb : std_logic := '0';
    signal rx_data : std_logic_vector(7 downto 0) := (others => '0');

    signal tx_strb : std_logic := '0';
    signal tx_busy : std_logic := '0';
    signal tx_data : std_logic_vector(7 downto 0) := (others => '0');

    signal btn_l_db   : std_logic := '0';
    signal btn_l_strb : std_logic := '0';
    signal btn_l_prev : std_logic := '0';
    signal btn_r_db   : std_logic := '0';
    signal btn_r_strb : std_logic := '0';
    signal btn_r_prev : std_logic := '0';
begin

    rst <= not rst_n;

    btn_l_debounce : entity work.btn_debounce
    port map(
                clk => clk,
                rst => rst,
                btn => not btn_l,
                btn_db => btn_l_db
            );
    btn_r_debounce : entity work.btn_debounce
    port map(
                clk => clk,
                rst => rst,
                btn => not btn_r,
                btn_db => btn_r_db
            );
    edge_detect : process(clk) is
    begin
        if rising_edge(clk) then
            if (rst) then
                btn_l_prev <= '0';
                btn_r_prev <= '0';
            else
                btn_r_prev <= btn_r_db;
                btn_l_prev <= btn_l_db;
            end if;
        end if;
    end process;

    btn_l_strb <= btn_l_db and (not btn_l_prev);
    btn_r_strb <= btn_r_db and (not btn_r_prev);

    rx_uart : entity work.uart_rx
    port map(
                clk => clk,
                rst => rst,
                rx => rx,
                dout => rx_data,
                strb => rx_strb
            );
    tx_uart : entity work.uart_tx
    port map(
                clk => clk,
                rst => rst,
                din => tx_data,
                strb => tx_strb,
                busy => tx_busy,
                tx => tx
            );

    crtl_uart : entity work.uart_ctrl
    port map(
                clk => clk,
                rst => rst,
                btn_r_strb => btn_r_strb,
                btn_l_strb => btn_l_strb,
                rx_in => rx_data,
                rx_strb => rx_strb,
                tx_busy => tx_busy,
                tx_out => tx_data,
                tx_strb => tx_strb
            );

end architecture;
