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
--  RX Buffer consistency 3 feature test implementation.
--
-- @Verifies:
--  @1. RX Buffer Write pointer corner-case when a word is simultaneously read
--      from and written to RX Buffer.
--
-- @Test sequence:
--   @1. Read Bit timing configuration of the DUT.
--   @2. Iterate with incrementing wait time X.
--       @2.1 Generate two random CAN frames. Send both frames by Test Node.
--       @2.2 Wait until first frame is sent by DUT.
--       @2.3 Wait until the start of last bit of DLC in the DUT. Wait for
--            incrementing time X.
--       @2.4 Read out frame from DUT Node. Due to incrementing time X, the
--            test will hit the scenario where frame is simultaneously being
--            read, and metadata from second frame is stored to the RX Buffer.
--       @2.5 Wait until the second frame is over. Read second frame from DUT.
--            Check that both frames were received correctly!
--
-- @TestInfoEnd
--------------------------------------------------------------------------------
-- Revision History:
--    19.12.2025  Created file
--------------------------------------------------------------------------------

Library ctu_can_fd_tb;
context ctu_can_fd_tb.ieee_context;
context ctu_can_fd_tb.rtl_context;
context ctu_can_fd_tb.tb_common_context;

use ctu_can_fd_tb.feature_test_agent_pkg.all;
use ctu_can_fd_tb.clk_gen_agent_pkg.all;

package rx_buf_consistency_3_ftest is
    procedure rx_buf_consistency_3_ftest_exec(
        signal      chn             : inout  t_com_channel
    );
end package;


package body rx_buf_consistency_3_ftest is
    procedure rx_buf_consistency_3_ftest_exec(
        signal      chn             : inout  t_com_channel
    ) is
        variable bus_timing         :       t_ctu_bit_time_cfg;

        variable can_tx_frame_1     :       t_ctu_frame;
        variable can_tx_frame_2     :       t_ctu_frame;
        variable can_rx_frame_1     :       t_ctu_frame;
        variable can_rx_frame_2     :       t_ctu_frame;

        variable rx_buf_state        :       t_ctu_rx_buf_state;

        variable frames_match       :       boolean;
        variable frame_sent         :       boolean;

        variable err_counters       :       t_ctu_err_ctrs;

        variable wait_threshold     :       natural;

        variable mode               :       t_ctu_mode := t_ctu_mode_rst_val;
    begin

        ------------------------------------------------------------------------
        -- @1. Read Bit timing configuration of the DUT.
        ------------------------------------------------------------------------
        info_m("Step 1");

        ctu_get_bit_time_cfg_v(bus_timing, DUT_NODE, chn);

        ------------------------------------------------------------------------
        -- @2. Iterate with incrementing wait time X.
        ------------------------------------------------------------------------
        info_m("Step 2");

        wait_threshold := bus_timing.tq_nbt *
                            (bus_timing.ph1_nbt + bus_timing.ph2_nbt + bus_timing.prop_nbt + 1);

        for wait_multiple in 1 to wait_threshold loop

            --------------------------------------------------------------------
            -- @2.1 Generate two random CAN frames. Send both frames by Test Node.
            --------------------------------------------------------------------
            info_m("Step 2.1");

            generate_can_frame(can_tx_frame_1);
            can_tx_frame_1.data_length := can_tx_frame_1.data_length mod 8;
            length_to_dlc(can_tx_frame_1.data_length, can_tx_frame_1.dlc);
            dlc_to_rwcnt(can_tx_frame_1.dlc, can_tx_frame_1.rwcnt);

            generate_can_frame(can_tx_frame_2);
            can_tx_frame_2.data_length := can_tx_frame_2.data_length mod 8;
            length_to_dlc(can_tx_frame_2.data_length, can_tx_frame_2.dlc);
            dlc_to_rwcnt(can_tx_frame_2.dlc, can_tx_frame_2.rwcnt);

            can_tx_frame_2.frame_format := NORMAL_CAN;
            can_tx_frame_2.ident_type := EXTENDED;
            can_tx_frame_2.rtr := NO_RTR_FRAME;

            ctu_put_tx_frame(can_tx_frame_1, 1, TEST_NODE, chn);
            ctu_put_tx_frame(can_tx_frame_2, 2, TEST_NODE, chn);

            ctu_give_txt_cmd(buf_set_ready, 1, TEST_NODE, chn);
            ctu_wait_sample_point(TEST_NODE, chn);
            ctu_wait_sample_point(TEST_NODE, chn);
            ctu_give_txt_cmd(buf_set_ready, 2, TEST_NODE, chn);

            --------------------------------------------------------------------
            -- @2.2 Wait until first frame is sent by DUT.
            --------------------------------------------------------------------
            info_m("Step 2.2");

            ctu_wait_frame_sent(DUT_NODE, chn);

            --------------------------------------------------------------------
            -- @2.3 Wait until the start of last bit of DLC in the DUT.
            --      Wait for incrementing time X.
            --------------------------------------------------------------------
            info_m("Step 2.3");

            ctu_wait_ff(ff_control, DUT_NODE, chn);

            -- This should wait till Sync Segment of last bit of DLC!
            for i in 1 to 5 loop
                ctu_wait_sample_point(DUT_NODE, chn);
            end loop;
            ctu_wait_sync_seg(DUT_NODE, chn);

            for i in 1 to wait_multiple loop
                info_m("Waiting for " & integer'image(i) & " clock cycles");
                clk_agent_wait_cycle(chn);
            end loop;

            --------------------------------------------------------------------
            -- @2.4 Read out frame from DUT Node. Due to incrementing time X,
            --      the test will hit the scenario where frame is simultaneously
            --      being read, and metadata from second frame is stored to the
            --      RX Buffer.
            --------------------------------------------------------------------
            info_m("Step 2.4");

            ctu_read_frame(can_rx_frame_1, DUT_NODE, chn);

            --------------------------------------------------------------------
            -- @2.5 Wait until the second frame is over.
            --      Read second frame from DUT.
            --      Check that both frames were received correctly!
            --------------------------------------------------------------------
            info_m("Step 2.5");

            ctu_wait_bus_idle(DUT_NODE, chn);
            ctu_wait_bus_idle(TEST_NODE, chn);

            ctu_read_frame(can_rx_frame_2, DUT_NODE, chn);

            compare_can_frames(can_tx_frame_1, can_rx_frame_1, false, frames_match);
            check_m(frames_match, "TX Frame 1 = RX Frame 1");

            compare_can_frames(can_tx_frame_2, can_rx_frame_2, false, frames_match);
            check_m(frames_match, "TX Frame 2 = RX Frame 2");

        end loop;

    end procedure;

end package body;