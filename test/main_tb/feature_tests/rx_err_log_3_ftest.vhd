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
--  RX Error logging feature test 3
--
-- @Verifies:
--  @1. RX Error being logged with following ERF_TYPE values:
--      @1.1 ERC_BIT_ERR
--      @1.2 ERC_STUF_ERR
--      @1.3 ERC_CRC_ERR
--      @1.4 ERC_FRM_ERR
--      @1.5 ERC_ACK_ERR
--
-- @Test sequence:
--  @1. Configure DUT to MODE[ERFM] = 1. Disable SSP in DUT.
--  @2. Generate CAN frame with 0xAA in Data field. Send it by DUT.
--      Wait until Data field in DUT. Flip bus, and wait till sample point.
--      Release bus value. Check DUT is in Error frame. Check it containts
--      single Error frame logged in RX Buffer. Read the Error frame and
--      check that ERF_TYPE = ERC_BIT_ERR. Wait until bus is idle.
--  @3. Generate CAN frame with 0xA0 in Data field. Send it by Test Node.
--      Wait until stuff bit bi Data field and flip bus value. Wait until
--      sample point in DUT. Release Bus value. Check DUT is transmitting
--      Error frame. Check there is one Error frame in RX Buffer. Read it
--      and check it has ERF_TYPE = ERC_STUF_ERR.
--  @4. Generate CAN frame and send it by Test Node. Wait until CRC field
--      in DUT and flip bus value. Wait until sample point. Release bus
--      value and wait until Error frame. Check DUTs RX Buffer has 1 Error
--      frame. Read it and check that it has ERF_TYPE = ERC_CRC_ERR or
--      ERC_STUF_ERR. Wait until bus is idle.
--  @5. Generate CAN frame and send it by DUT Node. Wait until ACK delimiter
--      in DUT and flip bus value. Wait until sample point and release bus
--      value. Check DUTs RX Buffer contains single RX frame. Read it, and
--      check it has ERF_TYPE = ERC_FRM_ERR. Wait until bus is idle.
--  @6. Configure Test Node to Acknowledge forbidden mode.
--      Generate CAN frame and send it by DUT Node. Wait until Error frame
--      in DUT Node, and check DUTs RX Buffer contains single Error frame.
--      Read it, and check its ERF_TYPE = ERC_ACK_ERR.
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

package rx_err_log_3_ftest is
    procedure rx_err_log_3_ftest_exec(
        signal      chn             : inout  t_com_channel
    );
end package;


package body rx_err_log_3_ftest is

    procedure rx_err_log_3_ftest_exec(
        signal      chn             : inout  t_com_channel
    ) is
        variable mode_1             : t_ctu_mode := t_ctu_mode_rst_val;
        variable mode_2             : t_ctu_mode := t_ctu_mode_rst_val;
        variable status             : t_ctu_status;
        variable frame_sent         : boolean;
        variable can_frame          : t_ctu_frame;
        variable err_frame          : t_ctu_frame;
        variable rx_buf_state        : t_ctu_rx_buf_state;
        variable can_rx             : std_logic;
    begin

        -------------------------------------------------------------------------------------------
        -- @1. Configure DUT to MODE[ERFM] = 1. Disable SSP in DUT.
        -------------------------------------------------------------------------------------------
        info_m("Step 1");

        mode_1.error_logging := true;
        ctu_set_mode(mode_1, DUT_NODE, chn);

        ctu_set_ssp(ssp_no_ssp, x"00", DUT_NODE, chn);

        -------------------------------------------------------------------------------------------
        -- @2. Generate CAN frame with 0xAA in Data field. Send it by DUT.
        --     Wait until Data field in DUT. Flip bus, and wait till sample point.
        --     Release bus value. Check DUT is in Error frame. Check it containts
        --     single Error frame logged in RX Buffer. Read the Error frame and
        --     check that ERF_TYPE = ERC_BIT_ERR. Wait until bus is idle.
        -------------------------------------------------------------------------------------------
        info_m("Step 2");

        generate_can_frame(can_frame);
        can_frame.rtr := NO_RTR_FRAME;
        can_frame.data_length := 2;
        can_frame.data(0) := x"AA";
        can_frame.data(1) := x"AA";
        length_to_dlc(can_frame.data_length, can_frame.dlc);

        ctu_send_frame(can_frame, 1, DUT_NODE, chn, frame_sent);
        ctu_wait_ff(ff_data, DUT_NODE, chn);
        ctu_wait_sample_point(DUT_NODE, chn);
        ctu_wait_sample_point(DUT_NODE, chn);

        flip_bus_level(chn);

        ctu_wait_sample_point(DUT_NODE, chn, false);
        wait for 20 ns;

        release_bus_level(chn);

        ctu_wait_sample_point(DUT_NODE, chn, false);
        ctu_wait_sample_point(DUT_NODE, chn, false);

        ctu_get_status(status, DUT_NODE, chn);
        check_m(status.error_transmission, "Error frame is being transmitted!");

        ctu_get_rx_buf_state(rx_buf_state, DUT_NODE, chn);
        check_m(rx_buf_state.rx_frame_count = 1, "Single Error frame in RX Buffer!");

        ctu_read_frame(err_frame, DUT_NODE, chn);
        check_m(err_frame.erf = '1', "FRAME_FORMAT_W[ERF] = 1");
        check_m(err_frame.ivld = '1', "FRAME_FORMAT_W[IVLD] = 1");
        check_m(err_frame.erf_pos = ERC_POS_DATA, "FRAME_FORMAT_W[ERF_POS] = ERC_POS_DATA");
        check_m(err_frame.erf_type = ERC_BIT_ERR, "FRAME_FORMAT_W[ERF_TYPE] = ERC_BIT_ERR");

        ctu_get_rx_buf_state(rx_buf_state, DUT_NODE, chn);
        check_m(rx_buf_state.rx_frame_count = 0, "No Error frame in RX Buffer!");

        ctu_wait_bus_idle(DUT_NODE, chn);
        ctu_wait_bus_idle(TEST_NODE, chn);

        -------------------------------------------------------------------------------------------
        -- @3. Generate CAN frame with 0x5F in Data field. Send it by Test Node.
        --     Wait until stuff bit bi Data field and flip bus value. Wait until
        --     sample point in DUT. Release Bus value. Check DUT is transmitting
        --     Error frame. Check there is one Error frame in RX Buffer. Read it
        --     and check it has ERF_TYPE = ERC_STUF_ERR.
        -------------------------------------------------------------------------------------------
        info_m("Step 3");

        generate_can_frame(can_frame);
        can_frame.rtr := NO_RTR_FRAME;
        can_frame.data_length := 2;
        can_frame.data(0) := x"5F";
        can_frame.data(1) := x"00";
        length_to_dlc(can_frame.data_length, can_frame.dlc);

        ctu_send_frame(can_frame, 1, TEST_NODE, chn, frame_sent);
        ctu_wait_ff(ff_data, DUT_NODE, chn);

        -- 0x5F -- 01011111
        --            -----
        -- After last 5 bits of first data byte there will be a stuff bit.
        for i in 1 to 8 loop
            ctu_wait_sample_point(DUT_NODE, chn, false);
        end loop;

        wait for 20 ns;

        flip_bus_level(chn);

        ctu_wait_sample_point(DUT_NODE, chn, false);
        wait for 20 ns;

        release_bus_level(chn);

        wait for 200 ns;

        ctu_get_status(status, DUT_NODE, chn);
        check_m(status.error_transmission, "Error frame is being transmitted!");

        ctu_get_rx_buf_state(rx_buf_state, DUT_NODE, chn);
        check_m(rx_buf_state.rx_frame_count = 1, "Single Error frame in RX Buffer!");

        ctu_read_frame(err_frame, DUT_NODE, chn);
        check_m(err_frame.erf = '1', "FRAME_FORMAT_W[ERF] = 1");
        check_m(err_frame.ivld = '1', "FRAME_FORMAT_W[IVLD] = 1");
        check_m(err_frame.erf_pos = ERC_POS_DATA, "FRAME_FORMAT_W[ERF_POS] = ERC_POS_DATA");
        check_m(err_frame.erf_type = ERC_STUF_ERR, "FRAME_FORMAT_W[ERF_TYPE] = ERC_STUF_ERR");

        ctu_get_rx_buf_state(rx_buf_state, DUT_NODE, chn);
        check_m(rx_buf_state.rx_frame_count = 0, "No Error frame in RX Buffer!");

        ctu_wait_bus_idle(DUT_NODE, chn);
        ctu_wait_bus_idle(TEST_NODE, chn);

        -------------------------------------------------------------------------------------------
        -- @4. Generate CAN frame and send it by Test Node. Wait until CRC field
        --     in DUT and flip bus value. Wait until sample point. Release bus
        --     value and wait until Error frame. Check DUTs RX Buffer has 1 Error
        --     frame. Read it and check that it has ERF_TYPE = ERC_CRC_ERR or
        --     ERC_STUF_ERR. Wait until bus is idle.
        -------------------------------------------------------------------------------------------
        info_m("Step 4");

        -- We need to set Test Node to Self-test mode. If not, due to missing ACK from DUT, the
        -- Test Node would transmitt Error frame in ACK Delimiter, causing an Error in
        -- ACK delimiter detected by DUT to be interpreted as Form Error, not CRC Error.
        -- Form error has priority over CRC Error.
        mode_2.self_test := true;
        ctu_set_mode(mode_2, TEST_NODE, chn);

        -- Hard-code the frame to avoid randomization
        -- This is because we want to invoke CRC_ERROR. We achieve that by flipping a bit
        -- in the CRC. However, if the frame was random, this could cause that stuff bit
        -- is dropped (if a sequence of equal bits is interrupte)!
        -- This would lead to different length of CRC field in the Test Node (transmitter).
        -- If the last bit of Test Nodes CRC field was dominant, then this would span
        -- to CRC Delimiter in DUT due to DUTs CRC being one bit shorter.
        -- Thus DUT would detect form error in CRC delimiter instead of CRC error!
        generate_can_frame(can_frame);
        can_frame.frame_format := NORMAL_CAN;
        can_frame.ident_type := BASE;
        can_frame.identifier := 0;
        can_frame.data_length := 1;
        length_to_dlc(can_frame.data_length, can_frame.dlc);

        -- This data pattern should satisfy that when we flip first or second crc bit,
        -- it is not a stuff bit
        can_frame.data(0) := x"AA";

        ctu_send_frame(can_frame, 1, TEST_NODE, chn, frame_sent);
        ctu_wait_ff(ff_crc, DUT_NODE, chn);

        ctu_wait_sample_point(DUT_NODE, chn);
        ctu_wait_sync_seg(DUT_NODE, chn);
        wait for 2 ns;

        get_can_rx(DUT_NODE, can_rx, chn);
        force_can_rx(not can_rx, DUT_NODE, chn);

        ctu_wait_sample_point(DUT_NODE, chn, false);
        ctu_wait_input_delay(chn);
        release_can_rx(chn);

        ctu_wait_err_frame(DUT_NODE, chn);

        wait for 200 ns;

        ctu_get_rx_buf_state(rx_buf_state, DUT_NODE, chn);
        check_m(rx_buf_state.rx_frame_count = 1, "Single Error frame in RX Buffer!");

        ctu_read_frame(err_frame, DUT_NODE, chn);
        check_m(err_frame.erf = '1', "FRAME_FORMAT_W[ERF] = 1");
        check_m(err_frame.ivld = '1', "FRAME_FORMAT_W[IVLD] = 1");
        check_m(err_frame.erf_type = ERC_CRC_ERR, "FRAME_FORMAT_W[ERF_TYPE] = ERC_CRC_ERR");

        ctu_get_rx_buf_state(rx_buf_state, DUT_NODE, chn);
        check_m(rx_buf_state.rx_frame_count = 0, "No Error frame in RX Buffer!");

        ctu_wait_bus_idle(DUT_NODE, chn);

        -------------------------------------------------------------------------------------------
        -- @5. Generate CAN frame and send it by DUT Node. Wait until ACK Delimiter
        --     in DUT and flip bus value. Wait until sample point and release bus
        --     value. Check DUTs RX Buffer contains single RX frame. Read it, and
        --     check it has ERF_TYPE = ERC_FRM_ERR. Wait until bus is idle.
        -------------------------------------------------------------------------------------------
        info_m("Step 5");

        generate_can_frame(can_frame);
        can_frame.frame_format := NORMAL_CAN;
        ctu_send_frame(can_frame, 1, DUT_NODE, chn, frame_sent);
        ctu_wait_ff(ff_ack_delim, DUT_NODE, chn);

        wait for 20 ns;
        flip_bus_level(chn);

        ctu_wait_sample_point(DUT_NODE, chn, false);
        wait for 20 ns;

        release_bus_level(chn);

        wait for 200 ns;

        ctu_get_rx_buf_state(rx_buf_state, DUT_NODE, chn);
        check_m(rx_buf_state.rx_frame_count = 1, "Single Error frame in RX Buffer!");

        ctu_read_frame(err_frame, DUT_NODE, chn);
        check_m(err_frame.erf = '1', "FRAME_FORMAT_W[ERF] = 1");
        check_m(err_frame.ivld = '1', "FRAME_FORMAT_W[IVLD] = 1");
        check_m(err_frame.erf_pos = ERC_POS_ACK, "FRAME_FORMAT_W[ERF_POS] = ERC_POS_CRC");
        check_m(err_frame.erf_type = ERC_FRM_ERR, "FRAME_FORMAT_W[ERF_TYPE] = ERC_FRM_ERR");

        ctu_get_rx_buf_state(rx_buf_state, DUT_NODE, chn);
        check_m(rx_buf_state.rx_frame_count = 0, "No Error frame in RX Buffer!");

        ctu_wait_bus_idle(DUT_NODE, chn);

        -------------------------------------------------------------------------------------------
        -- @6. Configure Test Node to Acknowledge forbidden mode.
        --     Generate CAN frame and send it by DUT Node. Wait until Error frame
        --     in DUT Node, and check DUTs RX Buffer contains single Error frame.
        --     Read it, and check its ERF_TYPE = ERC_ACK_ERR.
        -------------------------------------------------------------------------------------------
        info_m("Step 6");

        mode_2.acknowledge_forbidden := true;
        ctu_set_mode(mode_2, TEST_NODE, chn);

        generate_can_frame(can_frame);
        ctu_send_frame(can_frame, 1, DUT_NODE, chn, frame_sent);

        ctu_wait_err_frame(DUT_NODE, chn);

        wait for 200 ns;

        ctu_get_rx_buf_state(rx_buf_state, DUT_NODE, chn);
        check_m(rx_buf_state.rx_frame_count = 1, "Single Error frame in RX Buffer!");

        ctu_read_frame(err_frame, DUT_NODE, chn);
        check_m(err_frame.erf = '1', "FRAME_FORMAT_W[ERF] = 1");
        check_m(err_frame.ivld = '1', "FRAME_FORMAT_W[IVLD] = 1");
        check_m(err_frame.erf_pos = ERC_POS_ACK, "FRAME_FORMAT_W[ERF_POS] = ERC_POS_ACK");
        check_m(err_frame.erf_type = ERC_ACK_ERR, "FRAME_FORMAT_W[ERF_TYPE] = ERC_ACK_ERR");

        ctu_wait_bus_idle(DUT_NODE, chn);

    end procedure;

end package body;
