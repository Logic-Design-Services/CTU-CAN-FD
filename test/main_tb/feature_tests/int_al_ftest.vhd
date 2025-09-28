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
--  Interrupt DOI feature test.
--
-- @Verifies:
--  @1. AL Interrupt is set when node looses arbitration.
--  @2. AL Interrupt is not set when it is masked.
--  @3. AL Interrupt causes INT to go high when it is enabled.
--  @4. AL Interrupt causes INT to go low when it is disabled.
--  @5. AL Interrupt is cleared by write to INT_STATUS register.
--  @6. AL Interrupt enable is manipulated properly by INT_ENA_SET and
--      INT_ENA_CLEAR.
--  @7. AL Interrupt mask is manipulated properly by INT_MASK_SET and
--      INT_MASK_CLEAR.
--
-- @Test sequence:
--  @1. Unmask and enable AL Interrupt, disable and mask all other interrupts on
--      DUT.
--  @2. Send frame by DUT and Test Node at the same time, make DUTs identifier
--      higher that Test Nodes identifier (to loose arbitration).
--  @3. Wait until the end of arbitration in DUT. Check that AL Interrupt is set.
--      Check that INT pin is high.
--  @4. Disable AL Interrupt and check INT pin goes low. Enable AL Interrupt
--      and check INT pin goes high.
--  @5. Clear AL Interrupt and check it has been cleared and that INT pin is low.
--  @6. Mask AL Interrupt. Send again two frames as in step 2. Wait until
--      arbitration is over in DUT and check that AL interrupt is now not set.
--  @7. Disable AL Interrupt and check it was disabled. Enable AL Interrupt and
--      check it was enabled.
--  @8. Mask AL Interrupt and check it was masked. Un-mask AL Interrupt and
--      check it was un-masked.
--
-- @TestInfoEnd
--------------------------------------------------------------------------------
-- Revision History:
--    1.7.2019   Created file
--------------------------------------------------------------------------------

Library ctu_can_fd_tb;
context ctu_can_fd_tb.ieee_context;
context ctu_can_fd_tb.rtl_context;
context ctu_can_fd_tb.tb_common_context;

use ctu_can_fd_tb.feature_test_agent_pkg.all;
use ctu_can_fd_tb.interrupt_agent_pkg.all;

package int_al_ftest is
    procedure int_al_ftest_exec(
        signal      chn             : inout  t_com_channel
    );
end package;

package body int_al_ftest is
    procedure int_al_ftest_exec(
        signal      chn             : inout  t_com_channel
    ) is
        variable CAN_frame          :     t_ctu_frame;
        variable frame_sent         :     boolean := false;

        variable int_mask           :     t_ctu_interrupts := t_ctu_interrupts_rst_val;
        variable int_ena            :     t_ctu_interrupts := t_ctu_interrupts_rst_val;
        variable int_stat           :     t_ctu_interrupts := t_ctu_interrupts_rst_val;
        variable command            :     t_ctu_command := t_ctu_command_rst_val;
        variable buf_info           :     t_ctu_rx_buf_state;
        variable status             :     t_ctu_status;
    begin

        -----------------------------------------------------------------------
        -- @1. Unmask and enable AL Interrupt, disable and mask all other
        --     interrupts on DUT.
        -----------------------------------------------------------------------
        info_m("Step 1");
        
        int_mask.arb_lost_int := false;
        int_ena.arb_lost_int := true;
        ctu_set_int_mask(int_mask, DUT_NODE, chn);
        ctu_set_int_ena(int_ena, DUT_NODE, chn);

        -----------------------------------------------------------------------
        -- @2. Send frame by DUT and Test Node at the same time, make DUTs
        --     identifier higher that Test Nodes identifier (to loose
        --     arbitration).
        -----------------------------------------------------------------------
        info_m("Step 2");

        generate_can_frame(CAN_frame);
        rand_int_v(2047, CAN_frame.identifier);
        ctu_put_tx_frame(CAN_frame, 1, TEST_NODE, chn);
        CAN_frame.identifier := CAN_frame.identifier + 1;
        ctu_put_tx_frame(CAN_frame, 1, DUT_NODE, chn);
        
        ctu_wait_sample_point(DUT_NODE, chn);
        wait for 20 ns;
        ctu_give_txt_cmd(buf_set_ready, 1, TEST_NODE, chn);
        ctu_give_txt_cmd(buf_set_ready, 1, DUT_NODE, chn);

        -----------------------------------------------------------------------
        -- @3. Wait until the end of arbitration in DUT. Check that AL Interrupt
        --     is set. Check that INT pin is high.
        -----------------------------------------------------------------------
        info_m("Step 3");

        ctu_wait_ff(ff_arbitration, DUT_NODE, chn);
        ctu_wait_not_ff(ff_arbitration, DUT_NODE, chn);
        
        ctu_get_int_status(int_stat, DUT_NODE, chn);
        check_m(int_stat.arb_lost_int,
                "AL Interrupt set after Arbitration lost!");
        interrupt_agent_check_asserted(chn);
        
        ctu_wait_bus_idle(DUT_NODE, chn);
        ctu_wait_bus_idle(TEST_NODE, chn);
        
        -----------------------------------------------------------------------
        -- @4. Disable AL Interrupt and check INT pin goes low. Enable AL 
        --     Interrupt and check INT pin goes high.
        -----------------------------------------------------------------------
        info_m("Step 4");

        int_ena.arb_lost_int := false;
        ctu_set_int_ena(int_ena, DUT_NODE, chn);
        wait for 10 ns;
        interrupt_agent_check_not_asserted(chn);
        
        int_ena.arb_lost_int := true;
        ctu_set_int_ena(int_ena, DUT_NODE, chn);
        wait for 10 ns;
        interrupt_agent_check_asserted(chn);

        -----------------------------------------------------------------------
        -- @5. Clear AL Interrupt and check it has been cleared and that INT
        --     pin is low.
        -----------------------------------------------------------------------
        info_m("Step 5");

        int_stat.arb_lost_int := true;
        ctu_clr_int_status(int_stat, DUT_NODE, chn);
        ctu_get_int_status(int_stat, DUT_NODE, chn);

        check_false_m(int_stat.arb_lost_int, "AL Interrupt cleared!");
        interrupt_agent_check_not_asserted(chn);  
        
        -----------------------------------------------------------------------
        -- @6. Mask AL Interrupt. Send again two frames as in step 2. Wait
        --     until arbitration is over in DUT and check that AL interrupt is
        --     now not set.
        -----------------------------------------------------------------------
        info_m("Step 6");

        int_mask.arb_lost_int := true;
        ctu_set_int_mask(int_mask, DUT_NODE, chn);

        ctu_wait_sample_point(DUT_NODE, chn);
        wait for 20 ns;
        ctu_give_txt_cmd(buf_set_ready, 1, TEST_NODE, chn);
        ctu_give_txt_cmd(buf_set_ready, 1, DUT_NODE, chn);

        ctu_wait_ff(ff_arbitration, DUT_NODE, chn);
        ctu_wait_not_ff(ff_arbitration, DUT_NODE, chn);

        ctu_get_int_status(int_stat, DUT_NODE, chn);
        check_false_m(int_stat.arb_lost_int,
                      "AL Interrupt not set when masked");
        interrupt_agent_check_not_asserted(chn);

        ctu_wait_bus_idle(DUT_NODE, chn);
        ctu_wait_bus_idle(TEST_NODE, chn);

        -----------------------------------------------------------------------
        -- @7. Disable AL Interrupt and check it was disabled. Enable AL
        --     Interrupt and check it was enabled.
        -----------------------------------------------------------------------
        info_m("Step 7");

        int_ena.arb_lost_int := false;
        ctu_set_int_ena(int_ena, DUT_NODE, chn);
        int_ena.arb_lost_int := true;

        ctu_get_int_ena(int_ena, DUT_NODE, chn);
        check_false_m(int_ena.arb_lost_int, "AL Interrupt Disabled!");

        int_ena.arb_lost_int := true;
        ctu_set_int_ena(int_ena, DUT_NODE, chn);
        int_ena.arb_lost_int := false;
        ctu_get_int_ena(int_ena, DUT_NODE, chn);
        check_m(int_ena.arb_lost_int, "AL Interrupt Enabled!");
        
        -----------------------------------------------------------------------
        -- @8. Mask AL Interrupt and check it was masked. Un-mask DO Interrupt
        --     and check it was un-masked.
        -----------------------------------------------------------------------
        info_m("Step 8");

        int_mask.arb_lost_int := true;
        ctu_set_int_mask(int_mask, DUT_NODE, chn);
        int_mask.arb_lost_int := false;
        ctu_get_int_mask(int_mask, DUT_NODE, chn);
        check_m(int_mask.arb_lost_int, "AL Interrupt masked!");

        int_mask.arb_lost_int := false;
        ctu_set_int_mask(int_mask, DUT_NODE, chn);
        int_mask.arb_lost_int := true;
        ctu_get_int_mask(int_mask, DUT_NODE, chn);
        check_false_m(int_mask.arb_lost_int, "AL Interrupt masked!");

        info_m("Finished AL interrupt test");

    end procedure;
end package body;