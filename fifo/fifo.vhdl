library ieee;
use ieee.std_logic_1164.all;

-- Basic implementation of a synchronous FIFO using a circular buffer.
-- Supports simultaneous reads and writes.
-- Writes are ignored when full, and reads are ignored when empty.
-- Full and empty status are indicated by the corresponding output flags.

entity fifo is
    generic(
        FIFO_DEPTH : integer := 8; -- How many spots, this can be huge
        DATA_WIDTH : integer := 8  -- How many bits for each spot
    );
    port(
        clk     : in std_logic;
        rst     : in std_logic;
        -- flags
        full    : out std_logic;
        empty   : out std_logic;
        -- control signals
        wr_en   : in std_logic;
        wr_data : in std_logic_vector(DATA_WIDTH-1 downto 0);
        rd_strb : in std_logic;
        rd_data : out std_logic_vector(DATA_WIDTH-1 downto 0)
    );
end entity;

architecture rtl of fifo is
    type mem is array (0 to FIFO_DEPTH-1) of std_logic_vector(DATA_WIDTH-1 downto 0);
    signal fifo_mem : mem := (others => (others => '0'));

    signal r_wr_ptr   : integer range 0 to FIFO_DEPTH-1 := 0;
    signal r_rd_ptr   : integer range 0 to FIFO_DEPTH-1 := 0;
    signal r_count    : integer range 0 to FIFO_DEPTH   := 0; -- not indecies

    signal do_write, do_read : std_logic;

begin
    -- Legal from VHDL-2008 to read out signals, no need for internals
    do_write <= wr_en and not full;
    do_read  <= rd_strb and not empty;

    -- Read channel only driving the reading and using a ring buffer
    read_proc : process(clk) is
    begin
        if rising_edge(clk) then
            if rst then
                r_rd_ptr  <= 0;
                rd_data <= (others => '0');

            elsif do_read then
                rd_data <= fifo_mem(r_rd_ptr);

                if r_rd_ptr = FIFO_DEPTH - 1 then
                    r_rd_ptr <= 0;
                else
                    r_rd_ptr <= r_rd_ptr + 1;
                end if;
            end if;
        end if;
    end process;

    -- Write channel only driving the writing, also using the same ring buffer
    write_proc : process(clk) is
    begin
        if rising_edge(clk) then
            if rst then
                r_wr_ptr <= 0;
            elsif do_write then
                fifo_mem(r_wr_ptr) <= wr_data;

                if r_wr_ptr = FIFO_DEPTH - 1 then
                    r_wr_ptr <= 0;
                else
                    r_wr_ptr <= r_wr_ptr + 1;
                end if;
            end if;
        end if;
    end process;

    -- Counting how many spots are taken, driving the full and empty flags
    count_proc : process(clk) is
    begin
        if rising_edge(clk) then
            if rst then
                r_count <= 0;
            else
                if do_write = '1' and do_read = '0' then
                    r_count <= r_count + 1;
                elsif do_write = '0' and do_read = '1' then
                    r_count <= r_count - 1;
                end if;
            end if;
        end if;
    end process;

    full <= '1' when r_count = FIFO_DEPTH else '0';
    empty <= '1' when r_count = 0 else '0';

end architecture;
