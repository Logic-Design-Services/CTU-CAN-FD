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
--  RX Error logging feature test 6
--
-- @Verifies:
--  @1. RX Error frame is logged correctly in RX Buffer when Error frame occurs
--      right after Metadata word is stored.
--
-- @Test sequence:
--  @1. Configure DUT to MODE[ERFM] = 1, and enable Loopback mode in DUT.
--      Set DUT to One-shot mode.
--  @2. Generate CAN frame and send it byt Test Node. Wait until frame is sent.
--  @3. Generate CAN frame and send it by DUT Node. Wait until last bit of
--      DLC and flip bus value.
--  @4. Wait until error frame in DUT Node, release bus value. Check DUTs RX
--      Buffer contains a two RX frames. Wait until bus is idle.
--  @5. Generate CAN frame and send it byt Test Node. Wait until frame is sent.
--  @6. Read all 3 frames from DUTs RX Buffer, and check that first and third
--      frames are CAN frames matching first and third transmitted frame. Check
--      that secodn frame is an Error frame.
--
-- @TestInfoEnd
--------------------------------------------------------------------------------
-- Revision History:
--    24.8.2024   Created file
--------------------------------------------------------------------------------

Library ctu_can_fd_tb;
context ctu_can_fd_tb.ieee_context;
context ctu_can_fd_tb.rtl_context;
context ctu_can_fd_tb.tb_common_context;

use ctu_can_fd_tb.feature_test_agent_pkg.all;

package rx_err_log_6_ftest is
    procedure rx_err_log_6_ftest_exec(
        signal      chn             : inout  t_com_channel
    );
end package;


package body rx_err_log_6_ftest is

    procedure rx_err_log_6_ftest_exec(
        signal      chn             : inout  t_com_channel
    ) is
        variable mode_1             : t_ctu_mode := t_ctu_mode_rst_val;

        variable tx_frame_1         : t_ctu_frame;
        variable tx_frame_2         : t_ctu_frame;
        variable tx_frame_3         : t_ctu_frame;

        variable rx_frame_1         : t_ctu_frame;
        variable rx_frame_2         : t_ctu_frame;
        variable rx_frame_3         : t_ctu_frame;

        variable frames_match       : boolean;
        variable frame_sent         : boolean;

        variable rx_buf_state        : t_ctu_rx_buf_state;
    begin

        -------------------------------------------------------------------------------------------
        -- @1. Configure DUT to MODE[ERFM] = 1, and enable Loopback mode in DUT.
        --     Set DUT to One-shot mode.
        -------------------------------------------------------------------------------------------
        info_m("Step 1");

        mode_1.error_logging := true;
        mode_1.internal_loopback := true;
        ctu_set_mode(mode_1, DUT_NODE, chn);

        ctu_set_retr_limit(true, 0, DUT_NODE, chn);

        -------------------------------------------------------------------------------------------
        -- @2. Generate CAN frame and send it byt Test Node. Wait until frame is sent.
        -------------------------------------------------------------------------------------------
        info_m("Step 2");

        generate_can_frame(tx_frame_1);
        ctu_send_frame(tx_frame_1, 1, TEST_NODE, chn, frame_sent);
        ctu_wait_frame_sent(DUT_NODE, chn);

        -------------------------------------------------------------------------------------------
        -- @3. Generate CAN frame and send it by DUT Node. Wait until last bit of
        --     DLC and flip bus value.
        -------------------------------------------------------------------------------------------
        info_m("Step 3");

        generate_can_frame(tx_frame_2);
        tx_frame_2.frame_format := NORMAL_CAN;
        tx_frame_2.rtr := NO_RTR_FRAME;
        tx_frame_2.ident_type := BASE;
        tx_frame_2.identifier := tx_frame_2.identifier mod 2**11;

        ctu_send_frame(tx_frame_2, 1, DUT_NODE, chn, frame_sent);
        ctu_wait_frame_start(true, false, DUT_NODE, chn);
        ctu_wait_ff(ff_control, DUT_NODE, chn);

        -- IDE, r0, 3 bits of DLC
        for i in 1 to 5 loop
            ctu_wait_sample_point(DUT_NODE, chn);
        end loop;

        ctu_wait_sync_seg(DUT_NODE, chn);
        flip_bus_level(chn);
        ctu_wait_sample_point(DUT_NODE, chn, false);
        wait for 20 ns;
        release_bus_level(chn);

        wait for 100 ns;

        -------------------------------------------------------------------------------------------
        -- @4. Wait until error frame in DUT Node, release bus value. Check DUTs RX
        --      Buffer contains a two RX frames. Wait until bus is idle.
        -------------------------------------------------------------------------------------------
        info_m("Step 4");

        ctu_wait_err_frame(DUT_NODE, chn);

        ctu_get_rx_buf_state(rx_buf_state, DUT_NODE, chn);
        check_m(rx_buf_state.rx_frame_count = 2, "Two frames in RX Buffer!");

        ctu_wait_bus_idle(DUT_NODE, chn);

        -------------------------------------------------------------------------------------------
        -- @5. Generate CAN frame and send it byt Test Node. Wait until frame is sent.
        -------------------------------------------------------------------------------------------
        info_m("Step 5");

        generate_can_frame(tx_frame_3);
        ctu_send_frame(tx_frame_3, 1, TEST_NODE, chn, frame_sent);
        ctu_wait_frame_sent(DUT_NODE, chn);

        -------------------------------------------------------------------------------------------
        -- @6. Read all 3 frames from DUTs RX Buffer, and check that first and third
        --     frames are CAN frames matching first and third transmitted frame. Check
        --     that second frame is an Error frame.
        -------------------------------------------------------------------------------------------
        info_m("Step 6");

        ctu_read_frame(rx_frame_1, DUT_NODE, chn);
        ctu_read_frame(rx_frame_2, DUT_NODE, chn);
        ctu_read_frame(rx_frame_3, DUT_NODE, chn);

        compare_can_frames(rx_frame_1, tx_frame_1, false, frames_match);
        check_m(frames_match, "RX Frame 1 = TX Frame 1");
        check_m(rx_frame_1.erf = '0', "RX Frame 1 is CAN frame");

        check_m(rx_frame_2.erf = '1', "RX Frame 2 is Error frame");

        compare_can_frames(rx_frame_3, tx_frame_3, false, frames_match);
        check_m(frames_match, "RX Frame 3 = TX Frame 3");
        check_m(rx_frame_1.erf = '0', "RX Frame 3 is CAN frame");

    end procedure;

end package body;
