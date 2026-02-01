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
--  ERR_CAPT[ERR_POS] = ERC_POS_EOF. Error code capture in End of frame feature
--  test.
--
-- @Verifies:
--  @1. Detection of Form error in End of frame field. Value of ERR_CAPT when
--      Form Error should have been detected in EOF field.
--
-- @Test sequence:
--  @1. Check that ERR_CAPT contains no error (post reset).
--  @2. Generate CAN frame and send it by DUT. Wait until End of frame field
--      of DUT and wait for random number of bits (between 0 and 4). Force
--      bus level dominant and wait until sample point. Check that Error frame
--      is being transmitted and check value of ERR_CAPT.
--
-- @TestInfoEnd
--------------------------------------------------------------------------------
-- Revision History:
--    12.01.2020   Created file
--------------------------------------------------------------------------------

Library ctu_can_fd_tb;
context ctu_can_fd_tb.ieee_context;
context ctu_can_fd_tb.rtl_context;
context ctu_can_fd_tb.tb_common_context;

use ctu_can_fd_tb.feature_test_agent_pkg.all;

package err_capt_eof_ftest is
    procedure err_capt_eof_ftest_exec(
        signal      chn             : inout  t_com_channel
    );
end package;


package body err_capt_eof_ftest is
    procedure err_capt_eof_ftest_exec(
        signal      chn             : inout  t_com_channel
    ) is
        -- Generated frames
        variable frame_1            :     t_ctu_frame;

        -- Node status
        variable stat_1             :     t_ctu_status;
        variable stat_2             :     t_ctu_status;

        variable ff             :     t_ctu_frame_field;

        variable frame_sent         :     boolean;

        variable err_capt           :     t_ctu_err_capt;
        variable mode_2             :     t_ctu_mode := t_ctu_mode_rst_val;
        variable wait_time          :     natural;
    begin

        -----------------------------------------------------------------------
        -- @1. Check that ERR_CAPT contains no error (post reset).
        -----------------------------------------------------------------------
        info_m("Step 1");

        ctu_get_err_capt(err_capt, DUT_NODE, chn);
        check_m(err_capt.err_pos = err_pos_other, "Reset of ERR_CAPT!");

        -----------------------------------------------------------------------
        -- @2. Generate CAN frame and send it by DUT. Wait until End of
        --     frame field of DUT and wait for random number of bits
        --     (between 0 and 4). Force bus level dominant and wait until
        --     sample point. Check that Error frame is being transmitted and
        --     check value of ERR_CAPT.
        -----------------------------------------------------------------------
        info_m("Step 2");

        generate_can_frame(frame_1);
        ctu_send_frame(frame_1, 1, DUT_NODE, chn, frame_sent);

        ctu_wait_ff(ff_eof, DUT_NODE, chn);
        wait for 30 ns;

        rand_int_v(4, wait_time);
        info_m("waiting for:" & integer'image(wait_time) & " bits!");
        wait_time := wait_time + 1;
        for i in 1 to wait_time loop
            ctu_wait_sample_point(DUT_NODE, chn);
        end loop;
        wait for 1 ns;

        force_bus_level(DOMINANT, chn);
        ctu_wait_sample_point(DUT_NODE, chn);
        ctu_wait_input_delay(chn);
        release_bus_level(chn);

        ctu_get_err_capt(err_capt, DUT_NODE, chn);
        check_m(err_capt.err_type = can_err_form, "Form error detected!");
        check_m(err_capt.err_pos = err_pos_eof,
            "Error detected in EOF field!");

        ctu_wait_bus_idle(DUT_NODE, chn);
        ctu_wait_bus_idle(TEST_NODE, chn);

  end procedure;

end package body;
