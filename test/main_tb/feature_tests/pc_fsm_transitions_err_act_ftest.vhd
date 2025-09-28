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
--  Corner-case PC FSM transitions
--
-- @Verifies:
--  @1. Corner-case transitions of Protocol Control FSM to Active Error Flag.
--
-- @Test sequence:
--  @1. Set DUT to test mode (to be able to modify REC and TEC)
--  @2. Loop through all combinations of frames:
--          CAN 2.0 Base, CAN 2.0 Extended, CAN FD Based, CAN FD Extended.
--      @2.1. Loop through all bits of a frame:
--          @2.1.1 Set DUT node to Error Active.
--          @2.2.1 Send a Frame by DUT node. Wait for incrementing number of bits
--          @2.3.1 Flip a bit on DUT CAN RX.
--          @2.4.1 Check that DUT is either transmitting an error frame, or it has
--                 lost arbitration.
--          @2.5.1 Wait until bus is idle.
--
-- @TestInfoEnd
--------------------------------------------------------------------------------
-- Revision History:
--    14.12.2023   Created file
--------------------------------------------------------------------------------

Library ctu_can_fd_tb;
context ctu_can_fd_tb.ieee_context;
context ctu_can_fd_tb.rtl_context;
context ctu_can_fd_tb.tb_common_context;

use ctu_can_fd_tb.feature_test_agent_pkg.all;

package pc_fsm_transitions_err_act_ftest is
    procedure pc_fsm_transitions_err_act_ftest_exec(
        signal      chn             : inout  t_com_channel
    );
end package;


package body pc_fsm_transitions_err_act_ftest is

    procedure pc_fsm_transitions_err_act_ftest_exec(
        signal      chn             : inout  t_com_channel
    ) is
        variable r_data             :       std_logic_vector(31 downto 0) := (OTHERS => '0');
        variable can_tx_frame       :       t_ctu_frame;
        variable tx_val             :       std_logic;
        variable err_counters       :       t_ctu_err_ctrs;
        variable status             :       t_ctu_status;
        variable mode               :       t_ctu_mode := t_ctu_mode_rst_val;
        variable frame_bits         :       integer;
        variable bit_index          :       integer;
        variable ff             :       t_ctu_frame_field;
    begin

        -------------------------------------------------------------------------------------------
        -- @1. Set DUT to test mode (to be able to modify REC and TEC)
        -------------------------------------------------------------------------------------------
        info_m("Step 1: Set DUT to test mode");
        mode.test := true;
        ctu_set_mode(mode, DUT_NODE, chn);

        -------------------------------------------------------------------------------------------
        -- @2. Loop through all combinations of frames:
        --     CAN 2.0 Base, CAN 2.0 Extended, CAN FD Based, CAN FD Extended.
        -------------------------------------------------------------------------------------------
        info_m("Step 1: Loop through all combinations of frames:");
        info_m("        CAN 2.0 Base, CAN 2.0 Extended, CAN FD Based, CAN FD Extended.");

        for frame_format in NORMAL_CAN to FD_CAN loop
        for ident_type in BASE to EXTENDED loop

            generate_can_frame(can_tx_frame);
            can_tx_frame.identifier := 0;
            can_tx_frame.frame_format := frame_format;
            can_tx_frame.ident_type := ident_type;
            can_tx_frame.data_length := 1;
            can_tx_frame.rtr := NO_RTR_FRAME;
            can_tx_frame.brs := BR_NO_SHIFT;

            bit_index := 0;
            bit_iter_loop: loop

                -----------------------------------------------------------------------
                -- @2.1.1  Set DUT node to Error Active.
                -----------------------------------------------------------------------
                info_m("Step 2.1.1: Set DUT node to Error Active.");

                err_counters.rx_counter := 0;
                ctu_set_err_ctrs(err_counters, DUT_NODE, chn);

                -----------------------------------------------------------------------
                -- @2.1.2 Send a Frame by DUT node. Wait for incrementing number of bits
                -----------------------------------------------------------------------
                info_m("Step 2.1.2: Send a Frame by DUT node. Wait for incrementing number of bits");

                info_m("Identifier type: " & std_logic'image(frame_format));
                info_m("Frame format: " & std_logic'image(ident_type));

                ctu_put_tx_frame(can_tx_frame, 1, DUT_NODE, chn);
                ctu_give_txt_cmd(buf_set_ready, 1, DUT_NODE, chn);

                ctu_wait_frame_start(true, false, DUT_NODE, chn);

                info_m("Waiting for " & integer'image(bit_index) & " bits!");
                for j in 0 to bit_index loop
                    ctu_wait_sync_seg(DUT_NODE, chn);
                end loop;

                wait for 20 ns;

                -- If we get up to ACK, we finish, flipping ACK will not result in
                -- immediate Error frame!
                ctu_get_curr_ff(ff, DUT_NODE, chn);
                if (ff = ff_ack) then
                    ctu_wait_bus_idle(DUT_NODE, chn);
                    ctu_wait_bus_idle(TEST_NODE, chn);
                    exit bit_iter_loop;
                end if;

                -----------------------------------------------------------------------
                -- @2.1.3 Flip a bit on DUT CAN RX.
                -----------------------------------------------------------------------
                info_m("Step 2.1.3 Flip a bit on DUT CAN RX.");

                flip_bus_level(chn);
                ctu_wait_sync_seg(DUT_NODE, chn);
                release_bus_level(chn);

                ctu_wait_sync_seg(DUT_NODE, chn);

                -----------------------------------------------------------------------
                -- @2.1.4 Check that DUT is either transmitting an error frame, or it
                --        has lost arbitration.
                -----------------------------------------------------------------------
                info_m("Step 2.1.4 Check error frame or arbitration lost");

                ctu_get_status(status, DUT_NODE, chn);

                check_m(status.receiver or status.error_transmission,
                        "DUT either lost arbitration or is transmitting error frame");

                -----------------------------------------------------------------------
                -- @2.1.5 Wait until bus is idle.
                -----------------------------------------------------------------------
                info_m("Step 2.1.5 Wait until bus is idle.");

                ctu_wait_bus_idle(DUT_NODE, chn);

                bit_index := bit_index + 1;

            end loop;

        end loop;
        end loop;

  end procedure;

end package body;
