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
--  FRAME_TEST_W[SDLC] feature test
--
-- @Verifies:
--  @1. When MODE[TSTM] = 1, FRAME_TEST_W[SDLC] swaps value of transmitted DLC
--      with value defined in FRAME_TEST_W[SDLC].
--
-- @Test sequence:
--  @1. Set Test mode in DUT. Iterate through all TXT Buffers
--      @1.2. Generate random CAN FD frame. Transmit it by DUT.
--      @1.3. Send again the same frame as in previous point, only swap DLC,
--            again record the DLC. Check that transmitted DLC has been swapped.
--      @1.4. Wait until bus is idle.
--
-- @TestInfoEnd
--------------------------------------------------------------------------------
-- Revision History:
--    12.07.2021   Created file
--------------------------------------------------------------------------------

Library ctu_can_fd_tb;
context ctu_can_fd_tb.ieee_context;
context ctu_can_fd_tb.rtl_context;
context ctu_can_fd_tb.tb_common_context;

use ctu_can_fd_tb.feature_test_agent_pkg.all;

package frame_test_sdlc_ftest is
    procedure frame_test_sdlc_ftest_exec(
        signal      chn             : inout  t_com_channel
    );
end package;


package body frame_test_sdlc_ftest is
    procedure frame_test_sdlc_ftest_exec(
        signal      chn             : inout  t_com_channel
    ) is
        variable can_tx_frame       :       t_ctu_frame;
        variable can_rx_frame       :       t_ctu_frame;
        variable frame_sent         :       boolean := false;
        variable frames_equal       :       boolean := false;
        variable mode_1             :       t_ctu_mode := t_ctu_mode_rst_val;

        variable err_counters       :       t_ctu_err_ctrs := (0, 0, 0, 0);
        variable err_counters_2     :       t_ctu_err_ctrs := (0, 0, 0, 0);

        variable fault_th           :       t_ctu_fault_thresholds;
        variable fault_th_2         :       t_ctu_fault_thresholds;

        variable txt_buf_count      :       natural;
        variable tmp_int            :       natural;

        variable status_1           :       t_ctu_status;

        variable txt_buf_vector     :       std_logic_vector(7 downto 0) := x"00";
        variable txt_buf_state      :       t_ctu_txt_buff_state;

        variable swap_dlc           :       natural;
        variable expected_dlc       :       std_logic_vector(3 downto 0) := "0000";
        variable real_dlc           :       std_logic_vector(3 downto 0) := "0000";

        variable err_capt           :       t_ctu_err_capt;
    begin

        -----------------------------------------------------------------------
        -- @1. Set Test mode in DUT. Iterate through all TXT Buffers
        -----------------------------------------------------------------------
        info_m("Step 1");

        mode_1.test := true;
        -- Self test mode is needed so that DUT will not send Error frame after
        -- not getting ACK due to flipped bit. This-way we can check that test-node
        -- has detected CRC error!
        mode_1.self_test := true;
        ctu_set_mode(mode_1, DUT_NODE, chn);

        ctu_get_txt_buf_cnt(txt_buf_count, DUT_NODE, chn);

        for txt_buf_index in 1 to txt_buf_count loop

            info_m("Running the test from TXT Buffer: " & integer'image(txt_buf_index));

            -----------------------------------------------------------------------
            -- @1.2. Generate random CAN FD frame. Transmit it by DUT.
            -----------------------------------------------------------------------
            info_m("Step 1.2");

            generate_can_frame(can_tx_frame);
            can_tx_frame.frame_format := NORMAL_CAN;
            can_tx_frame.ident_type := BASE;
            can_tx_frame.identifier := can_tx_frame.identifier mod 2**11;
            info_m("Transmitted frame:");
            print_can_frame(can_tx_frame);

            ctu_put_tx_frame(can_tx_frame, txt_buf_index, DUT_NODE, chn);

            ctu_set_tx_frame_test(txt_buf_index, 0, false, false, false,
                                  DUT_NODE, chn);

            ctu_give_txt_cmd(buf_set_ready, txt_buf_index, DUT_NODE, chn);

            ctu_wait_ff(ff_control, DUT_NODE, chn);

            ctu_wait_bus_idle(DUT_NODE, chn);

            -----------------------------------------------------------------------
            -- @1.3. Send again the same frame as in previous point, only swap DLC,
            --       again record the DLC. Check that it is equal to swapped value.
            -----------------------------------------------------------------------
            info_m("Step 1.3");

            ctu_put_tx_frame(can_tx_frame, txt_buf_index, DUT_NODE, chn);

            rand_int_v(15, swap_dlc);
            ctu_set_tx_frame_test(txt_buf_index, swap_dlc, false, false, true,
                                  DUT_NODE, chn);

            ctu_give_txt_cmd(buf_set_ready, txt_buf_index, DUT_NODE, chn);

            -- We transnmit fixed frame format so that we move exactly to DLC!
            ctu_wait_ff(ff_control, DUT_NODE, chn);
            wait for 30 ns;
            -- Skip IDE and R0
            ctu_wait_sample_point(DUT_NODE, chn);
            ctu_wait_sample_point(DUT_NODE, chn);

            for i in 0 to 3 loop
                ctu_wait_sample_point(DUT_NODE, chn);
                get_can_tx(DUT_NODE, real_dlc(3 - i), chn);
            end loop;

            wait for 50 ns;
            expected_dlc := std_logic_vector(to_unsigned(swap_dlc, 4));
            info_m("Original DLC: " & to_string(can_tx_frame.dlc));
            info_m("Expected DLC: " & to_string(expected_dlc));
            info_m("Real DLC:     " & to_string(real_dlc));
            check_m(expected_dlc = real_dlc, "Expected DLC = Real DLC");

            -----------------------------------------------------------------------
            -- @1.4. Wait until bus is idle
            -----------------------------------------------------------------------
            info_m("Step 1.4");

            -- Note: If we swap DLC with equal value as the original one, we will
            --       never reach error frame! Therefore we don't wait for it, it
            --       is enough to check that DUT has transmitted swapped value of
            --       DLC!
            ctu_wait_bus_idle(DUT_NODE, chn);
            ctu_wait_bus_idle(TEST_NODE, chn);

        end loop;

  end procedure;

end package body;