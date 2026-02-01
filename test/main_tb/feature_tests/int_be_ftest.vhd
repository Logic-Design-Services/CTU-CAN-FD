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
--  Interrupt DOI feature test.
--
-- @Verifies:
--  @1. BE Interrupt is set when node transmits error frame.
--  @2. BE Interrupt is not set when it is masked.
--  @3. BE Interrupt causes INT to go high when it is enabled.
--  @4. BE Interrupt causes INT to go low when it is disabled.
--  @5. BE Interrupt is cleared by write to INT_STATUS register.
--  @6. BE Interrupt enable is manipulated properly by INT_ENA_SET and
--      INT_ENA_CLEAR.
--  @7. BE Interrupt mask is manipulated properly by INT_MASK_SET and
--      INT_MASK_CLEAR.
--
-- @Test sequence:
--  @1. Unmask and enable BE Interrupt, disable and mask all other interrupts on
--      DUT.
--  @2. Set Test Node to Acknowledge forbidden mode. Set DUT to One shot mode.
--      Send frame by DUT, and wait till ACK field. Check that BE interrupt is
--      not set, wait until error frame and check that BE interrupt is set.
--  @3. Disable BE Interrupt and check INT pin goes low. Enable BE Interrupt
--      and check INT pin goes high.
--  @4. Clear BE Interrupt and check it has been cleared and that INT pin is low.
--  @5. Mask BE Interrupt. Send again frame by DUT. Wait until ACK and check
--      BE interrupt is not set. Wait until error frame and check BE interrupt
--      is still not set.
--  @6. Disable BE Interrupt and check it was disabled. Enable BE Interrupt and
--      check it was enabled.
--  @7. Mask BE Interrupt and check it was masked. Un-mask BE Interrupt and
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

package int_be_ftest is
    procedure int_be_ftest_exec(
        signal      chn             : inout  t_com_channel
    );
end package;

package body int_be_ftest is
    procedure int_be_ftest_exec(
        signal      chn             : inout  t_com_channel
    ) is
        variable can_frame          :     t_ctu_frame;
        variable frame_sent         :     boolean := false;

        variable int_mask           :     t_ctu_interrupts := t_ctu_interrupts_rst_val;
        variable int_ena            :     t_ctu_interrupts := t_ctu_interrupts_rst_val;
        variable int_stat           :     t_ctu_interrupts := t_ctu_interrupts_rst_val;
        variable command            :     t_ctu_command := t_ctu_command_rst_val;
        variable buf_info           :     t_ctu_rx_buf_state;
        variable status             :     t_ctu_status;
        
        variable mode_1             :     t_ctu_mode := t_ctu_mode_rst_val;
        variable mode_2             :     t_ctu_mode := t_ctu_mode_rst_val;
    begin

        -----------------------------------------------------------------------
        -- @1. Unmask and enable BE Interrupt, disable and mask all other
        --     interrupts on DUT.
        -----------------------------------------------------------------------
        info_m("Step 1");
        
        int_mask.bus_error_int := false;
        int_ena.bus_error_int := true;
        ctu_set_int_mask(int_mask, DUT_NODE, chn);
        ctu_set_int_ena(int_ena, DUT_NODE, chn);

        -----------------------------------------------------------------------
        -- @2. Set Test Node to Acknowledge forbidden mode. Set DUT to One shot
        --     mode. Send frame by DUT, and wait till ACK field. Check that BE
        --     interrupt is not set, wait until error frame and check that BE
        --     interrupt is set.
        -----------------------------------------------------------------------
        info_m("Step 2");

        ctu_set_retr_limit(true, 0, DUT_NODE, chn);
        mode_2.acknowledge_forbidden := true;
        ctu_set_mode(mode_2, TEST_NODE, chn);

        generate_can_frame(can_frame);
        ctu_send_frame(can_frame, 1, DUT_NODE, chn, frame_sent);
        
        ctu_wait_ff(ff_ack, DUT_NODE, chn);
        ctu_get_int_status(int_stat, DUT_NODE, chn);
        check_false_m(int_stat.bus_error_int,
                      "BE Interrupt not set before error frame");

        ctu_wait_err_frame(DUT_NODE, chn);
        wait for 10 ns;
        ctu_get_int_status(int_stat, DUT_NODE, chn);
        check_m(int_stat.bus_error_int, "BE Interrupt set by error frame");
        
        ctu_wait_bus_idle(TEST_NODE, chn);
        ctu_wait_bus_idle(DUT_NODE, chn);
        
        -----------------------------------------------------------------------
        -- @3. Disable BE Interrupt and check INT pin goes low. Enable BE
        --     Interrupt and check INT pin goes high.
        -----------------------------------------------------------------------
        info_m("Step 3");
        
        int_ena.bus_error_int := false;
        ctu_set_int_ena(int_ena, DUT_NODE, chn);
        wait for 10 ns;
        interrupt_agent_check_not_asserted(chn);
        
        int_ena.bus_error_int := true;
        ctu_set_int_ena(int_ena, DUT_NODE, chn);
        wait for 10 ns;
        interrupt_agent_check_asserted(chn);
        
        -----------------------------------------------------------------------
        -- @4. Clear BE Interrupt and check it has been cleared and that INT
        --     pin is low.
        -----------------------------------------------------------------------
        info_m("Step 4");
        
        int_stat.bus_error_int := true;
        ctu_clr_int_status(int_stat, DUT_NODE, chn);
        ctu_get_int_status(int_stat, DUT_NODE, chn);

        check_false_m(int_stat.bus_error_int, "BE Interrupt cleared!");
        interrupt_agent_check_not_asserted(chn);  
        
        -----------------------------------------------------------------------
        -- @5. Mask BE Interrupt. Send again frame by DUT. Wait until ACK and
        --     check BE interrupt is not set. Wait until error frame and check
        --     BE interrupt is still not set.
        -----------------------------------------------------------------------
        info_m("Step 5");

        int_mask.bus_error_int := true;
        ctu_set_int_mask(int_mask, DUT_NODE, chn);
        
        ctu_send_frame(can_frame, 1, DUT_NODE, chn, frame_sent);
        
        ctu_wait_ff(ff_ack, DUT_NODE, chn);
        ctu_get_int_status(int_stat, DUT_NODE, chn);
        check_false_m(int_stat.bus_error_int,
                      "BE Interrupt not set before error frame");
        
        ctu_wait_err_frame(DUT_NODE, chn);
        wait for 10 ns;
        check_false_m(int_stat.bus_error_int, "BE Interrupt not set when masked");
        
        ctu_wait_bus_idle(TEST_NODE, chn);
        ctu_wait_bus_idle(DUT_NODE, chn);
        
        -----------------------------------------------------------------------
        -- @6. Disable BE Interrupt and check it was disabled. Enable BE 
        --     Interrupt and check it was enabled.
        -----------------------------------------------------------------------
        info_m("Step 6");

        int_ena.bus_error_int := false;
        ctu_set_int_ena(int_ena, DUT_NODE, chn);
        int_ena.bus_error_int := true;

        ctu_get_int_ena(int_ena, DUT_NODE, chn);
        check_false_m(int_ena.bus_error_int, "BE Interrupt Disabled!");

        int_ena.bus_error_int := true;
        ctu_set_int_ena(int_ena, DUT_NODE, chn);
        int_ena.bus_error_int := false;
        ctu_get_int_ena(int_ena, DUT_NODE, chn);
        check_m(int_ena.bus_error_int, "BE Interrupt Enabled!");
        
        -----------------------------------------------------------------------
        -- @7. Mask BE Interrupt and check it was masked. Un-mask BE Interrupt
        --     and check it was un-masked.
        -----------------------------------------------------------------------
        info_m("Step 7");
        
        int_mask.bus_error_int := true;
        ctu_set_int_mask(int_mask, DUT_NODE, chn);
        int_mask.bus_error_int := false;
        ctu_get_int_mask(int_mask, DUT_NODE, chn);
        check_m(int_mask.bus_error_int, "BE Interrupt masked!");

        int_mask.bus_error_int := false;
        ctu_set_int_mask(int_mask, DUT_NODE, chn);
        int_mask.bus_error_int := true;
        ctu_get_int_mask(int_mask, DUT_NODE, chn);
        check_false_m(int_mask.bus_error_int, "BE Interrupt masked!");

        info_m("Finished BE interrupt test");

    end procedure;
end package body;