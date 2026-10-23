library ieee;
use ieee.std_logic_1164.all;
use work.seven_seg_decode_pkg.all;

entity btn_counter is
    port(
        clk : in std_logic;
        rst_n : in std_logic;
        btn : in std_logic;

        seg : out std_logic_vector(6 downto 0)
    );
end entity;

architecture rtl of btn_counter is
    signal btn_count : integer range 0 to 15 := 0;
    signal btn_last : std_logic := '0';
    signal btn_db : std_logic := '0';

    signal reset_i : std_logic;
begin
    reset_i <= not rst_n;

    btn_debounce : entity work.btn_db
    port map(
        clk => clk,
        reset => reset_i,
        btn => not btn, -- buttons are active low on the tang nano
        btn_db => btn_db
    );

    process (clk) is
    begin
        if rising_edge(clk) then
            if reset_i then
                btn_count <= 0;
                btn_last <= '0';
            else
                if btn_db = '1' and btn_last = '0' then -- or it goes so fast it looks like 8
                    btn_count <= (btn_count + 1) mod 16;
                end if;
                btn_last <= btn_db;
            end if;
        end if;
    end process;

    seg <= to_svn_seg(btn_count);

end architecture;
