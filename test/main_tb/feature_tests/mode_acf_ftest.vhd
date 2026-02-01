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
--  Acknowledge forbidden feature test
--
-- @Verifies:
--  @1. When MODE[ACF] = 1, DUT acting as receiver does not send DOMINANT
--      ACK bit even if it correctly receives a frame.
--
-- @Test sequence:
--  @1. Configure Test Node to Self-Test Mode (do not require dominant ACK).
--  @2. Loop through following frame types: CAN 2.0 and CAN FD
--      @2.1. Enable Acknowledge Forbidden mode in DUT.
--      @2.2. Generate CAN frame and send it by Test Node.
--      @2.3. Wait until ACK field in DUT. Check DUT transmitts RECESSIVE.
--            Wait until bus is idle.
--      @2.4. Disable Acknowledge Forbidden mode in DUT.
--      @2.5. Send the same CAN frame as in 2.2.
--      @2.6. Wait until ACK field in DUT. Check DUT transmitts DOMINANT.
--            Wait until bus is idle.
--
-- @TestInfoEnd
--------------------------------------------------------------------------------
-- Revision History:
--    30.07.2024   Created file
--------------------------------------------------------------------------------

Library ctu_can_fd_tb;
context ctu_can_fd_tb.ieee_context;
context ctu_can_fd_tb.rtl_context;
context ctu_can_fd_tb.tb_common_context;

use ctu_can_fd_tb.feature_test_agent_pkg.all;

package mode_acf_ftest is
    procedure mode_acf_ftest_exec(
        signal      chn             : inout  t_com_channel
    );
end package;


package body mode_acf_ftest is
    procedure mode_acf_ftest_exec(
        signal      chn             : inout  t_com_channel
    ) is
        variable mode_1             :       t_ctu_mode := t_ctu_mode_rst_val;
        variable mode_2             :       t_ctu_mode := t_ctu_mode_rst_val;

        variable can_frame          :       t_ctu_frame;
        variable frame_sent         :       boolean := false;

        variable dut_can_tx         :       std_logic;
        variable bit_duration       :       time;
    begin

        -------------------------------------------------------------------------------------------
        -- @1. Configure Test Node to Self-Test Mode (do not require dominant ACK).
        -------------------------------------------------------------------------------------------
        info_m("Step 1");

        mode_2.self_test := true;
        ctu_set_mode(mode_1, TEST_NODE, chn);

        ctu_measure_bit_duration(DUT_NODE, chn, bit_duration);

        -------------------------------------------------------------------------------------------
        -- @2. Loop through following frame types: CAN 2.0 and CAN FD
        -------------------------------------------------------------------------------------------
        info_m("Step 2");

        for frame_format in NORMAL_CAN to FD_CAN loop

            ---------------------------------------------------------------------------------------
            -- @2.1. Enable Acknowledge Forbidden mode in DUT.
            ---------------------------------------------------------------------------------------
            info_m("Step 2.1");

            mode_1.acknowledge_forbidden := true;
            ctu_set_mode(mode_1, DUT_NODE, chn);

            ---------------------------------------------------------------------------------------
            -- @2.2. Generate CAN frame and send it by Test Node.
            ---------------------------------------------------------------------------------------
            info_m("Step 2.2");

            generate_can_frame(can_frame);
            can_frame.frame_format := frame_format;
            ctu_send_frame(can_frame, 1, TEST_NODE, chn, frame_sent);

            ---------------------------------------------------------------------------------------
            -- @2.3. Wait until ACK field in DUT. Check DUT transmitts RECESSIVE.
            --       Wait until bus is idle.
            ---------------------------------------------------------------------------------------
            info_m("Step 2.3");

            ctu_wait_ff(ff_ack, DUT_NODE, chn);

            -- Reliable way how to wait until the middle of bit
            wait for bit_duration / 2;

            get_can_tx(DUT_NODE, dut_can_tx, chn);
            check_m(dut_can_tx = RECESSIVE, "DUT sends recessive ACK when MODE[ACF]=1");

            ctu_wait_bus_idle(DUT_NODE, chn);

            ---------------------------------------------------------------------------------------
            -- @2.4. Disable Acknowledge Forbidden mode in DUT.
            ---------------------------------------------------------------------------------------
            info_m("Step 2.4");

            mode_1.acknowledge_forbidden := false;
            ctu_set_mode(mode_1, DUT_NODE, chn);

            ---------------------------------------------------------------------------------------
            -- @2.5. Send the same CAN frame as in 2.2.
            ---------------------------------------------------------------------------------------
            info_m("Step 2.5");

            ctu_send_frame(can_frame, 1, TEST_NODE, chn, frame_sent);

            ---------------------------------------------------------------------------------------
            -- @2.6. Wait until ACK field in DUT. Check DUT transmitts DOMINANT.
            --       Wait until bus is idle.
            ---------------------------------------------------------------------------------------
            info_m("Step 2.6");

            ctu_wait_ff(ff_ack, DUT_NODE, chn);

            -- Reliable way how to wait until the middle of bit
            wait for bit_duration / 2;

            get_can_tx(DUT_NODE, dut_can_tx, chn);
            check_m(dut_can_tx = DOMINANT, "DUT sends Dominant ACK when MODE[ACF]=0");

            ctu_wait_bus_idle(DUT_NODE, chn);

        end loop;

  end procedure;

end package body;