--------------------------------------------------------------------------------
--
-- Register map generation tool
--
-- Copyright (C) 2018 Ondrej Ille <ondrej.ille@gmail.com>
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this SW component and associated documentation files (the "Component"),
-- to deal in the Component without restriction, including without limitation
-- the rights to use, copy, modify, merge, publish, distribute, sublicense,
-- and/or sell copies of the Component, and to permit persons to whom the
-- Component is furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Component.
--
-- THE COMPONENT IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHTHOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
-- FROM, OUT OF OR IN CONNECTION WITH THE COMPONENT OR THE USE OR OTHER DEALINGS
-- IN THE COMPONENT.
--
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Purpose:
--   Access signaller indicating read access to a given register.
--------------------------------------------------------------------------------
-- Revision History:
--    25.10.2018   Created file
--------------------------------------------------------------------------------

Library ieee;
USE IEEE.std_logic_1164.all;
USE IEEE.numeric_std.ALL;

entity read_access_signaller is
    generic(
        -- Width of memory register whose access is being signalled
        constant data_width           :     natural := 32
    );
    port(
        ------------------------------------------------------------------------
        -- Clock and reset
        ------------------------------------------------------------------------
        signal clk_sys                :in   std_logic;
        signal res_n                  :in   std_logic;

        ------------------------------------------------------------------------
        -- Chip select (from address decoder)
        ------------------------------------------------------------------------
        signal cs                     :in   std_logic;

        ------------------------------------------------------------------------
        -- Memory access signals
        ------------------------------------------------------------------------
        signal read                   :in   std_logic;
        signal be                     :in   std_logic_vector(data_width / 8 - 1 downto 0);

        ------------------------------------------------------------------------
        -- Signalling outputs
        ------------------------------------------------------------------------
        signal read_signal            :out  std_logic
    );

end entity read_access_signaller;

architecture rtl of read_access_signaller is

    -- Byte enable zeros
    constant BE_ZEROES      : std_logic_vector(data_width / 8 - 1 downto 0) := (OTHERS => '0');

begin

    ---------------------------------------------------------------------------
    -- Read signalling
    ---------------------------------------------------------------------------
    read_signal  <= (read and cs) when (be /= BE_ZEROES)
                                  else
                              '0';

end architecture;
