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
--  Data length Code CAN 2.0 more than 8 bytes feature test.
--
-- @Verifies:
--  @1. When transmission of CAN 2.0 frame with DLC higher than 8 is requested,
--      only 8 bytes are transmitted!
--
-- @Test sequence:
--   @1. Generate CAN 2.0 Frame and set DLC higher than 8. Set higher data
--       bytes accordingly!
--   @2. Send the CAN Frame via DUT. Monitor the bus and check that only
--       8 bytes are sent!
--   @3. Verify that frame received by Test node, has the same DLC, but is has
--       received only 8 bytes of Data!
--
-- @TestInfoEnd
--------------------------------------------------------------------------------
-- Revision History:
--    14.7.2018   Created file
--   21.10.2018   Add check monitoring data field length.
--------------------------------------------------------------------------------

Library ctu_can_fd_tb;
context ctu_can_fd_tb.ieee_context;
context ctu_can_fd_tb.rtl_context;
context ctu_can_fd_tb.tb_common_context;

use ctu_can_fd_tb.feature_test_agent_pkg.all;

package dlc_can20_8_64_bytes_ftest is
    procedure dlc_can20_8_64_bytes_ftest_exec(
        signal      chn             : inout  t_com_channel
    );
end package;


package body dlc_can20_8_64_bytes_ftest is
    procedure dlc_can20_8_64_bytes_ftest_exec(
        signal      chn             : inout  t_com_channel
    ) is
        variable can_frame          :        t_ctu_frame;
        variable can_frame_2        :        t_ctu_frame  := SW_CAN_Frame_type_rst_val;
        variable frame_sent         :        boolean;
        variable ff             :        t_ctu_frame_field;
    begin

        ------------------------------------------------------------------------
        -- @1. Generate CAN 2.0 Frame and set DLC higher than 8. Set higher data
        --     bytes accordingly!
        ------------------------------------------------------------------------
        info_m("Step 1: Generate frame");

        generate_can_frame(can_frame);
        rand_logic_vect_v(can_frame.dlc, 0.5);
        -- Set highest bit to 1 -> DLC will be always more than 8!
        can_frame.dlc(3) := '1';
        can_frame.rtr := NO_RTR_FRAME;
        can_frame.frame_format := NORMAL_CAN;
        dlc_to_length(can_frame.dlc, can_frame.data_length);
        for i in 0 to can_frame.data_length - 1 loop
            rand_logic_vect_v(can_frame.data(i), 0.5);
        end loop;

        ------------------------------------------------------------------------
        -- @2. Send the CAN Frame via DUT. Monitor the bus and check that only
        --     8 bytes are sent!
        ------------------------------------------------------------------------
        info_m("Step 2: Send frame");

        ctu_send_frame(can_frame, 1, DUT_NODE, chn, frame_sent);
        ctu_wait_ff(ff_data, DUT_NODE, chn);

        for i in 0 to 63 loop
            ctu_wait_sample_point(DUT_NODE, chn);
            wait for 11 ns; -- for DFF to flip

            ctu_get_curr_ff(ff, DUT_NODE, chn);

            if (i = 63) then
                check_false_m(ff = ff_data,
                    "After 64 bytes data field ended!");
            else
                check_m(ff = ff_data,
                        "Before 64 bytes data field goes on!");
            end if;
        end loop;
        ctu_wait_bus_idle(DUT_NODE, chn);
        ctu_wait_bus_idle(TEST_NODE, chn);

        wait for 500 ns;

        ------------------------------------------------------------------------
        -- @3. Verify that frame received by Test node, has the same DLC, but
        --     it has received only 8 bytes of Data!
        ------------------------------------------------------------------------
        info_m("Step 3: Check frame received!");
        ctu_read_frame(can_frame_2, TEST_NODE, chn);
        check_m(can_frame_2.dlc = can_frame.dlc, "Invalid DLC received!");
        check_m(can_frame_2.rwcnt = 5, "Invalid DLC received!");

        for i in 8 to 63 loop
            check_m(can_frame_2.data(i) = "00000000",
                    "Byte index " & integer'image(i) & " not zero!");
        end loop;

  end procedure;
end package body;
