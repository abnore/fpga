library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Asynchronous FIFO using a circular buffer and Gray-coded pointers.
-- Read and write channels operate on independent clocks.
-- Writes are ignored when full, and reads are ignored when empty.
-- Pointers are synchronized between clock domains using two flip-flops.
-- FIFO_DEPTH must be a power of two, with a minimum depth of 2.

entity fifo_async is
    generic(
        FIFO_DEPTH : positive := 8;
        DATA_WIDTH : positive := 8
    );
    port(
        wr_clk  : in std_logic;
        rd_clk  : in std_logic;
        rst     : in std_logic;

        -- Flags
        full    : out std_logic;
        empty   : out std_logic;

        -- Write channel
        wr_en   : in std_logic;
        wr_data : in std_logic_vector(DATA_WIDTH-1 downto 0);

        -- Read channel
        rd_strb : in std_logic;
        rd_data : out std_logic_vector(DATA_WIDTH-1 downto 0)
    );
end entity;


architecture rtl of fifo_async is

    -- Calculate number of address bits needed for the FIFO.
    function clog2(n : positive) return natural is
        variable bits : natural := 0;
        variable size : positive := 1;
    begin
        while size < n loop
            size := size * 2;
            bits := bits + 1;
        end loop;

        return bits;
    end function;

    -- Convert binary pointer to Gray code.
    -- Only one bit changes between consecutive Gray values.
    function bin2gray(b : unsigned) return unsigned is
    begin
        return b xor shift_right(b, 1);
    end function;

    constant ADDR_BITS : natural := clog2(FIFO_DEPTH);
    constant PTR_BITS  : natural := ADDR_BITS + 1;

    -- Mask used to invert the two highest Gray-code bits.
    constant FULL_MASK : unsigned(PTR_BITS-1 downto 0) :=
        shift_left(to_unsigned(3, PTR_BITS), PTR_BITS-2);

    -- Circular buffer
    type mem is array (0 to FIFO_DEPTH-1)
        of std_logic_vector(DATA_WIDTH-1 downto 0);

    signal fifo_mem : mem;

    -- Binary pointers: extra bit distinguishes full from empty.
    signal r_wr_bin : unsigned(PTR_BITS-1 downto 0) := (others => '0');
    signal r_rd_bin : unsigned(PTR_BITS-1 downto 0) := (others => '0');

    -- Gray-coded pointers
    signal r_wr_gray : unsigned(PTR_BITS-1 downto 0) := (others => '0');
    signal r_rd_gray : unsigned(PTR_BITS-1 downto 0) := (others => '0');

    -- Next pointer values
    signal wr_bin_next  : unsigned(PTR_BITS-1 downto 0);
    signal rd_bin_next  : unsigned(PTR_BITS-1 downto 0);

    signal wr_gray_next : unsigned(PTR_BITS-1 downto 0);
    signal rd_gray_next : unsigned(PTR_BITS-1 downto 0);

    -- Read pointer synchronized into write clock domain
    signal rd_sync1 : unsigned(PTR_BITS-1 downto 0) := (others => '0');
    signal rd_sync2 : unsigned(PTR_BITS-1 downto 0) := (others => '0');

    -- Write pointer synchronized into read clock domain
    signal wr_sync1 : unsigned(PTR_BITS-1 downto 0) := (others => '0');
    signal wr_sync2 : unsigned(PTR_BITS-1 downto 0) := (others => '0');

    -- Local reset synchronizers (asynchronous assertion)
    signal wr_rst_pipe : std_logic_vector(1 downto 0) := (others => '1');
    signal rd_rst_pipe : std_logic_vector(1 downto 0) := (others => '1');

    signal wr_rst, rd_rst : std_logic;

    -- Registered status flags
    signal r_full  : std_logic := '0';
    signal r_empty : std_logic := '1';

    signal do_write, do_read : std_logic;

begin

    assert FIFO_DEPTH >= 2 and 2**ADDR_BITS = FIFO_DEPTH
        report "FIFO_DEPTH must be a power of two and at least 2"
        severity failure;

    full  <= r_full;
    empty <= r_empty;

    wr_rst <= wr_rst_pipe(1);
    rd_rst <= rd_rst_pipe(1);

    -- A reset is asserted immediately, but released separately
    -- after two clock edges in each domain.
    wr_reset_sync : process(wr_clk, rst)
    begin
        if rst = '1' then
            wr_rst_pipe <= (others => '1');
        elsif rising_edge(wr_clk) then
            wr_rst_pipe <= wr_rst_pipe(0) & '0';
        end if;
    end process;

    rd_reset_sync : process(rd_clk, rst)
    begin
        if rst = '1' then
            rd_rst_pipe <= (others => '1');
        elsif rising_edge(rd_clk) then
            rd_rst_pipe <= rd_rst_pipe(0) & '0';
        end if;
    end process;

    -- Accept transfers only when permitted by the local flags.
    do_write <= wr_en and not r_full  and not wr_rst;
    do_read  <= rd_strb and not r_empty and not rd_rst;

    -- Calculate the next binary pointer only when a transfer occurs.
    wr_bin_next <= r_wr_bin + 1 when do_write = '1' else r_wr_bin;
    rd_bin_next <= r_rd_bin + 1 when do_read  = '1' else r_rd_bin;

    wr_gray_next <= bin2gray(wr_bin_next);
    rd_gray_next <= bin2gray(rd_bin_next);


    -- WRITE CLOCK DOMAIN --------------------------------------------

    write_proc : process(wr_clk)
    begin
        if rising_edge(wr_clk) then
            if wr_rst = '1' then
                r_wr_bin  <= (others => '0');
                r_wr_gray <= (others => '0');
                r_full    <= '0';
            else
                if do_write = '1' then
                    fifo_mem(to_integer(r_wr_bin(ADDR_BITS-1 downto 0)))
                        <= wr_data;
                end if;

                r_wr_bin  <= wr_bin_next;
                r_wr_gray <= wr_gray_next;

                -- Full when the next write pointer has wrapped around
                -- to the synchronized read pointer.
                if wr_gray_next = (rd_sync2 xor FULL_MASK) then
                    r_full <= '1';
                else
                    r_full <= '0';
                end if;
            end if;
        end if;
    end process;


    -- READ CLOCK DOMAIN ---------------------------------------------

    read_proc : process(rd_clk)
    begin
        if rising_edge(rd_clk) then
            if rd_rst = '1' then
                r_rd_bin  <= (others => '0');
                r_rd_gray <= (others => '0');
                rd_data   <= (others => '0');
                r_empty   <= '1';
            else
                if do_read = '1' then
                    rd_data <= fifo_mem(
                        to_integer(r_rd_bin(ADDR_BITS-1 downto 0))
                    );
                end if;

                r_rd_bin  <= rd_bin_next;
                r_rd_gray <= rd_gray_next;

                -- Empty when the next read pointer equals
                -- the synchronized write pointer.
                if rd_gray_next = wr_sync2 then
                    r_empty <= '1';
                else
                    r_empty <= '0';
                end if;
            end if;
        end if;
    end process;


    -- CLOCK DOMAIN CROSSING -----------------------------------------

    -- Read pointer crosses into the write clock domain.
    rd_sync_proc : process(wr_clk)
    begin
        if rising_edge(wr_clk) then
            if wr_rst = '1' then
                rd_sync1 <= (others => '0');
                rd_sync2 <= (others => '0');
            else
                rd_sync1 <= r_rd_gray;
                rd_sync2 <= rd_sync1;
            end if;
        end if;
    end process;

    -- Write pointer crosses into the read clock domain.
    wr_sync_proc : process(rd_clk)
    begin
        if rising_edge(rd_clk) then
            if rd_rst = '1' then
                wr_sync1 <= (others => '0');
                wr_sync2 <= (others => '0');
            else
                wr_sync1 <= r_wr_gray;
                wr_sync2 <= wr_sync1;
            end if;
        end if;
    end process;

end architecture;
