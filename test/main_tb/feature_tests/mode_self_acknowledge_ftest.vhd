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
--  Self acknowledge mode test
--
-- @Verifies:
--  @1. When MODE[SAM] = 1 and CTU CAN FD transmits a frame, then it will
--      send dominant ACK bit.
--
-- @Test sequence:
--  @1. Configure Self acknowledge mode in DUT Node.
--  @2. Send frame by DUT. Wait till ACK field in DUT Node.
--  @3. Check that DUT Node is transmitting Dominant value. Wait until bus
--      is idle.
--
-- @TestInfoEnd
--------------------------------------------------------------------------------
-- Revision History:
--    8.9.2024   Created file
--------------------------------------------------------------------------------

Library ctu_can_fd_tb;
context ctu_can_fd_tb.ieee_context;
context ctu_can_fd_tb.rtl_context;
context ctu_can_fd_tb.tb_common_context;

use ctu_can_fd_tb.feature_test_agent_pkg.all;

package mode_self_acknowledge_ftest is
    procedure mode_self_acknowledge_ftest_exec(
        signal      chn             : inout  t_com_channel
    );
end package;


package body mode_self_acknowledge_ftest is
    procedure mode_self_acknowledge_ftest_exec(
        signal      chn             : inout  t_com_channel
    ) is
        variable can_tx_frame       :       t_ctu_frame;
        variable can_rx_frame       :       t_ctu_frame;
        variable frame_sent         :       boolean := false;
        variable mode_1             :       t_ctu_mode := t_ctu_mode_rst_val;
        variable mode_2             :       t_ctu_mode := t_ctu_mode_rst_val;

        variable txt_buf_state      :       t_ctu_txt_buff_state;
        variable rx_buf_state       :       t_ctu_rx_buf_state;
        variable status             :       t_ctu_status;
        variable frames_equal       :       boolean := false;
        variable ff             :       t_ctu_frame_field;

        variable can_tx             :       std_logic;
    begin

        ------------------------------------------------------------------------
        -- @1. Configures Self Acknowledge mode in DUT.
        ------------------------------------------------------------------------
        info_m("Step 1");

        mode_1.self_acknowledge := true;
        ctu_set_mode(mode_1, DUT_NODE, chn);

        ------------------------------------------------------------------------
        -- @2. Send frame by DUT. Wait till ACK field in DUT Node.
        ------------------------------------------------------------------------
        info_m("Step 2");

        generate_can_frame(can_tx_frame);
        ctu_send_frame(can_tx_frame, 1, DUT_NODE, chn, frame_sent);
        ctu_wait_ff(ff_ack, DUT_NODE, chn);
        ctu_wait_sync_seg(DUT_NODE, chn);
        wait for 20 ns;

        ------------------------------------------------------------------------
        -- @3. Check that DUT Node is transmitting Dominant value.
        --     Wait until bus is idle.
        ------------------------------------------------------------------------
        info_m("Step 3");

        get_can_tx(DUT_NODE, can_tx, chn);
        check_m(can_tx = DOMINANT, "DUT transmits dominant ACK when MODE[SAM]=1");
        ctu_wait_bus_idle(DUT_NODE, chn);

  end procedure;

end package body;