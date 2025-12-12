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
--  RX Error logging feature tests
--
-- @Verifies:
--  @1. RX Error being logged with following ERF_POS values:
--      @1.1 ERF_POS_ARB
--      @1.2 ERF_POS_CTRL
--      @1.3 ERF_POS_DATA
--      @1.4 ERF_POS_CRC
--
-- @Test sequence:
--  @1. Configure DUT to MODE[ERFM] = 1.
--  @2. Iterate through Arbitration, Control, Data and CRC fields of
--      Protocol control:
--      @2.1 Generate CAN frame and send it by DUT.
--      @2.2 Wait until Protocol control field being tested and wait until
--           Dominant bit.
--      @2.3 Flip bus value. Wait until sample point. Release bus value.
--      @2.4 Check Error frame is being transmitted. Check single frame is
--           in RX Buffer.
--      @2.5 Wait until bus is idle. Read the frame from the RX Buffer.
--           Check its ERF_POS value is as expected. Check its ERF bit is set.
--           Check its IVLD bit is set apart from Error frame in Arbitration.
--
-- @TestInfoEnd
--------------------------------------------------------------------------------
-- Revision History:
--    5.8.2024   Created file
--------------------------------------------------------------------------------

Library ctu_can_fd_tb;
context ctu_can_fd_tb.ieee_context;
context ctu_can_fd_tb.rtl_context;
context ctu_can_fd_tb.tb_common_context;

use ctu_can_fd_tb.feature_test_agent_pkg.all;

package rx_err_log_ftest is
    procedure rx_err_log_ftest_exec(
        signal      chn             : inout  t_com_channel
    );
end package;


package body rx_err_log_ftest is

    procedure rx_err_log_ftest_exec(
        signal      chn             : inout  t_com_channel
    ) is
        variable mode_1             : t_ctu_mode := t_ctu_mode_rst_val;
        variable ff             : t_ctu_frame_field;
        variable frame_sent         : boolean;
        variable tx_val             : std_logic;
        variable status             : t_ctu_status;
        variable rx_buf_state        : t_ctu_rx_buf_state;
        variable can_frame          : t_ctu_frame;
        variable err_frame          : t_ctu_frame;
    begin

        -------------------------------------------------------------------------------------------
        -- @1. Configure DUT to MODE[ERFM] = 1.
        -------------------------------------------------------------------------------------------
        info_m("Step 1");

        mode_1.error_logging := true;
        ctu_set_mode(mode_1, DUT_NODE, chn);

        -------------------------------------------------------------------------------------------
        -- @2. Iterate through Arbitration, Control, Data and CRC fields of
        --      Protocol control:
        -------------------------------------------------------------------------------------------
        info_m("Step 2");

        for i in 0 to 3 loop
            case (i) is
            when 0 => ff := ff_arbitration;
            when 1 => ff := ff_control;
            when 2 => ff := ff_data;
            when others => ff := ff_crc;
            end case;

            info_m("Testing ERF_POS in: " & t_ctu_frame_field'image(ff));

            ---------------------------------------------------------------------------------------
            -- @2.1 Generate CAN frame and send it by DUT.
            ---------------------------------------------------------------------------------------
            info_m("Step 2.1");

            generate_can_frame(can_frame);
            can_frame.rtr := NO_RTR_FRAME;
            can_frame.frame_format := NORMAL_CAN;
            can_frame.data_length := 8;     -- To make sure data field is there!
            length_to_dlc(can_frame.data_length, can_frame.dlc);

            ctu_send_frame(can_frame, 1, DUT_NODE, chn, frame_sent);

            ---------------------------------------------------------------------------------------
            -- @2.2 Wait until Protocol control field being tested and wait until Dominant bit.
            ---------------------------------------------------------------------------------------
            info_m("Step 2.2");

            ctu_wait_ff(ff, DUT_NODE, chn);
            ctu_wait_sample_point(DUT_NODE, chn);

            dom_bit_wait : while (true) loop
                ctu_wait_sync_seg(DUT_NODE, chn);
                wait for 20 ns;
                get_can_tx(DUT_NODE, tx_val, chn);
                if (tx_val = DOMINANT) then
                    exit dom_bit_wait;
                end if;
            end loop;

            ---------------------------------------------------------------------------------------
            -- @2.3 Flip bus value. Wait until sample point. Release bus value.
            ---------------------------------------------------------------------------------------
            info_m("Step 2.3");

            flip_bus_level(chn);

            ctu_wait_sample_point(DUT_NODE, chn, false);
            wait for 20 ns;

            release_bus_level(chn);

            -- Need to wait for few cycles so that the Error frame is stored there!
            wait for 100 ns;

            ---------------------------------------------------------------------------------------
            -- @2.4 Check Error frame is being transmitted. Check single frame is in RX Buffer.
            ---------------------------------------------------------------------------------------
            info_m("Step 2.4");

            ctu_get_status(status, DUT_NODE, chn);
            check_m(status.error_transmission, "Error frame is being transmitted!");

            ctu_get_rx_buf_state(rx_buf_state, DUT_NODE, chn);
            check_m(rx_buf_state.rx_frame_count = 1, "Single Error frame in RX Buffer!");

            ---------------------------------------------------------------------------------------
            -- @2.5 Wait until bus is idle. Read the frame from the RX Buffer.
            --      Check its ERF_POS value is as expected. Check its ERF bit is set.
            --      Check its IVLD bit is set apart from Error frame in Arbitration.
            ---------------------------------------------------------------------------------------
            info_m("Step 2.5");

            ctu_wait_bus_idle(DUT_NODE, chn);
            ctu_read_frame(err_frame, DUT_NODE, chn);
            check_m(err_frame.erf = '1',                            "FRAME_FORMAT_W[ERF] = 1");

            -- All fields apart from arbitration shall have IVLD set!
            if (i > 0) then
                check_m(err_frame.ivld = '1',                       "FRAME_FORMAT_W[IVLD] = 1");
                check_m(err_frame.identifier = can_frame.identifier,"Identifier match");
            else
                check_m(err_frame.ivld = '0',                       "FRAME_FORMAT_W[IVLD] = 0");
            end if;

            case (i) is
            when 0      => check_m(err_frame.erf_pos = ERC_POS_ARB,    "ERF_POS = Arbitration");
            when 1      => check_m(err_frame.erf_pos = ERC_POS_CTRL,   "ERF_POS = Control");
            when 2      => check_m(err_frame.erf_pos = ERC_POS_DATA,   "ERF_POS = Data");
            when others => check_m(err_frame.erf_pos = ERC_POS_CRC,    "ERF_POS = CRC");
            end case;

        end loop;

  end procedure;

end package body;
