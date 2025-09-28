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
--  Restricted operation mode - feature test.
--
-- @Verifies:
--  @1. When error is detected in ROM mode, Integration is entered and REC, or
--      TEC are not modified!
--  @2. TXT Buffer after issuing Set Ready command in ROM mode, will end up
--      in TX Failed and no frame will be transmitted!
--  @3. When Overload condition is detected by CTU CAN FD in ROM mode
--      (last bit of EOF, first two bits of Intermission), it enters bus
--      integration state.
--  @4. Node is able to receive next frame right after detecting Error in
--      restricted operation mode.
--  @5. Node in restricted operation mode sends ACK bit dominant!
--
--
-- @Test sequence:
--  @1. Configure ROM mode in DUT. Insert frame to TXT buffer and issue
--      Set ready command. Verify that TXT buffer ends up in TX failed.
--      Check that unit is not transmitter. Repeat several times in a row.
--  @2. Send frame by Test node with stuff bit. Force this stuff bit to opposite
--      value on CAN RX of DUT. Check that DUT goes to integrating. Check
--      that REC/TEC of DUT are not changed.
--  @3. Test node will retransmitt frame from previous step. Wait until ACK field
--      in DUT. Check that DUT is transmitting dominant bit.
--  @4. Wait until EOF field of DUT. Wait randomly for 7,8,9 bits to offset
--      to last bit of EOF or first/second bit of Intermission. Force CAN bus
--      to dominant. Check that DUT will end in integration state (and
--      not in overload state).
--
-- @TestInfoEnd
--------------------------------------------------------------------------------
-- Revision History:
--    10.11.2020   Created file
--------------------------------------------------------------------------------

Library ctu_can_fd_tb;
context ctu_can_fd_tb.ieee_context;
context ctu_can_fd_tb.rtl_context;
context ctu_can_fd_tb.tb_common_context;

use ctu_can_fd_tb.feature_test_agent_pkg.all;

package mode_restr_op_ftest is
    procedure mode_restr_op_ftest_exec(
        signal      chn             : inout  t_com_channel
    );
end package;


package body mode_restr_op_ftest is
    procedure mode_restr_op_ftest_exec(
        signal      chn             : inout  t_com_channel
    ) is
        variable CAN_TX_frame       :       t_ctu_frame;
        variable CAN_RX_frame       :       t_ctu_frame;
        variable frame_sent         :       boolean := false;
        variable mode_1             :       t_ctu_mode := t_ctu_mode_rst_val;
        
        variable err_counters       :       t_ctu_err_ctrs := (0, 0, 0, 0);
        variable err_counters_2     :       t_ctu_err_ctrs := (0, 0, 0, 0);

        variable fault_th           :       t_ctu_fault_thresholds;
        variable fault_th_2         :       t_ctu_fault_thresholds;
        
        variable txt_buf_state      :       t_ctu_txt_buff_state;
        variable status             :       t_ctu_status;
        variable bit_waits          :       natural;
    begin

        ------------------------------------------------------------------------
        --  @1. Configure ROM mode in DUT. Insert frame to TXT buffer and
        --      issue Set ready command. Verify that TXT buffer ends up in TX
        --      failed. Check that unit is not transmitter. Repeat several times
        --      in a row.
        ------------------------------------------------------------------------
        info_m("Step 1: Configure ROM mode in DUT. Try to send frame in ROM!");
        
        mode_1.restricted_operation := true;
        ctu_set_mode(mode_1, DUT_NODE, chn);
        
        generate_can_frame(CAN_TX_frame);
        -- To make sure we have only one ACK bit
        CAN_TX_frame.frame_format := NORMAL_CAN;
        ctu_send_frame(CAN_TX_frame, 1, DUT_NODE, chn, frame_sent);
        wait for 20 ns;
        
        for i in 0 to 20 loop
            ctu_get_status(status, DUT_NODE, chn);
            check_false_m(status.transmitter, "Node does not transmitt in ROM!");
            check_false_m(status.receiver, "Node turned receiver in ROM -> WTF?");
            check_m(status.bus_status, "Node remains idle");
            
            ctu_get_txt_buf_state(1, txt_buf_state, DUT_NODE, chn);
            check_m(txt_buf_state = buf_failed, "TXT buffer went to failed in ROM!");
            
            wait for 100 ns;
        end loop;

        -----------------------------------------------------------------------
        -- @2. Send frame by Test node with stuff bit. Force this stuff bit to
        --     opposite value on CAN RX of DUT. Check that DUT goes to
        --     integrating. Check that REC/TEC of DUT are not changed.
        --
        --     Note: By default for feature tests, device is in One shot mode,
        --           so two frames are issued to invoke transmission back-to
        --           back by Test node.
        -----------------------------------------------------------------------
        info_m("Step 2: Send frame by Test node!");
        
        CAN_TX_frame.identifier := 0;
        CAN_TX_frame.ident_type := BASE;
        ctu_send_frame(CAN_TX_frame, 1, TEST_NODE, chn, frame_sent);
        ctu_send_frame(CAN_TX_frame, 2, TEST_NODE, chn, frame_sent);
        
        -- Following wait ends just after sample point of SOF!
        ctu_wait_frame_start(false, true, DUT_NODE, chn);
        
        -- 5th bit of Base ID should be recessive stuff bit.
        for i in 0 to 3 loop
            ctu_wait_sample_point(DUT_NODE, chn);
        end loop;
        
        force_bus_level(DOMINANT, chn);
        ctu_wait_sample_point(DUT_NODE, chn);
        wait for 20 ns;

        ctu_wait_sample_point(DUT_NODE, chn);      
        wait for 10 ns;
        release_bus_level(chn);

        ctu_get_status(status, DUT_NODE, chn);
        check_m(status.bus_status, "Node became idle after Error in ROM mod!");
        
        ctu_get_err_ctrs(err_counters, DUT_NODE, chn);
        check_m(err_counters.rx_counter = 0, "REC not incremented in ROM!");
        check_m(err_counters.tx_counter = 0, "TEC not incremented in ROM!");

        -----------------------------------------------------------------------
        -- @3. Test node will retransmitt frame from previous step. Wait until
        --     ACK field in DUT. Check that DUT is transmitting dominant
        --     bit.
        -----------------------------------------------------------------------
        info_m("Step 3: Wait till ACK of retrasnmitted frame.");
        
        ctu_wait_frame_field(pc_deb_ack, DUT_NODE, chn);
        
        ctu_wait_sync_seg(DUT_NODE, chn);
        wait for 10 ns;
        check_can_tx(DOMINANT, DUT_NODE, "Send Dominant ACK after Error in ROM!", chn);
        
        ctu_wait_sample_point(DUT_NODE, chn);

        -----------------------------------------------------------------------
        -- @4. Wait until EOF field of DUT. Wait randomly for 7,8,9 bits to
        --     offset to last bit of EOF or first/second bit of Intermission.
        --     Force CAN bus to dominant. Check that DUT will end in
        --     integration state (and not in overload state).
        -----------------------------------------------------------------------
        info_m("Step 4: Overload condition reaction by CTU CAN FD!");
        
        -- 0 - 2
        rand_int_v(2, bit_waits);
        bit_waits := bit_waits + 7;
        
        -- This should offset to last bit of EOF, first or second bit of interm.
        for i in 0 to bit_waits - 1 loop
            ctu_wait_sample_point(DUT_NODE, chn);
        end loop;
        
        ctu_wait_sync_seg(DUT_NODE, chn);
        
        force_bus_level(DOMINANT, chn);
        ctu_wait_sample_point(DUT_NODE, chn);
        wait for 40 ns;
        release_bus_level(chn);
        
        ctu_get_status(status, DUT_NODE, chn);
        check_m(status.bus_status, "Node became idle after Error in ROM mod!");
        
        ctu_get_err_ctrs(err_counters, DUT_NODE, chn);
        check_m(err_counters.rx_counter = 0, "REC not incremented in ROM!");
        check_m(err_counters.tx_counter = 0, "TEC not incremented in ROM!");

  end procedure;

end package body;