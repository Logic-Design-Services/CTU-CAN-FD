--------------------------------------------------------------------------------
--
-- CTU CAN FD IP Core
-- Copyright (C) 2021-2023 Ondrej Ille
-- Copyright (C) 2023-     Logic Design Services Ltd.s
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this VHDL component and associated documentation files (the "Component"),
-- to use, copy, modify, merge, publish, distribute the Component for
-- non-commercial purposes. Using the Component for commercial purposes is
-- forbidden unless previously agreed with Copyright holder.
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
-- The CAN protocol is developed by Robert Bosch GmbH and protected by patents.
-- Anybody who wants to implement this IP core on silicon has to obtain a CAN
-- protocol license from Bosch.
--
-- -------------------------------------------------------------------------------
--
-- CTU CAN FD IP Core
-- Copyright (C) 2015-2020 MIT License
--
-- Authors:
--     Ondrej Ille <ondrej.ille@gmail.com>
--     Martin Jerabek <martin.jerabek01@gmail.com>
--
-- Project advisors:
-- 	Jiri Novak <jnovak@fel.cvut.cz>
-- 	Pavel Pisa <pisa@cmp.felk.cvut.cz>
--
-- Department of Measurement         (http://meas.fel.cvut.cz/)
-- Faculty of Electrical Engineering (http://www.fel.cvut.cz)
-- Czech Technical University        (http://www.cvut.cz/)
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this VHDL component and associated documentation files (the "Component"),
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
-- The CAN protocol is developed by Robert Bosch GmbH and protected by patents.
-- Anybody who wants to implement this IP core on silicon has to obtain a CAN
-- protocol license from Bosch.
--
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- @TestInfoStart
--
-- @Purpose:
--  Feature test verifying read access to TXT Buffer.
--
-- @Verifies:
--  @1. Verifies that read access to TXT Buffer returns all zeroes.
--
-- @Test sequence:
--  @1. Get Number of existing TXT Buffers
--  @2. Iterate all TXT Buffers
--      @2.1 Generate random CAN frame, and store it to the TXT Buffer.
--      @2.2 Try to read the TXT Buffer and check zeroes are returned.
--
-- @TestInfoEnd
--------------------------------------------------------------------------------
-- Revision History:
--    12.06.2019   Created file
--------------------------------------------------------------------------------

Library ctu_can_fd_tb;
context ctu_can_fd_tb.ieee_context;
context ctu_can_fd_tb.rtl_context;
context ctu_can_fd_tb.tb_common_context;

use ctu_can_fd_tb.feature_test_agent_pkg.all;

package txt_buffer_read_access_ftest is
    procedure txt_buffer_read_access_ftest_exec(
        signal      chn             : inout  t_com_channel
    );
end package;


package body txt_buffer_read_access_ftest is
    procedure txt_buffer_read_access_ftest_exec(
        signal      chn             : inout  t_com_channel
    ) is
        -- Generated frames
        variable frame_tx           :     t_ctu_frame;

        variable txtb_cnt           :     natural;
        variable buf_offset         :     std_logic_vector(11 downto 0);
        variable addr               :     std_logic_vector(11 downto 0);
        variable r_data             :     std_logic_vector(31 downto 0);
    begin

        -----------------------------------------------------------------------
        -- @1. Get Number of existing TXT Buffers
        -----------------------------------------------------------------------
        info_m("Step 1");

        ctu_get_txt_buf_cnt(txtb_cnt, DUT_NODE, chn);

        -----------------------------------------------------------------------
        -- @2. Iterate all TXT Buffers
        -----------------------------------------------------------------------
        info_m("Step 2");

        for txt_buf_index in 1 to txtb_cnt loop

            -------------------------------------------------------------------
            -- @2.1 Generate random CAN frame, and store it to the TXT Buffer.
            -------------------------------------------------------------------
            info_m("Step 2.1");

            generate_can_frame(frame_tx);
            ctu_put_tx_frame(frame_tx, txt_buf_index, DUT_NODE, chn);

            -------------------------------------------------------------------
            -- @2.2 Try to read the TXT Buffer and check zeroes are returned.
            -------------------------------------------------------------------
            info_m("Step 2.2");

            -- Try to read each word
            case txt_buf_index is
            when 1 => buf_offset := TXTB1_DATA_1_ADR;
            when 2 => buf_offset := TXTB2_DATA_1_ADR;
            when 3 => buf_offset := TXTB3_DATA_1_ADR;
            when 4 => buf_offset := TXTB4_DATA_1_ADR;
            when 5 => buf_offset := TXTB5_DATA_1_ADR;
            when 6 => buf_offset := TXTB6_DATA_1_ADR;
            when 7 => buf_offset := TXTB7_DATA_1_ADR;
            when others => buf_offset := TXTB8_DATA_1_ADR;
            end case;

            for i in 0 to 20 loop
                addr := std_logic_vector(unsigned(buf_offset) + to_unsigned(i * 4, 12));
                ctu_read(r_data, addr, DUT_NODE, chn);

                check_m(r_data = x"00000000", "TXT Buffer: " & integer'image(i) &
                                              " address: " & to_hstring(addr));
            end loop;

        end loop;

  end procedure;

end package body;
