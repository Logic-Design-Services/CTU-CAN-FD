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
--  RX Error logging feature test 4
--
-- @Verifies:
--  @1. When Error occurs in Base Identifier, logged Error Frame has
--      FRAME_FORMAT_W[IVLD] = 0.
--  @2. When Error occurs in the first bit after Base Identifier, logged
--      Error frame has FRAME_FORMAT_W[IVLD] = 0.
--  @3. When Error occurs in the bit after IDE bit, and IDE bit was Dominat,
--      FRAME_FORMAT_W[IVLD] = 1.
--  @4. When Error occurs in the Extended Identifier, logged Error frame has
--      FRAME_FORMAT_W[IVLD] = 0.
--  @5. When Error occurs in the bit after Extended identifier, the logged
--      Error frame has FRAME_FORMAT_W[IVLD] = 1.
--
-- @Test sequence:
--  @1. Configure DUT to MODE[ERFM] = 1. Set 0 retransmit limitations!
--  @2. Generate CAN frame and send it by DUT Node. Wait until Base ID and
--      flip a dominant bit in the Base identifier. Check that RX Buffer has
--      a single frame in it. Read the frame and check it is an Error frame
--      with FRAME_FORMAT_W[IVLD] = 0. Wait until bus is idle.
--  @3. Generate CAN FD frame with Base ID only. Send the frame by DUT Node,
--      and wait until RTR bit. Flip the RTR bit, and check DUT Node has
--      1 Error frame in its RX Buffer. Read the Error frame, and check it
--      has FRAME_FORMAT_W[IVLD] = 0.
--  @4. Generate CAN frame with Base identifier only. Send it by DUT Node
--      and wait until IDE bit. Wait for one more bit, and flip bus value.
--      Check there is a single frame in RX Buffer. Read the frame and check
--      it is an Error frame and it has FRAME_FORMAT_W[IVLD] = 1.
--  @5. Generate CAN frame with Extended Identifier and send it by DUT Node.
--      Wait until a Dominant bit in the Extended identifier and flip its value.
--      Check that DUT has single frame in RX Buffer. Read the frame and check
--      it is an Error frame with FRAME_FORMAT_W[IVLD] = 0.
--  @6. Generate CAN frame with Extended identifier and send it by DUT Node.
--      Wait until a first bit after the Extended Identifier, and flip its
--      value. Check that DUT Nodes RX Buffer contains a single Error frame.
--      Read the frame, and check it is an error frame. Check its
--      FRAME_FORMAT_W[IVLD] = 1.
--
-- @TestInfoEnd
--------------------------------------------------------------------------------
-- Revision History:
--    15.8.2024   Created file
--------------------------------------------------------------------------------

Library ctu_can_fd_tb;
context ctu_can_fd_tb.ieee_context;
context ctu_can_fd_tb.rtl_context;
context ctu_can_fd_tb.tb_common_context;

use ctu_can_fd_tb.feature_test_agent_pkg.all;

package rx_err_log_4_ftest is
    procedure rx_err_log_4_ftest_exec(
        signal      chn             : inout  t_com_channel
    );
end package;


package body rx_err_log_4_ftest is

    procedure rx_err_log_4_ftest_exec(
        signal      chn             : inout  t_com_channel
    ) is
        variable can_frame          : t_ctu_frame;
        variable err_frame          : t_ctu_frame;
        variable frame_sent         : boolean;

        variable can_tx             : std_logic;

        variable mode_1             : t_ctu_mode := t_ctu_mode_rst_val;
        variable status             : t_ctu_status;

        variable rx_buf_state        : t_ctu_rx_buf_state;
    begin

        -------------------------------------------------------------------------------------------
        -- @1. Configure DUT to MODE[ERFM] = 1.
        -------------------------------------------------------------------------------------------
        info_m("Step 1");

        mode_1.error_logging := true;
        ctu_set_mode(mode_1, DUT_NODE, chn);

        ctu_set_retr_limit(true, 0, DUT_NODE, chn);

        -------------------------------------------------------------------------------------------
        -- @2. Generate CAN frame and send it by DUT Node. Wait until Base ID and
        --     flip a dominant bit in the Base identifier. Check that RX Buffer has
        --     a single frame in it. Read the frame and check it is an Error frame
        --     with FRAME_FORMAT_W[IVLD] = 0. Wait until bus is idle.
        -------------------------------------------------------------------------------------------
        info_m("Step 2");

        generate_can_frame(can_frame);
        ctu_send_frame(can_frame, 1, DUT_NODE, chn, frame_sent);
        ctu_wait_frame_start(true, false, DUT_NODE, chn);

        ctu_wait_sample_point(DUT_NODE, chn);

        while (true) loop
            ctu_wait_sync_seg(DUT_NODE, chn);
            wait for 20 ns;
            get_can_tx(DUT_NODe, can_tx, chn);
            if (can_tx = DOMINANT) then
                exit;
            end if;
        end loop;

        flip_bus_level(chn);
        ctu_wait_sample_point(DUT_NODE, chn, false);
        wait for 20 ns;
        release_bus_level(chn);

        wait for 100 ns;

        ctu_get_status(status, DUT_NODE, chn);
        check_m(status.error_transmission, "Error frame is being transmitted!");

        ctu_get_rx_buf_state(rx_buf_state, DUT_NODE, chn);
        check_m(rx_buf_state.rx_frame_count = 1, "Single Error frame in RX Buffer!");

        ctu_read_frame(err_frame, DUT_NODE, chn);
        check_m(err_frame.erf = '1', "FRAME_FORMAT_W[ERF] = 1");
        check_m(err_frame.ivld = '0', "FRAME_FORMAT_W[IVLD] = 0");

        ctu_get_rx_buf_state(rx_buf_state, DUT_NODE, chn);
        check_m(rx_buf_state.rx_frame_count = 0, "No Error frame in RX Buffer!");

        ctu_wait_bus_idle(DUT_NODE, chn);
        ctu_wait_bus_idle(TEST_NODE, chn);

        -------------------------------------------------------------------------------------------
        -- @3. Generate CAN FD frame with Base ID only. Send the frame by DUT Node,
        --     and wait until RTR bit. Flip the RTR bit, and check DUT Node has
        --     1 Error frame in its RX Buffer. Read the Error frame, and check it
        --     has FRAME_FORMAT_W[IVLD] = 0.
        -------------------------------------------------------------------------------------------
        info_m("Step 3");

        generate_can_frame(can_frame);
        can_frame.frame_format := NORMAL_CAN;
        can_frame.ident_type := BASE;
        can_frame.identifier := can_frame.identifier mod 2 ** 11;
        can_frame.rtr := NO_RTR_FRAME;

        ctu_send_frame(can_frame, 1, DUT_NODE, chn, frame_sent);
        ctu_wait_frame_start(true, false, DUT_NODE, chn);

        -- SOF + 11 Bits of Base ID
        for i in 1 to 12 loop
            ctu_wait_sample_point(DUT_NODE, chn);
        end loop;

        wait for 20 ns;

        flip_bus_level(chn);
        ctu_wait_sample_point(DUT_NODE, chn, false);
        wait for 20 ns;
        release_bus_level(chn);

        wait for 100 ns;

        ctu_get_status(status, DUT_NODE, chn);
        check_m(status.error_transmission, "Error frame is being transmitted!");

        ctu_get_rx_buf_state(rx_buf_state, DUT_NODE, chn);
        check_m(rx_buf_state.rx_frame_count = 1, "Single Error frame in RX Buffer!");

        ctu_read_frame(err_frame, DUT_NODE, chn);
        check_m(err_frame.erf = '1', "FRAME_FORMAT_W[ERF] = 1");
        check_m(err_frame.ivld = '0', "FRAME_FORMAT_W[IVLD] = 0");

        ctu_get_rx_buf_state(rx_buf_state, DUT_NODE, chn);
        check_m(rx_buf_state.rx_frame_count = 0, "No Error frame in RX Buffer!");

        ctu_wait_bus_idle(DUT_NODE, chn);
        ctu_wait_bus_idle(TEST_NODE, chn);

        -------------------------------------------------------------------------------------------
        -- @4. Generate CAN frame with Base Identifier only. Send it by DUT Node
        --     and wait until IDE bit. Wait for one more bit, and flip bus value.
        --     Check there is a single frame in RX Buffer. Read the frame and check
        --     it is an Error frame and it has FRAME_FORMAT_W[IVLD] = 1.
        -------------------------------------------------------------------------------------------
        info_m("Step 4");

        generate_can_frame(can_frame);
        can_frame.frame_format := NORMAL_CAN;
        can_frame.ident_type := BASE;
        can_frame.identifier := can_frame.identifier mod 2 ** 11;
        can_frame.rtr := NO_RTR_FRAME;

        ctu_send_frame(can_frame, 1, DUT_NODE, chn, frame_sent);
        ctu_wait_frame_start(true, false, DUT_NODE, chn);

        -- SOF + 11 Bits of Base ID + RTR bit
        for i in 1 to 13 loop
            ctu_wait_sample_point(DUT_NODE, chn);
        end loop;

        -- One more bit (IDE) -> Post-IDE bit will be flipped!
        ctu_wait_sample_point(DUT_NODE, chn);

        wait for 20 ns;

        flip_bus_level(chn);
        ctu_wait_sample_point(DUT_NODE, chn, false);
        wait for 20 ns;
        release_bus_level(chn);

        wait for 100 ns;

        ctu_get_status(status, DUT_NODE, chn);
        check_m(status.error_transmission, "Error frame is being transmitted!");

        ctu_get_rx_buf_state(rx_buf_state, DUT_NODE, chn);
        check_m(rx_buf_state.rx_frame_count = 1, "Single Error frame in RX Buffer!");

        ctu_read_frame(err_frame, DUT_NODE, chn);
        check_m(err_frame.erf = '1', "FRAME_FORMAT_W[ERF] = 1");
        check_m(err_frame.ivld = '1', "FRAME_FORMAT_W[IVLD] = 1");

        ctu_get_rx_buf_state(rx_buf_state, DUT_NODE, chn);
        check_m(rx_buf_state.rx_frame_count = 0, "No Error frame in RX Buffer!");

        ctu_wait_bus_idle(DUT_NODE, chn);
        ctu_wait_bus_idle(TEST_NODE, chn);

        -------------------------------------------------------------------------------------------
        -- @5. Generate CAN frame with Extended Identifier and send it by DUT Node.
        --     Wait until a Dominant bit in the Extended identifier and flip its value.
        --     Check that DUT has single frame in RX Buffer. Read the frame and check
        --     it is an Error frame with FRAME_FORMAT_W[IVLD] = 0.
        -------------------------------------------------------------------------------------------
        info_m("Step 5");

        generate_can_frame(can_frame);
        can_frame.ident_type := EXTENDED;

        ctu_send_frame(can_frame, 1, DUT_NODE, chn, frame_sent);
        ctu_wait_frame_start(true, false, DUT_NODE, chn);

        -- SOF + 11 Bits of Base ID + RTR bit + IDE bit + First bit of Identifier Extension
        for i in 1 to 14 loop
            ctu_wait_sample_point(DUT_NODE, chn);
        end loop;

        while (true) loop
            ctu_wait_sync_seg(DUT_NODE, chn);
            wait for 11 ns;
            get_can_tx(DUT_NODE, can_tx, chn);
            if (can_tx = DOMINANT) then
                exit;
            end if;
        end loop;

        --wait for 20 ns;

        flip_bus_level(chn);
        ctu_wait_sample_point(DUT_NODE, chn, false);
        ctu_wait_input_delay(chn);
        release_bus_level(chn);

        ctu_wait_sample_point(DUT_NODE, chn, false);

        ctu_get_status(status, DUT_NODE, chn);
        check_m(status.error_transmission, "Error frame is being transmitted!");

        ctu_get_rx_buf_state(rx_buf_state, DUT_NODE, chn);
        check_m(rx_buf_state.rx_frame_count = 1, "Single Error frame in RX Buffer!");

        ctu_read_frame(err_frame, DUT_NODE, chn);
        check_m(err_frame.erf = '1', "FRAME_FORMAT_W[ERF] = 1");
        check_m(err_frame.ivld = '0', "FRAME_FORMAT_W[IVLD] = 0");

        ctu_get_rx_buf_state(rx_buf_state, DUT_NODE, chn);
        check_m(rx_buf_state.rx_frame_count = 0, "No Error frame in RX Buffer!");

        ctu_wait_bus_idle(DUT_NODE, chn);
        ctu_wait_bus_idle(TEST_NODE, chn);

        -------------------------------------------------------------------------------------------
        -- @6. Generate CAN frame with Extended identifier and send it by DUT Node.
        --     Wait until a first bit after the Extended Identifier, and flip its
        --     value. Check that DUT Nodes RX Buffer contains a single Error frame.
        --     Read the frame, and check it is an error frame. Check its
        --     FRAME_FORMAT_W[IVLD] = 1.
        -------------------------------------------------------------------------------------------
        info_m("Step 6");

        generate_can_frame(can_frame);
        can_frame.ident_type := EXTENDED;

        ctu_send_frame(can_frame, 1, DUT_NODE, chn, frame_sent);
        ctu_wait_frame_start(true, false, DUT_NODE, chn);

        -- SOF + 11 Bits of Base ID + SRR bit + IDE bit + 18 bits + RTR bit
        for i in 1 to 33 loop
            ctu_wait_sample_point(DUT_NODE, chn);
        end loop;

        wait for 20 ns;

        flip_bus_level(chn);
        ctu_wait_sample_point(DUT_NODE, chn, false);
        wait for 20 ns;
        release_bus_level(chn);

        wait for 100 ns;

        ctu_get_status(status, DUT_NODE, chn);
        check_m(status.error_transmission, "Error frame is being transmitted!");

        ctu_get_rx_buf_state(rx_buf_state, DUT_NODE, chn);
        check_m(rx_buf_state.rx_frame_count = 1, "Single Error frame in RX Buffer!");

        ctu_read_frame(err_frame, DUT_NODE, chn);
        check_m(err_frame.erf = '1', "FRAME_FORMAT_W[ERF] = 1");
        check_m(err_frame.ivld = '1', "FRAME_FORMAT_W[IVLD] = 1");

        ctu_get_rx_buf_state(rx_buf_state, DUT_NODE, chn);
        check_m(rx_buf_state.rx_frame_count = 0, "No Error frame in RX Buffer!");

        ctu_wait_bus_idle(DUT_NODE, chn);

    end procedure;

end package body;
