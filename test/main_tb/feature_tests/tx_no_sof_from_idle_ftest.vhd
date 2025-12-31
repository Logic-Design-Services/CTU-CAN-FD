--------------------------------------------------------------------------------
--
-- CTU CAN FD IP Core
-- Copyright (C) 2021-present Ondrej Ille
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this VHDL component and associated documentation files (the "Component"),
-- to use, copy, modify, merge, publish, distribute the Component for
-- educational, research, evaluation, self-interest purposes. Using the
-- Component for commercial purposes is forbidden unless previously agreed with
-- Copyright holder.
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
--  Transmitt from Idle without Start of Frame test
--
-- @Verifies:
--  @1. When node has a frame to transmit and detects dominant bit during
--      bus idle, it transmitts frame without SOF bit.
--
-- @Test sequence:
--  @1. Generate CAN frame and insert it to DUT for transmission.
--  @2. Wait until sample point, and mark the frame as ready. Then wait until
--      Sync segment and force bus level dominant.
--      Wait until Sample point and release the force.
--  @3. Check DUT became transmitter, and is already transmitting arbitration.
--      Wait until the frame is sent, read it from Test Node and check it
--      matches the transmitted frame.
--
-- @TestInfoEnd
--------------------------------------------------------------------------------
-- Revision History:
--     31.12.2025   Created file
--------------------------------------------------------------------------------

Library ctu_can_fd_tb;
context ctu_can_fd_tb.ieee_context;
context ctu_can_fd_tb.rtl_context;
context ctu_can_fd_tb.tb_common_context;

use ctu_can_fd_tb.feature_test_agent_pkg.all;

package tx_no_sof_from_idle_ftest is
    procedure tx_no_sof_from_idle_ftest_exec(
        signal      chn             : inout  t_com_channel
    );
end package;

package body tx_no_sof_from_idle_ftest is

    procedure tx_no_sof_from_idle_ftest_exec(
        signal      chn             : inout  t_com_channel
    ) is
        variable can_frame_tx       :       t_ctu_frame;
        variable can_frame_rx       :       t_ctu_frame;
        variable status             :       t_ctu_status;
        variable ff                 :       t_ctu_frame_field;
        variable frames_equal       :       boolean;
    begin

        -------------------------------------------------------------------------------------------
        --  @1. Generate CAN frame and insert it to DUT for transmission.
        -------------------------------------------------------------------------------------------
        info_m("Step 1");

        generate_can_frame(can_frame_tx);
        ctu_put_tx_frame(can_frame_tx, 1, DUT_NODE, chn);

        -------------------------------------------------------------------------------------------
        --  @2. Wait until sample point, and mark the frame as ready. Then wait until
        --      Sync segment and force bus level dominant.
        --      Wait until Sample point and release the force.
        -------------------------------------------------------------------------------------------
        info_m("Step 2");

        ctu_wait_sample_point(DUT_NODE, chn);
        ctu_wait_input_delay(chn);

        ctu_give_txt_cmd(buf_set_ready, 1, DUT_NODE, chn);

        ctu_wait_sync_seg(DUT_NODE, chn);
        force_bus_level(DOMINANT, chn);
        ctu_wait_sample_point(DUT_NODE, chn);
        ctu_wait_input_delay(chn);
        release_bus_level(chn);

        -------------------------------------------------------------------------------------------
        --  @3. Check DUT became transmitter, and is already transmitting arbitration.
        --      Wait until the frame is sent, read it from Test Node and check it
        --      matches the transmitted frame.
        -------------------------------------------------------------------------------------------
        info_m("Step 3");

        ctu_get_curr_ff(ff, DUT_NODE, chn);
        check_m(ff = ff_arbitration, "Protocol control in arbitration!");

        ctu_get_status(status, DUT_NODE, chn);
        check_m(status.transmitter, "DUT is transmitter");

        ctu_wait_bus_idle(DUT_NODE, chn);
        ctu_wait_bus_idle(TEST_NODE, chn);

        ctu_read_frame(can_frame_rx, TEST_NODE, chn);

        compare_can_frames(can_frame_rx, can_frame_tx, false, frames_equal);
        check_m(frames_equal, "TX Frame = RX Frame");

    end procedure;
end package body;
