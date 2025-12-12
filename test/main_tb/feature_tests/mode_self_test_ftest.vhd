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
--  Self test mode - feature test.
--
-- @Verifies:
--  @1. In Self test mode, transmitted frame is valid even if ACK was recessive!
--
-- @Test sequence:
--  @1. Configures Self Test mode in DUT. Configure ACK forbidden in Test node.
--  @2. Send frame by DUT. Wait till ACK field.
--  @3. Monitor during whole ACK field that frame bus is RECESSIVE.
--  @4. Check that after ACK field, DUT is NOT transmitting Error frame!
--      Wait till bus is idle and check that TXT Buffer in DUT is in TX OK!
--      Check that frame was received by Test node.
--
-- @TestInfoEnd
--------------------------------------------------------------------------------
-- Revision History:
--    22.9.2019   Created file
--------------------------------------------------------------------------------

Library ctu_can_fd_tb;
context ctu_can_fd_tb.ieee_context;
context ctu_can_fd_tb.rtl_context;
context ctu_can_fd_tb.tb_common_context;

use ctu_can_fd_tb.feature_test_agent_pkg.all;

package mode_self_test_ftest is
    procedure mode_self_test_ftest_exec(
        signal      chn             : inout  t_com_channel
    );
end package;


package body mode_self_test_ftest is
    procedure mode_self_test_ftest_exec(
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
    begin

        ------------------------------------------------------------------------
        -- @1. Configures Self Test mode in DUT. Configure ACK forbidden in
        --     Test node.
        ------------------------------------------------------------------------
        info_m("Step 1: Configuring STM in DUT, ACF in Test node!");
        
        mode_1.self_test := true;
        ctu_set_mode(mode_1, DUT_NODE, chn);
        
        mode_2.acknowledge_forbidden := true;
        ctu_set_mode(mode_2, TEST_NODE, chn);

        ------------------------------------------------------------------------
        -- @2. Send frame by DUT. Wait till ACK field.
        ------------------------------------------------------------------------
        info_m("Step 2: Send frame by DUT, Wait till ACK");
        
        generate_can_frame(can_tx_frame);
        ctu_send_frame(can_tx_frame, 1, DUT_NODE, chn, frame_sent);
        ctu_wait_ff(ff_ack, DUT_NODE, chn);
        
        ------------------------------------------------------------------------
        -- @3. Monitor during whole ACK field that frame bus is RECESSIVE.
        ------------------------------------------------------------------------
        info_m("Step 3: Checking ACK field is recessive"); 
        
        ctu_get_curr_ff(ff, DUT_NODE, chn);
        while (ff = ff_ack) loop
            check_bus_level(RECESSIVE, "Dominant ACK transmitted!", chn);
            ctu_get_curr_ff(ff, DUT_NODE, chn);
            
            ctu_get_status(status, DUT_NODE, chn);
            check_m(status.transmitter, "DUT receiver!");
            
            wait for 100 ns; -- To make checks more sparse
        end loop;
        
        ------------------------------------------------------------------------
        -- @4. Check that after ACK field, DUT is NOT transmitting Error 
        --     frame! Wait till bus is idle and check that TXT Buffer in DUT
        --     is in TX OK! Check that frame was received by Test node.
        ------------------------------------------------------------------------
        info_m("Step 4: Check Error frame is not transmitted!"); 
        
        ctu_get_status(status, DUT_NODE, chn);
        check_false_m(status.error_transmission, "Error frame not transmitted!");
        
        ctu_get_curr_ff(ff, DUT_NODE, chn);
        
        -- For CAN FD frames secondary ACK is still marked as ACK to DEBUG
        -- register! From there if this is recessive (it is now, no ACK is sent),
        -- it is interpreted as ACK Delimiter and we move directly to EOF! This
        -- is OK!
        check_m(ff = ff_ack_delim or
                ff = ff_eof, "ACK delimiter follows recessive ACK!");
        
        ctu_wait_bus_idle(TEST_NODE, chn);
        ctu_wait_bus_idle(DUT_NODE, chn);
        
        ctu_get_txt_buf_state(1, txt_buf_state, DUT_NODE, chn);
        check_m(txt_buf_state = buf_done, "Frame transmitted OK");
        
        ctu_get_rx_buf_state(rx_buf_state, TEST_NODE, chn);
        check_m(rx_buf_state.rx_frame_count = 1, "Frame received in LOM");
        
        ctu_read_frame(can_rx_frame, TEST_NODE, chn);
        compare_can_frames(can_rx_frame, can_tx_frame, false, frames_equal);
        
  end procedure;

end package body;