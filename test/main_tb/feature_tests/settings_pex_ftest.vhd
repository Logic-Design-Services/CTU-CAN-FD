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
--  SETTINGS[PEX] feature test
--
-- @Verifies:
--  @1. When SETTINGS[PEX]=1 and MODE[FDE]=1, CTU CAN FD can transmit a CAN
--      FD frame.
--  @2. When SETTINGS[PEX]=1 and MODE[FDE]=1, CTU CAN FD enters to bus
--      integrating state upon sampling recessive r0/res bit.
--  @2. When SETTINGS[PEX]=0 and MODE[FDE]=1, CTU CAN FD detects error upon
--      sampling recessive r0/res bit.
--
-- @Test sequence:
--  @1. Iterate across all combinations of SETTINGS[PEX] and MODE[FDE]:
--      @1.1 If MODE[FDE] = 1 generate CAN FD frame, otherwise generate CAN
--           2.0 frame.
--      @1.2 Send the frame by DUT and receive by Test Node. Read out from
--           Test Node and check the received frame matches the transmitted
--           frame.
--      @1.3 Send the frame by Test Node and receive by DUT. Read out from
--           DUT and compare the received frame with the transmitted frame.
--      @1.4 Send the same frame by Test Node, and force on DUTs CAN RX:
--              - When MODE[FDE] = 0, and Base ID, flip r0 (after IDE)
--              - When MODE[FDE] = 1, and Base ID, flip r0 (after EDL)
--      @1.5 Check that when SETTINGS[PEX] = 1, the node entered bus integration
--           state, and when SETTINGS[PEX] = 0, the node is transmitting error
--           frame. Wait until bus is idle in both nodes.
--
-- @TestInfoEnd
--------------------------------------------------------------------------------
-- Revision History:
--    28.12.2025   Created file
--------------------------------------------------------------------------------

Library ctu_can_fd_tb;
context ctu_can_fd_tb.ieee_context;
context ctu_can_fd_tb.rtl_context;
context ctu_can_fd_tb.tb_common_context;

use ctu_can_fd_tb.feature_test_agent_pkg.all;
use ctu_can_fd_tb.mem_bus_agent_pkg.all;

package settings_pex_ftest is
    procedure settings_pex_ftest_exec(
        signal      chn             : inout  t_com_channel
    );
end package;


package body settings_pex_ftest is
    procedure settings_pex_ftest_exec(
        signal      chn             : inout  t_com_channel
    ) is
        variable can_tx_frame       :       t_ctu_frame;
        variable can_rx_frame       :       t_ctu_frame;

        variable frame_sent         :       boolean := false;
        variable frames_equal       :       boolean := false;

        variable mode_1             :       t_ctu_mode := t_ctu_mode_rst_val;
        variable status             :       t_ctu_status;
        variable command            :       t_ctu_command := t_ctu_command_rst_val;

    begin

        -------------------------------------------------------------------------------------------
        --  @1. Iterate across all combinations of SETTINGS[PEX] and MODE[FDE]:
        -------------------------------------------------------------------------------------------
        info_m("Step 1");

        for settings_pex in boolean'left to boolean'right loop
        for mode_fde in boolean'left to boolean'right loop

            info_m("SETTINGS[PEX]= " & boolean'image(settings_pex));
            info_m("MODE[FDE]= " & boolean'image(mode_fde));

            mode_1.pex_support := settings_pex;
            mode_1.flexible_data_rate := mode_fde;

            ctu_set_mode(mode_1, DUT_NODE, chn);

            ctu_set_retr_limit(true, 0, DUT_NODE, chn);

            ---------------------------------------------------------------------------------------
            -- @1.1 If MODE[FDE] = 1 generate CAN FD frame, otherwise generate CAN
            --      2.0 frame.
            ---------------------------------------------------------------------------------------
            info_m("Step 1.1");

            generate_can_frame(can_tx_frame);

            can_tx_frame.ident_type := BASE;
            can_tx_frame.identifier := can_tx_frame.identifier mod 2 ** 11;

            if (mode_fde) then
                can_tx_frame.frame_format := FD_CAN;
            else
                can_tx_frame.frame_format := NORMAL_CAN;
                can_tx_frame.data_length := can_tx_frame.data_length mod 8;
                length_to_dlc(can_tx_frame.data_length, can_tx_frame.dlc);
                dlc_to_rwcnt(can_tx_frame.dlc, can_tx_frame.rwcnt);
            end if;

            ---------------------------------------------------------------------------------------
            -- @1.2 Send the frame by DUT and receive by Test Node. Read out from
            --      Test Node and check the received frame matches the transmitted
            --      frame.
            ---------------------------------------------------------------------------------------
            info_m("Step 1.2");

            ctu_send_frame(can_tx_frame, 1, DUT_NODE, chn, frame_sent);
            ctu_wait_frame_sent(DUT_NODE, chn);

            ctu_wait_bus_idle(DUT_NODE, chn);
            ctu_wait_bus_idle(TEST_NODE, chn);

            ctu_read_frame(can_rx_frame, TEST_NODE, chn);
            compare_can_frames(can_rx_frame, can_tx_frame, false, frames_equal);

            check_m(frames_equal, "TX Frame = RX Frame");

            ---------------------------------------------------------------------------------------
            -- @1.3 Send the frame by Test Node and receive by DUT. Read out from
            --      DUT and compare the received frame with the transmitted frame.
            ---------------------------------------------------------------------------------------
            info_m("Step 1.3");

            ctu_send_frame(can_tx_frame, 1, TEST_NODE, chn, frame_sent);
            ctu_wait_frame_sent(TEST_NODE, chn);

            ctu_wait_bus_idle(DUT_NODE, chn);
            ctu_wait_bus_idle(TEST_NODE, chn);

            ctu_read_frame(can_rx_frame, DUT_NODE, chn);
            compare_can_frames(can_rx_frame, can_tx_frame, false, frames_equal);

            check_m(frames_equal, "TX Frame = RX Frame");

            ---------------------------------------------------------------------------------------
            -- @1.4 Send the same frame by Test Node, and force on DUTs CAN RX:
            --       - When MODE[FDE] = 0, and Base ID, flip r0 (after IDE)
            --       - When MODE[FDE] = 1, and Base ID, flip r0 (after EDL)
            ---------------------------------------------------------------------------------------
            info_m("Step 1.4");

            ctu_send_frame(can_tx_frame, 1, TEST_NODE, chn, frame_sent);
            ctu_wait_frame_start(false, true, DUT_NODE, chn);

            if (mode_fde) then
                -- BASE ID (11) + RTR (1) + IDE (1) + EDL (1)
                for i in 1 to 14 loop
                    ctu_wait_sample_point(DUT_NODE, chn);
                end loop;
            else
                -- BASE ID (11) + RTR (1) + IDE (1)
                for i in 1 to 13 loop
                    ctu_wait_sample_point(DUT_NODE, chn);
                end loop;
            end if;

            ctu_wait_sync_seg(DUT_NODE, chn);

            force_can_rx(RECESSIVE, DUT_NODE, chn);
            ctu_wait_sample_point(DUT_NODE, chn);
            ctu_wait_input_delay(chn);
            release_can_rx(chn);

            ---------------------------------------------------------------------------------------
            -- @1.5 Check that when SETTINGS[PEX] = 1, the node entered bus integration
            --      state, and when SETTINGS[PEX] = 0, the node is transmitting error
            --      frame. Wait until bus is idle in both nodes.
            ---------------------------------------------------------------------------------------
            info_m("Step 1.5");

            ctu_wait_sync_seg(DUT_NODE, chn);
            ctu_get_status(status, DUT_NODE, chn);

            if (settings_pex) then
                check_false_m(status.error_transmission, "Error frame is NOT being transmitted!");
                check_m(status.protocol_exception, "Protocol exception is set");
            else
                check_m(status.error_transmission, "Error frame is being transmitted!");
                check_false_m(status.protocol_exception, "Protocol exception is NOT set");
                command.clear_pexs_flag := true;
                ctu_give_cmd(command, DUT_NODE, chn);
            end if;

            ctu_wait_bus_idle(DUT_NODE, chn);
            ctu_wait_bus_idle(TEST_NODE, chn);

        end loop;
        end loop;

  end procedure;

end package body;