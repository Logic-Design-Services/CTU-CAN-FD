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
--  RX Error logging feature test 2
--
-- @Verifies:
--  @1. RX Error being logged with following ERF_POS values:
--      @1.1 ERF_POS_ACK
--      @1.2 ERF_POS_EOF
--      @1.3 ERF_POS_OVRL
--      @1.4 ERF_POS_ERR
--
-- @Test sequence:
--  @1. Configure DUT to MODE[ERFM] = 1. Disable SSP in DUT.
--  @2. Generate CAN frame and send it by DUT Node. Wait until CRC delimiter
--      and flip bus value. Wait until Sample point and release bus value.
--  @3. Check DUT is transmitting Error frame. Check RX Buffer contains single
--      Error Frame. Read out the error frame, and check that it is error frame
--      with ERF_POS = ERF_POS_ACK. Wait until bus is idle.
--  @4. Generate CAN frame and send it by DUT Node. Wait until End of frame field
--      and wait until random bit within End of Frame. Flip bus value and
--      wait till sample point. Release bus value.
--  @5. Check DUT node is transmitting error frame. Check RX Bufer of DUT
--      contains single Error frame. Read it from RX Buffer of DUT, and
--      check it has ERF_POS = ERF_POS_EOF. Wait until bus is idle.
--  @6. Generate CAN frame and send it by DUT node. Wait until DUT Node is
--      in first bit of Intermission. Flip bus value (overload condition), and
--      wait till sample point. Release bus value.
--  @7. Wait for one bit, and flip bus value. Wait till sample point and check
--      that DUT is transmitting Error frame. Check RX Buffer contains a single
--      Error frame. Release bus level.
--  @8. Wait for one more bit and flip bus value again (Bit Error in Error Flag).
--      Wait until Sample point and release Bus value. Check that DUTs RX Buffer
--      now contains two error frames. Wait until bus is idle.
--  @9. Read out both Error frames from DUTs RX Buffer, check first has
--      ERF_POS = ERF_POS_OVRL, and second has ERF_POS_ERR.
--      Wait until bus is idle.
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

package rx_err_log_2_ftest is
    procedure rx_err_log_2_ftest_exec(
        signal      chn             : inout  t_com_channel
    );
end package;


package body rx_err_log_2_ftest is

    procedure rx_err_log_2_ftest_exec(
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
        variable err_frame_2        : t_ctu_frame;
        variable rand_bits          : natural;
    begin

        -------------------------------------------------------------------------------------------
        -- @1. Configure DUT to MODE[ERFM] = 1.
        -------------------------------------------------------------------------------------------
        info_m("Step 1");

        mode_1.error_logging := true;
        ctu_set_mode(mode_1, DUT_NODE, chn);

        -------------------------------------------------------------------------------------------
        -- @2. Generate CAN frame and send it by DUT Node. Wait until CRC delimiter
        --      and flip bus value. Wait until Sample point and release bus value.
        -------------------------------------------------------------------------------------------
        info_m("Step 2");

        generate_can_frame(can_frame);
        -- NORMAL_CAN to work-around the issue with SSP at the last bit of CRC
        can_frame.frame_format := NORMAL_CAN;
        ctu_send_frame(can_frame, 1, DUT_NODE, chn, frame_sent);

        ctu_wait_ff(ff_crc_delim, DUT_NODE, chn);
        wait for 20 ns;
        flip_bus_level(chn);
        ctu_wait_sample_point(DUT_NODE, chn, false);
        wait for 20 ns;
        release_bus_level(chn);

        -- To make sure frame manages to be stored.
        wait for 100 ns;

        -------------------------------------------------------------------------------------------
        -- @3. Check DUT is transmitting Error frame. Check RX Buffer contains single
        --      Error Frame. Read out the error frame, and check that it is error frame
        --      with ERF_POS = ERF_POS_ACK. Wait until bus is idle.
        -------------------------------------------------------------------------------------------
        info_m("Step 3");

        ctu_get_status(status, DUT_NODE, chn);
        check_m(status.error_transmission, "Error frame is being transmitted!");

        ctu_get_rx_buf_state(rx_buf_state, DUT_NODE, chn);
        check_m(rx_buf_state.rx_frame_count = 1, "Single Error frame in RX Buffer!");

        ctu_read_frame(err_frame, DUT_NODE, chn);
        check_m(err_frame.erf = '1', "FRAME_FORMAT_W[ERF] = 1");
        check_m(err_frame.ivld = '1', "FRAME_FORMAT_W[IVLD] = 1");
        check_m(err_frame.erf_pos = ERC_POS_ACK, "FRAME_FORMAT_W[ERF_POS] = ERC_POS_ACK");

        -- When we manage to flip just the stuff bit due to randomization, it will be stuff error
        -- not from error!
        check_m(err_frame.erf_type = ERC_FRM_ERR or err_frame.erf_type = ERC_STUF_ERR,
                "FRAME_FORMAT_W[ERF_TYPE] = ERC_FRM_ERR or FRAME_FORMAT_W[ERF_TYPE] = ERC_STUF_ERR");

        ctu_wait_bus_idle(DUT_NODE, chn);

        -------------------------------------------------------------------------------------------
        -- @4. Generate CAN frame and send it by DUT Node. Wait until End of frame field
        --     and wait until random bit within End of Frame. Flip bus value, and wait till
        --     sample point. Release bus value.
        -------------------------------------------------------------------------------------------
        info_m("Step 4");

        generate_can_frame(can_frame);
        ctu_send_frame(can_frame, 1, DUT_NODE, chn, frame_sent);

        ctu_wait_ff(ff_eof, DUT_NODE, chn);

        rand_int_v(4, rand_bits);
        for i in 0 to rand_bits loop
            ctu_wait_sample_point(DUT_NODE, chn);
        end loop;

        wait for 20 ns;
        flip_bus_level(chn);
        ctu_wait_sample_point(DUT_NODE, chn);
        wait for 20 ns;
        release_bus_level(chn);

        -- To make sure frame manages to be stored.
        wait for 100 ns;

        -------------------------------------------------------------------------------------------
        --  @5. Check DUT node is transmitting error frame. Check RX Bufer of DUT
        --      contains single Error frame. Read it from RX Buffer of DUT, and
        --      check it has ERF_POS = ERF_POS_EOF. Wait until bus is idle.
        -------------------------------------------------------------------------------------------
        info_m("Step 5");

        ctu_get_status(status, DUT_NODE, chn);
        check_m(status.error_transmission, "Error frame is being transmitted!");

        ctu_get_rx_buf_state(rx_buf_state, DUT_NODE, chn);
        check_m(rx_buf_state.rx_frame_count = 1, "Single Error frame in RX Buffer!");

        ctu_read_frame(err_frame, DUT_NODE, chn);
        check_m(err_frame.erf = '1', "FRAME_FORMAT_W[ERF] = 1");
        check_m(err_frame.ivld = '1', "FRAME_FORMAT_W[IVLD] = 1");
        check_m(err_frame.erf_pos = ERC_POS_EOF, "FRAME_FORMAT_W[ERF_POS] = ERC_POS_EOF");
        check_m(err_frame.erf_type = ERC_FRM_ERR, "FRAME_FORMAT_W[ERF_TYPE] = ERC_FRM_ERR");

        ctu_wait_bus_idle(DUT_NODE, chn);

        -------------------------------------------------------------------------------------------
        -- @6. Generate CAN frame and send it by DUT node. Wait until DUT Node is
        --     in first bit of Intermission. Flip bus value (overload condition), and
        --     wait till sample point. Release bus value.
        -------------------------------------------------------------------------------------------
        info_m("Step 6");

        generate_can_frame(can_frame);
        ctu_send_frame(can_frame, 1, DUT_NODE, chn, frame_sent);

        ctu_wait_frame_start(true, false, DUT_NODE, chn);
        ctu_wait_ff(ff_intermission, DUT_NODE, chn);
        wait for 20 ns;

        flip_bus_level(chn);
        ctu_wait_sample_point(DUT_NODE, chn);
        wait for 20 ns;
        release_bus_level(chn);

        -------------------------------------------------------------------------------------------
        -- @7. Wait for one bit, and flip bus value. Wait till sample point and check
        --     that DUT is transmitting Error frame. Check RX Buffer contains a single
        --     Error frame. Release bus level;
        -------------------------------------------------------------------------------------------
        info_m("Step 7");

        ctu_wait_sample_point(DUT_NODE, chn);
        wait for 20 ns;

        flip_bus_level(chn);
        ctu_wait_sample_point(DUT_NODE, chn);
        wait for 20 ns;
        release_bus_level(chn);

        ctu_get_status(status, DUT_NODE, chn);
        check_m(status.error_transmission, "Error frame is being transmitted!");

        -- Wait till Error frame is stored;
        wait for 100 ns;

        ctu_get_rx_buf_state(rx_buf_state, DUT_NODE, chn);
        check_m(rx_buf_state.rx_frame_count = 1,
                "Single Error frame in RX Buffer, and it is: " &
                    integer'image(rx_buf_state.rx_frame_count));

        -------------------------------------------------------------------------------------------
        -- @8. Wait for one more bit and flip bus value again (Bit Error in Error Flag).
        --     Wait until Sample point and release Bus value. Check that DUTs RX Buffer
        --     now contains two error frames.
        -------------------------------------------------------------------------------------------
        info_m("Step 8");

        ctu_wait_sample_point(DUT_NODE, chn);
        wait for 20 ns;

        flip_bus_level(chn);
        ctu_wait_sample_point(DUT_NODE, chn);
        wait for 20 ns;
        release_bus_level(chn);

        -- Wait till Error frame is stored;
        wait for 100 ns;

        ctu_get_rx_buf_state(rx_buf_state, DUT_NODE, chn);
        check_m(rx_buf_state.rx_frame_count = 2, "Two Error frames in RX Buffer!");

        ctu_wait_bus_idle(DUT_NODE, chn);

        -------------------------------------------------------------------------------------------
        -- @9. Read out both Error frames from DUTs RX Buffer, check first has
        --     ERF_POS = ERF_POS_OVRL, and second has ERF_POS_ERR.
        -------------------------------------------------------------------------------------------
        info_m("Step 9");

        -- Read first one
        ctu_read_frame(err_frame, DUT_NODE, chn);
        check_m(err_frame.erf = '1', "Error Frame 1: FRAME_FORMAT_W[ERF] = 1");
        check_m(err_frame.ivld = '1', "Error Frame 1: FRAME_FORMAT_W[IVLD] = 1");
        check_m(err_frame.erf_pos = ERC_POS_OVRL, "Error Frame 1: FRAME_FORMAT_W[ERF_POS] = ERC_POS_OVRL");
        check_m(err_frame.erf_type = ERC_BIT_ERR, "Error Frame 1: FRAME_FORMAT_W[ERF_TYPE] = ERC_BIT_ERR");

        -- Read second one
        ctu_read_frame(err_frame_2, DUT_NODE, chn);
        check_m(err_frame_2.erf = '1', "Error Frame 2: FRAME_FORMAT_W[ERF] = 1");
        check_m(err_frame_2.ivld = '1', "Error Frame 2: FRAME_FORMAT_W[IVLD] = 1");
        check_m(err_frame_2.erf_pos = ERC_POS_ERR, "Error Frame 2: FRAME_FORMAT_W[ERF_POS] = ERC_POS_ERR");
        check_m(err_frame_2.erf_type = ERC_BIT_ERR, "Error Frame 2: FRAME_FORMAT_W[ERF_TYPE] = ERC_BIT_ERR");

    end procedure;

end package body;
