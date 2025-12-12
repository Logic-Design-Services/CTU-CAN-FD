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
--  ERR_CAPT[ERR_POS] = ERC_POS_CTRL, form error feature test. 
--
-- @Verifies:
--  @1. Detection of form error in control field on r0 bit in CAN 2.0 base frame,
--      on r0 bit in CAN FD base frame, on r1 bit in CAN 2.0 extended frame
--      and r0 in CAN FD extended frame when protocol exception handling is
--      disabled!
--  @2. Value of ERR_CAPT[ERR_POS] when form error shall be detected in control
--      field of CAN frame!
--
-- @Test sequence:
--  @1. Check that ERR_CAPT contains no error (post reset).
--  @2. Generate CAN frame (CAN 2.0 Base only, CAN FD Base only, CAN 2.0 Extended,
--      CAN FD extended), send it by Test Node. Wait until Arbitration field of
--      the other node and wait and wait
--      for 13 (Base ID, RTR, IDE) or 14 (Base ID, RTR, IDE, EDL) or 32 bits
--      (Base ID, SRR, IDE, Ext ID, RTR) or 33 (Base ID, SRR, IDE, Ext ID, RTR,
--      EDL) bits based on frame type.
--      Force bus Recessive (reserved bits are dominant) and wait until sample
--      point. Check that Node is transmitting error frame. Check that ERR_CAPT
--      signals Form Error in Control field. Reset the node, Wait until integration
--      is over and check that ERR_CAPT is at its reset value (this is to check
--      that next loops will truly set ERR_CAPT). Repeat with each frame type!
--
-- @TestInfoEnd
--------------------------------------------------------------------------------
-- Revision History:
--    03.02.2020   Created file
--------------------------------------------------------------------------------

Library ctu_can_fd_tb;
context ctu_can_fd_tb.ieee_context;
context ctu_can_fd_tb.rtl_context;
context ctu_can_fd_tb.tb_common_context;

use ctu_can_fd_tb.feature_test_agent_pkg.all;

package err_capt_ctrl_form_ftest is
    procedure err_capt_ctrl_form_ftest_exec(
        signal      chn             : inout  t_com_channel
    );
end package;


package body err_capt_ctrl_form_ftest is
    procedure err_capt_ctrl_form_ftest_exec(
        signal      chn             : inout  t_com_channel
    ) is
        -- Generated frames
        variable frame_1            :     t_ctu_frame;

        -- Node status
        variable stat_1             :     t_ctu_status;    
        variable stat_2             :     t_ctu_status;

        -- Node mode
        variable mode_2             :     t_ctu_mode;
        variable mode_1             :     t_ctu_mode;

        variable wait_time          :     natural;
        variable frame_sent         :     boolean;
        variable err_capt           :     t_ctu_err_capt;
    begin

        -----------------------------------------------------------------------
        -- @1. Check that ERR_CAPT contains no error (post reset).
        -----------------------------------------------------------------------
        info_m("Step 1");
        
        ctu_get_err_capt(err_capt, DUT_NODE, chn);
        check_m(err_capt.err_pos = err_pos_other, "Reset of ERR_CAPT!");

        -- Protocol exception should be disabled, otherwise, we dont get error
        -- frame upon form error in control field.
        ctu_get_mode(mode_2, DUT_NODE, chn);
        mode_2.pex_support := false;
        ctu_set_mode(mode_2, DUT_NODE, chn);

        -----------------------------------------------------------------------
        -- @2. Generate CAN frame (CAN 2.0 Base only, CAN FD Base only, CAN 2.0
        --    Extended, CAN FD extended), send it by Test Node. Wait until
        --    Arbitration field of the other node and wait for 13 (Base ID, RTR,
        --    IDE) or 14 (Base ID, RTR, IDE, EDL) or 34 bits (Base ID, SRR, IDE,
        ---   Ext ID, RTR) or 35 bits  (Base ID, SRR, IDE, Ext ID, RTR, EDL)
        --    bits based on frame type. Force bus Recessive
        --    (reserved bits are dominant) and wait until sample point. Check
        --    that Node is transmitting error frame. Check that ERR_CAPT signals
        --    Form Error in Control field. Reset the node, Wait until integration
        --    is over and check that ERR_CAPT is at its reset value (this is to
        ---   check that next loops will truly set ERR_CAPT). Repeat with each
        --    frame type!
        -----------------------------------------------------------------------
        for i in 1 to 4 loop
            info_m("Inner Loop: " & integer'image(i));
            generate_can_frame(frame_1);

            -- ID is not important in this TC. Avoid overflows of high generated
            -- IDs on Base IDs!
            frame_1.identifier := 10;
            -- This is to avoid failing assertions on simultaneous RTR and EDL
            -- flag (if r0 is corrupted by TC to be recessive!). RTR flag is
            -- not important in this TC, therefore we can afford to fixate it!
            frame_1.RTR := NO_RTR_FRAME;
            
            case i is
            when 1 =>
                frame_1.frame_format := NORMAL_CAN;
                frame_1.ident_type := BASE;
                wait_time := 13; -- Till r0
                
                -- This is to get Form error on r0 RECESSIVE
                ctu_get_mode(mode_1, DUT_NODE, chn);
                mode_1.flexible_data_rate := false;
                ctu_set_mode(mode_1, DUT_NODE, chn);

            when 2 =>
                frame_1.frame_format := FD_CAN;
                frame_1.ident_type := BASE;
                wait_time := 14; -- Till r0
                
                -- This is to get Form error on r0 (after EDL) RECESSIVE
                ctu_get_mode(mode_1, DUT_NODE, chn);
                mode_1.flexible_data_rate := true;
                ctu_set_mode(mode_1, DUT_NODE, chn);
                
            when 3 =>
                frame_1.frame_format := NORMAL_CAN;
                frame_1.ident_type := EXTENDED;
                wait_time := 32; -- Till r1
                
                -- This is to get Form error on r1
                ctu_get_mode(mode_1, DUT_NODE, chn);
                mode_1.flexible_data_rate := false;
                ctu_set_mode(mode_1, DUT_NODE, chn);
                
            when 4 =>
                frame_1.frame_format := FD_CAN;
                frame_1.ident_type := EXTENDED;
                wait_time := 33; -- Till r0
                
                -- This is to get Form error on r0 (after EDL) RECESSIVE
                ctu_get_mode(mode_1, DUT_NODE, chn);
                mode_1.flexible_data_rate := true;
                ctu_set_mode(mode_1, DUT_NODE, chn);
                
            end case;
            
            ctu_send_frame(frame_1, 1, TEST_NODE, chn, frame_sent);

            ctu_wait_ff(ff_arbitration, DUT_NODE, chn);
            
            info_m("Waiting for: " & integer'image(wait_time) & " bits!");
            for j in 1 to wait_time loop
                ctu_wait_sample_point(DUT_NODE, chn);
            end loop;
            
            -- Force bus for one bit time
            force_bus_level(RECESSIVE, chn);
            ctu_wait_sample_point(DUT_NODE, chn, skip_stuff_bits => false);
            wait for 20 ns; -- To be sure that opposite bit is sampled!
            release_bus_level(chn);
            
            -- Check errors
            ctu_get_status(stat_2, DUT_NODE, chn);
            check_m(stat_2.error_transmission,
                    "Error frame is being transmitted!");
        
            ctu_get_err_capt(err_capt, DUT_NODE, chn);
            check_m(err_capt.err_type = can_err_form, "Form error detected!");
            check_m(err_capt.err_pos = err_pos_ctrl,
                    "Error detected in Control field!");
            wait for 100 ns; -- For debug only to see waves properly!

            -- Reset both nodes
            ctu_soft_reset(TEST_NODE, chn);
            ctu_soft_reset(DUT_NODE, chn);
            ctu_turn(true, TEST_NODE, chn);
            ctu_turn(true, DUT_NODE, chn);
            ctu_wait_err_active(TEST_NODE, chn);
            ctu_wait_err_active(DUT_NODE, chn);

            ctu_get_err_capt(err_capt, DUT_NODE, chn);
            check_m(err_capt.err_pos = err_pos_other, "Reset value other");
        end loop;

  end procedure;

end package body;
