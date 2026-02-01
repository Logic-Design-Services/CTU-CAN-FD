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
--  TX Status feature test.
--
-- @Verifies:
--  @1. TXT Buffer is Empty after reset
--  @2. TXT Buffer is OK after successfull transmission.
--  @2. TXT Buffer is Failed after transmission fails from this buffer!
--  @3. TXT Buffer is Aborted after Set Abort command was issued during
--      transmission.
--
-- @Test sequence:
--  @1. Reset Node, Enable it, and wait until it integrates. Pick random TXT
--      Buffer which will be used during this test. Check that TXT Buffer is
--      empty.
--  @2. Transmitt CAN Frame by DUT and wait until it is received in Test node.
--      Check that TXT Buffer is OK.
--  @3. Set ACK Forbidden mode in Test node. Set One shot mode in DUT. Send frame
--      by DUT and wait until it is sent. Check that TXT Buffer is in TX
--      Failed.
--  @4. Send CAN frame and when it starts, issue Set Abort Command. Wait until
--      frame is sent and check that TXT Buffer is in Aborted.
--
-- Note:
--  Ready, TX in Progress and Abort in Progress are not tested here as they are
--  checked in tx_cmd_set_ready/empty/abort test case.
--
-- @TestInfoEnd
--------------------------------------------------------------------------------
-- Revision History:
--     22.11.2019   Created file
--------------------------------------------------------------------------------

Library ctu_can_fd_tb;
context ctu_can_fd_tb.ieee_context;
context ctu_can_fd_tb.rtl_context;
context ctu_can_fd_tb.tb_common_context;

use ctu_can_fd_tb.feature_test_agent_pkg.all;

package tx_status_ftest is
    procedure tx_status_ftest_exec(
        signal      chn             : inout  t_com_channel
    );
end package;

package body tx_status_ftest is

    procedure tx_status_ftest_exec(
        signal      chn             : inout  t_com_channel
    ) is
        variable can_frame_tx       :       t_ctu_frame;
        variable mode_2             :       t_ctu_mode := t_ctu_mode_rst_val;
        variable frame_sent         :       boolean := false;
        variable bus_timing         :       t_ctu_bit_time_cfg;
        variable txt_state          :       t_ctu_txt_buff_state;
        variable num_buffers        :       natural;
    begin

        ctu_get_txt_buf_cnt(num_buffers, DUT_NODE, chn);

        for txt_buf_num in 1 to num_buffers loop

            -----------------------------------------------------------------------
            -- @1. Reset Node, Enable it, and wait until it integrates. Pick random
            --     TXT Buffer which will be used during this test. Check that TXT
            --     Buffer is empty.
            -----------------------------------------------------------------------
            info_m("Step 1");

            ctu_get_bit_time_cfg_v(bus_timing, DUT_NODE, chn);
            ctu_soft_reset(DUT_NODE, chn);
            ctu_soft_reset(TEST_NODE, chn);
            ctu_set_bit_time_cfg(bus_timing, DUT_NODE, chn);
            ctu_set_bit_time_cfg(bus_timing, TEST_NODE, chn);

            ctu_turn(true, DUT_NODE, chn);
            ctu_turn(true, TEST_NODE, chn);

            -- Wait till integration is over!
            ctu_wait_err_active(DUT_NODE, chn);
            ctu_wait_err_active(TEST_NODE, chn);

            ctu_get_txt_buf_state(txt_buf_num, txt_state, DUT_NODE, chn);
            check_m(txt_state = buf_empty, "TX Empty after reset!");

            -----------------------------------------------------------------------
            -- @2. Transmit CAN Frame by DUT and wait until it is received in
            --     Test node. Check that TXT Buffer is OK.
            -----------------------------------------------------------------------
            info_m("Step 2");

            generate_can_frame(can_frame_tx);
            can_frame_tx.brs := BR_NO_SHIFT;
            ctu_send_frame(can_frame_tx, txt_buf_num, DUT_NODE, chn, frame_sent);

            ctu_wait_frame_sent(DUT_NODE, chn);
            ctu_wait_bus_idle(TEST_NODE, chn);

            ctu_get_txt_buf_state(txt_buf_num, txt_state, DUT_NODE, chn);
            check_m(txt_state = buf_done, "TX OK after frame sent!");

            -----------------------------------------------------------------------
            -- @3. Set ACK Forbidden mode in Test node. Set One shot mode in DUT.
            --     Send frame by DUT and wait until it is sent. Check that TXT
            --     Buffer is in TX Failed.
            -----------------------------------------------------------------------
            info_m("Step 3");

            mode_2.acknowledge_forbidden := true;
            ctu_set_mode(mode_2, TEST_NODE, chn);

            ctu_set_retr_limit(true, 0, DUT_NODE, chn);

            generate_can_frame(can_frame_tx);
            can_frame_tx.brs := BR_NO_SHIFT;

            ctu_send_frame(can_frame_tx, txt_buf_num, DUT_NODE, chn, frame_sent);
            ctu_wait_frame_start(true, false, DUT_NODE, chn);
            ctu_wait_bus_idle(DUT_NODE, chn);
            ctu_wait_bus_idle(TEST_NODE, chn);

            ctu_get_txt_buf_state(txt_buf_num, txt_state, DUT_NODE, chn);
            check_m(txt_state = buf_failed, "TX Failed after error!");

            -----------------------------------------------------------------------
            -- @4. Send CAN frame and when it starts, issue Set Abort Command. Wait
            --     until frame is sent and check that TXT Buffer is in Aborted.
            -----------------------------------------------------------------------
            info_m("Step 4");

            -- One shot must be disabled now, otherwise this would lead to
            -- TX Failed. We need transmission to be failed, but retransmitt limit
            -- not reached!
            ctu_set_retr_limit(false, 5, DUT_NODE, chn);

            generate_can_frame(can_frame_tx);
            can_frame_tx.brs := BR_NO_SHIFT;
            ctu_send_frame(can_frame_tx, txt_buf_num, DUT_NODE, chn, frame_sent);

            ctu_wait_frame_start(true, false, DUT_NODE, chn);
            ctu_give_txt_cmd(buf_set_abort, txt_buf_num, DUT_NODE, chn);
            ctu_wait_bus_idle(DUT_NODE, chn);
            ctu_wait_bus_idle(TEST_NODE, chn);

            ctu_get_txt_buf_state(txt_buf_num, txt_state, DUT_NODE, chn);
            check_m(txt_state = buf_aborted, "TX Aborted after Set Abort!");

        end loop;

    end procedure;
end package body;
