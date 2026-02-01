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
--  Bus monitoring mode - feature test.
--
-- @Verifies:
--  @1. No frame is transmitted during Bus monitoring mode.
--  @2. No dominant bit is transmitted in Bus monitoring mode. ACK and Error
--      frames are re-reouted internally and bus remains unchanged!
--  @3. A frame can be sucesfully received when other nodes are sending frames
--      between each other and such frames are being ACKed between the nodes.
--
-- @Test sequence:
--  @1. Configure Bus monitoring mode in DUT. Set Self test mode in Test node.
--  @2. Insert frame for transmission to DUT. Check for sufficiently long
--      that it will NOT be transmitted (TXT Buffer goes to failed and no
--      transmission is started).
--  @3. Send CAN frame by Test node. Wait till ACK field.
--  @4. Monitor bus during whole ACK field, check that it is recessive. Wait
--      till bus is idle.
--  @5. Check that frame was received by DUT.
--  @6. Set DUT to NON-ISO FD. Send CAN FD frame by Test node.
--  @7. Wait till error frame transmitted by DUT (should come as CRC is now
--      different).
--  @8. Monitor during whole Error frame transmitted by DUT, that recessive
--      value is sent on the bus by DUT! Wait until bus is idle. Check
--      afterwards that frame was sent OK by Test node.
--  @9. Read value of RX Frame counter by DUT. Set Test Node to Self-acknowledge
--      mode. This will emulate other nodes sending and ACKing frames with only
--      Test Node being available.
-- @10. Generate random frame, and send it by Test Node. Wait until the frame
--      is sent by the Test Node.
-- @11. Read the frame from DUT Node, and check that the frame received matches
--      the transmitted frame. Read the RX Error counter and check it did not
--      increment.
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
use ctu_can_fd_tb.mem_bus_agent_pkg.all;


package mode_bus_monitoring_ftest is
    procedure mode_bus_monitoring_ftest_exec(
        signal      chn             : inout  t_com_channel
    );
end package;


package body mode_bus_monitoring_ftest is
    procedure mode_bus_monitoring_ftest_exec(
        signal      chn             : inout  t_com_channel
    ) is
        variable can_tx_frame       :       t_ctu_frame;
        variable can_rx_frame       :       t_ctu_frame;
        variable frame_sent         :       boolean := false;

        variable err_counters_1     :       t_ctu_err_ctrs;
        variable err_counters_2     :       t_ctu_err_ctrs;

        variable mode_1             :       t_ctu_mode := t_ctu_mode_rst_val;
        variable mode_2             :       t_ctu_mode := t_ctu_mode_rst_val;
        variable txt_buf_state      :       t_ctu_txt_buff_state;
        variable rx_buf_state       :       t_ctu_rx_buf_state;
        variable status             :       t_ctu_status;
        variable frames_equal       :       boolean := false;
        variable ff             :       t_ctu_frame_field;
    begin

        ------------------------------------------------------------------------
        -- @1. Configure Bus monitoring mode in DUT. Set Self test mode in Test
        --     node.
        ------------------------------------------------------------------------
        info_m("Step 1: Configuring BMM in DUT, STM in Test node!");

        mode_1.bus_monitoring := true;
        ctu_set_mode(mode_1, DUT_NODE, chn);
        mode_2.self_test := true;
        ctu_set_mode(mode_2, TEST_NODE, chn);

        ------------------------------------------------------------------------
        -- @2. Insert frame for transmission to DUT. Check for sufficiently
        --     long that it will NOT be transmitted (TXT Buffer remains Ready).
        ------------------------------------------------------------------------
        info_m("Step 2: Checking frame is not transmitted in Bus monitoring mode!");

        generate_can_frame(can_tx_frame);
        ctu_send_frame(can_tx_frame, 1, DUT_NODE, chn, frame_sent);

        wait for 20 ns;

        for i in 0 to 100 loop
            ctu_get_txt_buf_state(1, txt_buf_state, DUT_NODE, chn);
            check_m(txt_buf_state = buf_failed, "TXT buffer went to failed");
            ctu_get_status(status, DUT_NODE, chn);
            check_false_m(status.transmitter, "Node does not transmitt in BMM!");
            check_false_m(status.receiver, "Node turned receiver in BMM -> WTF?");
            check_m(status.bus_status, "Node remains idle");
            wait for 50 ns; -- To make checks more sparse
        end loop;

        ------------------------------------------------------------------------
        -- @3. Send CAN frame by Test node. Wait till ACK field of DUT.
        ------------------------------------------------------------------------
        info_m("Step 3: Send frame by Test node, Wait till ACK");

        generate_can_frame(can_tx_frame);
        ctu_send_frame(can_tx_frame, 1, TEST_NODE, chn, frame_sent);
        ctu_wait_ff(ff_ack, DUT_NODE, chn);

        ------------------------------------------------------------------------
        -- @4. Monitor bus during whole ACK field, check that it is recessive.
        --     Wait till bus is idle.
        ------------------------------------------------------------------------
        info_m("Step 4: Checking ACK field is recessive");

        ctu_get_curr_ff(ff, DUT_NODE, chn);
        while (ff = ff_ack) loop
            check_bus_level(RECESSIVE, "Dominant ACK transmitted!", chn);
            ctu_get_curr_ff(ff, DUT_NODE, chn);

            ctu_get_status(status, DUT_NODE, chn);
            check_m(status.receiver, "DUT receiver!");

        end loop;
        ctu_wait_bus_idle(TEST_NODE, chn);
        ctu_wait_bus_idle(DUT_NODE, chn);

        ------------------------------------------------------------------------
        -- @5. Check that frame was received by DUT.
        ------------------------------------------------------------------------
        info_m("Step 5: Checking frame received OK");

        ctu_get_rx_buf_state(rx_buf_state, DUT_NODE, chn);
        check_m(rx_buf_state.rx_frame_count = 1, "Frame received in BMM");

        ctu_read_frame(can_rx_frame, DUT_NODE, chn);
        compare_can_frames(can_rx_frame, can_tx_frame, false, frames_equal);
        check_m(frames_equal, "TX vs. RX frame matching!");

        ------------------------------------------------------------------------
        -- @6. Set DUT to NON-ISO FD. Send CAN FD frame by Test node.
        ------------------------------------------------------------------------
        info_m("Step 6: Set NISOFD for DUT. Send frame by Test node");

        mode_1.iso_fd_support := false;
        ctu_set_mode(mode_1, DUT_NODE, chn);

        generate_can_frame(can_tx_frame);
        can_tx_frame.frame_format := FD_CAN;
        can_tx_frame.rtr := NO_RTR_FRAME;

        ctu_send_frame(can_tx_frame, 1, TEST_NODE, chn, frame_sent);

        ------------------------------------------------------------------------
        -- @7. Wait till error frame transmitted by DUT (should come as CRC is
        --     now different).
        ------------------------------------------------------------------------
        info_m("Step 7: Waiting till error frame");

        ctu_wait_err_frame(DUT_NODE, chn);

        ------------------------------------------------------------------------
        -- @8. Monitor during whole Error frame transmitted by DUT, that
        --     recessive value is sent on the bus by DUT! Wait until bus is
        --     idle. Check afterwards that frame was sent OK by Test node.
        ------------------------------------------------------------------------
        info_m("Step 8: Monitor that error flag sent by DUT is recessive");

        ctu_get_status(status, DUT_NODE, chn);
        check_m(status.error_transmission, "Error frame transmitted!");

        mem_bus_agent_disable_transaction_reporting(chn);
        while (status.error_transmission) loop
            check_can_tx(RECESSIVE, DUT_NODE, "Dominant Error flag transmitted!", chn);
            ctu_get_status(status, DUT_NODE, chn);
        end loop;
        mem_bus_agent_enable_transaction_reporting(chn);

        ctu_wait_bus_idle(TEST_NODE, chn);
        ctu_wait_bus_idle(DUT_NODE, chn);
        ctu_get_txt_buf_state(1, txt_buf_state, TEST_NODE, chn);
        check_m(txt_buf_state = buf_done, "Frame transmitted OK");

        -- Need to turn back on the ISO-FD and reset the DUT Node. This is because
        -- CRC Init vector for CRC-17 and CRC-21 should initialize to 1 in MSB.
        -- This happends upon first bit of intermission, therefore during last
        -- frame the init vector initializes to 0. This then causes CRC Errors
        -- in follow-up frames.
        -- In real operation this is OK, since NISOFD is set once during initial
        -- configuration!
        mode_1.iso_fd_support := true;
        ctu_set_mode(mode_1, DUT_NODE, chn);

        ctu_turn(false, DUT_NODE, chn);
        ctu_turn(true, DUT_NODE, chn);
        ctu_wait_err_active(DUT_NODE, chn);

        -----------------------------------------------------------------------
        --  @9. Read value of RX Frame counter by DUT. Set Test Node to
        --      Self-acknowledge mode. This will emulate other nodes sending
        --      and ACKing frames with only Test Node being available.
        -----------------------------------------------------------------------
        info_m("Step 9: Set Test Node to Self-acknowledge mode");

        ctu_get_err_ctrs(err_counters_1, DUT_NODE, chn);

        mode_2.self_acknowledge := true;
        mode_2.self_test := false;
        ctu_set_mode(mode_2, TEST_NODE, chn);

        -----------------------------------------------------------------------
        -- @10. Generate random frame, and send it by Test Node. Wait until the
        --      frame is sent by the Test Node.
        -----------------------------------------------------------------------
        info_m("Step 10: Generate random frame and send by Test Node");

        generate_can_frame(can_tx_frame);
        ctu_send_frame(can_tx_frame, 1, TEST_NODE, chn, frame_sent);
        ctu_wait_frame_sent(TEST_NODE, chn);

        -----------------------------------------------------------------------
        -- @11. Read the frame from DUT Node, and check that the frame received
        --      matches the transmitted frame. Read the RX Error counter and
        --      check it did not increment.
        -----------------------------------------------------------------------
        info_m("Step 11: Read the frame from DUT and compare");

        ctu_read_frame(can_rx_frame, DUT_NODE, chn);
        compare_can_frames(can_rx_frame, can_tx_frame, false, frames_equal);
        check_m(frames_equal, "TX vs. RX frame matching!");

        ctu_get_err_ctrs(err_counters_2, DUT_NODE, chn);
        check_m(err_counters_1.rx_counter = err_counters_2.rx_counter,
                "RX Error counter not incremented");

  end procedure;

end package body;