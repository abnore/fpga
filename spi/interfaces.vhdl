library ieee;
use ieee.std_logic_1164.all;

-- even though GHDL now supports this, synthesize has a bug and use of views
-- does not work as intended.

package interfaces is

    type spi_wires is record
        sck : std_logic;
        mosi : std_logic;
        miso : std_logic;
    end record;

    view spi_master_view of spi_wires is
        sck, mosi : out;
        miso : in;
    end view;

    alias spi_slave_view is spi_master_view'converse;

end package;
