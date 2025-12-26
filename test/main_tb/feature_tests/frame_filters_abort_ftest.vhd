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
--  Frame filters abort feature test
--
-- @Verifies:
--  @1. Covering scenario when a frame does not pass RX frame filter, but
--      and Error frame occurs (to get code coverage to 100 percent).
--
-- @Test sequence:
--  @1. Set Test Node to One-shot Mode. Enable frame filtering in DUT,
--      configure Mask filter A to receive only a frame with Base ID 0x1.
--  @2. Generate CAN frame with Base ID 0x1, send it by DUT, and wait till frame
--      is sent.
--  @3. Set DUT to Ack-forbidden mode. Generate CAN frame with Base ID 0x2,
--      send it by DUT and wait till bus is idle, the frame should result in
--      Error frame.
--  @4. Disable ACK forbidden mode in DUT. Generate another CAN frame with
--      Base ID 0x1 and send it by a Test Node. Wait till bus is idle.
--  @5. Read two frames from DUT. Compare them with first and third transmitted
--      frame by the Test Node.
--
-- @TestInfoEnd
--------------------------------------------------------------------------------
-- Revision History:
--    26.12.2025   Created file
--------------------------------------------------------------------------------

Library ctu_can_fd_tb;
context ctu_can_fd_tb.ieee_context;
context ctu_can_fd_tb.rtl_context;
context ctu_can_fd_tb.tb_common_context;

use ctu_can_fd_tb.feature_test_agent_pkg.all;

package frame_filters_abort_ftest is
    procedure frame_filters_abort_ftest_exec(
        signal      chn             : inout  t_com_channel
    );
end package;


package body frame_filters_abort_ftest is
    procedure frame_filters_abort_ftest_exec(
        signal      chn             : inout  t_com_channel
    ) is
        variable can_tx_frame_1     :       t_ctu_frame;
        variable can_tx_frame_2     :       t_ctu_frame;
        variable can_tx_frame_3     :       t_ctu_frame;

        variable can_rx_frame_1     :       t_ctu_frame;
        variable can_rx_frame_2     :       t_ctu_frame;

        variable frame_sent         :       boolean := false;
        variable frames_equal       :       boolean := false;

        variable mode_1             :       t_ctu_mode := t_ctu_mode_rst_val;

        variable hw_cfg             :       t_ctu_hw_cfg;
        variable filt_cfg           :       t_ctu_mask_filt_cfg;
        variable rx_buf_state       :       t_ctu_rx_buf_state;

    begin

        -------------------------------------------------------------------------------------------
        -- @1. Set Test Node to One-shot Mode. Enable frame filtering in DUT,
        --     configure Mask filter A to receive only a frame with Base ID 0x1.
        -------------------------------------------------------------------------------------------
        info_m("Step 1");

        ctu_set_retr_limit(true, 0, TEST_NODE, chn);

        ctu_get_hw_config(hw_cfg, DUT_NODE, chn);
        if (hw_cfg.sup_filtA = false) then
            info_m("Skipping test since filter A is not present in HW");
            return;
        end if;

        mode_1.acceptance_filter := true;
        ctu_set_mode(mode_1, DUT_NODE, chn);

        filt_cfg.acc_CAN_2_0 := true;
        filt_cfg.acc_CAN_FD := false;
        filt_cfg.ident_type := BASE;
        filt_cfg.ID_value := 1;
        filt_cfg.ID_mask := 2 ** 11 - 1;
        ctu_set_mask_filter(filter_A, filt_cfg, DUT_NODE, chn);

        -------------------------------------------------------------------------------------------
        -- @2. Generate CAN frame with Base ID 0x1, send it by DUT, and wait till frame
        --     is sent.
        -------------------------------------------------------------------------------------------
        info_m("Step 2");

        generate_can_frame(can_tx_frame_1);
        can_tx_frame_1.data_length := can_tx_frame_1.data_length mod 8;
        length_to_dlc(can_tx_frame_1.data_length, can_tx_frame_1.dlc);
        dlc_to_rwcnt(can_tx_frame_1.dlc, can_tx_frame_1.rwcnt);

        can_tx_frame_1.ident_type := BASE;
        can_tx_frame_1.frame_format := NORMAL_CAN;
        can_tx_frame_1.identifier := 1;

        ctu_send_frame(can_tx_frame_1, 1, TEST_NODE, chn, frame_sent);
        ctu_wait_frame_sent(DUT_NODE, chn);
        ctu_wait_bus_idle(DUT_NODE, chn);

        -------------------------------------------------------------------------------------------
        -- @3. Set DUT to Ack-forbidden mode. Generate CAN frame with Base ID 0x2,
        --     send it by DUT and wait till bus is idle, the frame should result in
        --     Error frame.
        -------------------------------------------------------------------------------------------
        info_m("Step 3");

        mode_1.acknowledge_forbidden := true;
        ctu_set_mode(mode_1, DUT_NODE, chn);

        generate_can_frame(can_tx_frame_2);
        can_tx_frame_2.data_length := can_tx_frame_2.data_length mod 8;
        length_to_dlc(can_tx_frame_2.data_length, can_tx_frame_2.dlc);
        dlc_to_rwcnt(can_tx_frame_2.dlc, can_tx_frame_2.rwcnt);

        can_tx_frame_2.ident_type := BASE;
        can_tx_frame_2.frame_format := NORMAL_CAN;
        can_tx_frame_2.identifier := 2;

        ctu_send_frame(can_tx_frame_2, 1, TEST_NODE, chn, frame_sent);
        ctu_wait_frame_sent(DUT_NODE, chn);
        ctu_wait_bus_idle(DUT_NODE, chn);

        -------------------------------------------------------------------------------------------
        -- @4. Disable ACK forbidden mode in DUT. Generate another CAN frame with
        --     Base ID 0x1 and send it by a Test Node. Wait till bus is idle.
        -------------------------------------------------------------------------------------------
        info_m("Step 4");

        mode_1.acknowledge_forbidden := false;
        ctu_set_mode(mode_1, DUT_NODE, chn);

        generate_can_frame(can_tx_frame_3);

        can_tx_frame_3.data_length := can_tx_frame_3.data_length mod 8;
        length_to_dlc(can_tx_frame_3.data_length, can_tx_frame_3.dlc);
        dlc_to_rwcnt(can_tx_frame_3.dlc, can_tx_frame_3.rwcnt);

        can_tx_frame_3.ident_type := BASE;
        can_tx_frame_3.frame_format := NORMAL_CAN;
        can_tx_frame_3.identifier := 1;

        ctu_send_frame(can_tx_frame_3, 1, TEST_NODE, chn, frame_sent);
        ctu_wait_frame_sent(DUT_NODE, chn);
        ctu_wait_bus_idle(DUT_NODE, chn);

        -------------------------------------------------------------------------------------------
        -- @5. Read two frames from DUT. Compare them with first and third transmitted
        --     frame by the Test Node.
        -------------------------------------------------------------------------------------------
        info_m("Step 5");

        ctu_get_rx_buf_state(rx_buf_state, DUT_NODE, chn);
        check_m(rx_buf_state.rx_frame_count = 2, "Two frames received");

        ctu_read_frame(can_rx_frame_1, DUT_NODE, chn);
        compare_can_frames(can_rx_frame_1, can_tx_frame_1, false, frames_equal);
        check_m(frames_equal, "RX Frame 1 = TX Frame 1");

        ctu_read_frame(can_rx_frame_2, DUT_NODE, chn);
        compare_can_frames(can_rx_frame_2, can_tx_frame_3, false, frames_equal);
        check_m(frames_equal, "RX Frame 2 = TX Frame 3");

  end procedure;

end package body;