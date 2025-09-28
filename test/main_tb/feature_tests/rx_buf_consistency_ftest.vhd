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
--  RX Buffer consistency feature test implementation.
--
-- @Verifies:
--  @1. RX Buffer Frame count is consistent when frame is commited at at the
--      same time as read of previous frame is finished.
--
-- @Test sequence:
--   @1. Disable DUT, configure fast Nominal and Data bit-rate (to reduce test
--       length).
--   @2. Iterate with incrementing wait time X.
--       @2.1 Generate two random CAN frames. Send both frames by Test Node.
--       @2.2 Wait until first frame is sent by DUT. Check RX Frame count is
--            1 in DUT.
--       @2.3 Wait until start of End of Frame field in DUT Node.
--            Then wait for X clock cycles.
--       @2.4 Read out frame from DUT Node. Due to incrementing time X, the
--            test will hit the scenario where frame reading is simultaneously
--            finished, and second received frame is commited!
--       @2.5 Wait until second frame reception is finished in DUT.
--       @2.6 Check RX Frame count is 1 in DUT.
--       @2.7 Read second frame from DUT. Check RX Frame count in DUT is 0.
--            Check both transmitted frames match both received frames.
--
-- @TestInfoEnd
--------------------------------------------------------------------------------
-- Revision History:
--
--    17.7.2024  Created file
--------------------------------------------------------------------------------

Library ctu_can_fd_tb;
context ctu_can_fd_tb.ieee_context;
context ctu_can_fd_tb.rtl_context;
context ctu_can_fd_tb.tb_common_context;

use ctu_can_fd_tb.feature_test_agent_pkg.all;
use ctu_can_fd_tb.clk_gen_agent_pkg.all;

package rx_buf_consistency_ftest is
    procedure rx_buf_consistency_ftest_exec(
        signal      chn             : inout  t_com_channel
    );
end package;


package body rx_buf_consistency_ftest is
    procedure rx_buf_consistency_ftest_exec(
        signal      chn             : inout  t_com_channel
    ) is
        variable bus_timing         : t_ctu_bit_time_cfg;

        variable CAN_TX_frame_1     :       t_ctu_frame;
        variable CAN_TX_frame_2     :       t_ctu_frame;
        variable CAN_RX_frame_1     :       t_ctu_frame;
        variable CAN_RX_frame_2     :       t_ctu_frame;

        variable rx_buf_info        :       t_ctu_rx_buff_info;

        variable frames_match       :       boolean;
        variable frame_sent         :       boolean;
    begin

        ------------------------------------------------------------------------
        -- @1. Disable DUT, configure fast Nominal and Data bit-rate (to reduce
        --     test length).
        ------------------------------------------------------------------------
        info_m("Step 1");

        bus_timing.tq_nbt     := 1;
        bus_timing.tq_dbt     := 1;
        bus_timing.prop_nbt   := 5;
        bus_timing.ph1_nbt    := 2;
        bus_timing.ph2_nbt    := 4;
        bus_timing.sjw_nbt    := 1;
        bus_timing.prop_dbt   := 3;
        bus_timing.ph1_dbt    := 1;
        bus_timing.ph2_dbt    := 3;
        bus_timing.sjw_dbt    := 1;

        ctu_turn(false, DUT_NODE, chn);
        ctu_turn(false, TEST_NODE, chn);

        ctu_set_bit_time_cfg(bus_timing, DUT_NODE, chn);
        ctu_set_bit_time_cfg(bus_timing, TEST_NODE, chn);

        ctu_set_ssp(ssp_no_ssp, x"00", DUT_NODE, chn);
        ctu_set_ssp(ssp_no_ssp, x"00", TEST_NODE, chn);

        ctu_turn(true, DUT_NODE, chn);
        ctu_turn(true, TEST_NODE, chn);

        ctu_wait_err_active(DUT_NODE, chn);
        ctu_wait_err_active(TEST_NODE, chn);

        -- First frame must be always equal so that duration to read it is
        -- always the same, and thus delaying the frame readout cycle by cycle
        -- will guarantee to hit the moment when frame is simultaneously
        -- commited and last word is read!
        generate_can_frame(CAN_TX_frame_1);

        -- Restrict to non-CAN FD frames from two reasons:
        --  - Shorter data fields -> Reduces test length
        --  - Avoids ambiguity in length of ACK field.
        CAN_TX_frame_1.frame_format := NORMAL_CAN;
        if (CAN_TX_frame_1.data_length > 8) then
            CAN_TX_frame_1.data_length := 8;
        end if;
        length_to_dlc(CAN_TX_frame_1.data_length, CAN_TX_frame_1.dlc);
        dlc_to_rwcnt(CAN_TX_frame_1.dlc, CAN_TX_frame_1.rwcnt);

        ------------------------------------------------------------------------
        -- @2. Iterate with incrementing wait time X.
        ------------------------------------------------------------------------
        info_m("Step 2");

        for wait_multiple in 1 to 200 loop

            --------------------------------------------------------------------
            -- @2.1 Generate two random CAN frames.
            --      Send both frames by Test Node.
            --------------------------------------------------------------------
            info_m("Step 2.1");

            generate_can_frame(CAN_TX_frame_2);

            ctu_send_frame(CAN_TX_frame_1, 1, TEST_NODE, chn, frame_sent);
            wait for 200 ns;
            ctu_send_frame(CAN_TX_frame_2, 2, TEST_NODE, chn, frame_sent);

            --------------------------------------------------------------------
            -- @2.2 Wait until first frame is sent by DUT. Check RX Frame count
            --      is 1 in DUT.
            --------------------------------------------------------------------
            info_m("Step 2.2");

            ctu_wait_frame_sent(DUT_NODE, chn);
            ctu_get_rx_buf_state(rx_buf_info, DUT_NODE, chn);
            check_m(rx_buf_info.rx_frame_count = 1, "RX Buffer frame count is 1");

            --------------------------------------------------------------------
            -- @2.3 Wait until start of End of Frame field in DUT Node. Then
            --      wait for 5 more bits. Then wait for X clock cycles.
            --------------------------------------------------------------------
            info_m("Step 2.3");

            ctu_wait_frame_field(pc_deb_eof, DUT_NODE, chn);

            for i in 1 to wait_multiple loop
                info_m("Waiting for " & integer'image(i) & " clock cycles");
                clk_agent_wait_cycle(chn);
            end loop;

            --------------------------------------------------------------------
            -- @2.4 Read out frame from DUT Node. Due to incrementing time X,
            --      the test will hit the scenario where frame reading is
            --      simultaneously finished, and second received frame is
            --      commited!
            --------------------------------------------------------------------
            info_m("Step 2.4");

            ctu_read_frame(CAN_RX_frame_1, DUT_NODE, chn);

            --------------------------------------------------------------------
            -- @2.5 Wait until second frame reception is finished in DUT.
            --------------------------------------------------------------------
            info_m("Step 2.5");

            ctu_wait_bus_idle(DUT_NODE, chn);
            ctu_wait_bus_idle(TEST_NODE, chn);

            --------------------------------------------------------------------
            -- @2.6 Check RX Frame count is 1 in DUT.
            --------------------------------------------------------------------
            info_m("Step 2.6");

            ctu_get_rx_buf_state(rx_buf_info, DUT_NODE, chn);
            check_m(rx_buf_info.rx_frame_count = 1, "RX Buffer frame count is 1");

            --------------------------------------------------------------------
            -- @2.7 Read second frame from DUT. Check RX Frame count in DUT is 0.
            --      Check both transmitted frames match both received frames.
            --------------------------------------------------------------------
            info_m("Step 2.7");

            ctu_read_frame(CAN_RX_frame_2, DUT_NODE, chn);

            ctu_get_rx_buf_state(rx_buf_info, DUT_NODE, chn);
            check_m(rx_buf_info.rx_frame_count = 0, "RX Buffer frame count is 0");

            compare_can_frames(CAN_RX_frame_1, CAN_TX_frame_1, false, frames_match);
            check_m(frames_match, "Frame 1 match");

            compare_can_frames(CAN_RX_frame_2, CAN_TX_frame_2, false, frames_match);
            check_m(frames_match, "Frame 2 match");

        end loop;

    end procedure;

end package body;