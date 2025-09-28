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
--  TXT Buffer backup mode 4 feature test.
--
-- @Verifies:
--  @1. When MODE[TBBM] = 1, and parity error occurs during frame transmission
--      from "original" TXT Buffer, "backup" buffer is used for transmission.
--
-- @Test sequence:
--  @1. Set TXT Buffer backup mode and Test mode in DUT.
--  @2. Loop 2 times for each TXT Buffer:
--      @2.1 Generate random priorities of TXT Buffers and apply them in DUT.
--           Generate random index of TXT Buffer which is for sure "original"
--           TXT Buffer and insert random frame to it.
--      @2.2 Enable test access to buffer RAMs. Generate random word index
--           (within data bytesof TXT Buffer), and flip such bit.
--           Disable test access.
--      @2.2 Send Set ready command to selected original TXT Buffer. Wait until
--           DUT starts transmission, and check that original TXT Buffer is in
--           "TX in progress". Wait until error frame is transmitted. Check that
--           "original" TXT Buffer ended in "Parity Error". Wait until "backup"
--           TXT Buffer becomes "TX in progress".
--      @2.3 Wait until transmission ends and bus is idle. Check that "original"
--           TXT Buffer is in "Parity Error" state and "backup" TXT buffer ended in
--           "TX OK" state.
--
-- @TestInfoEnd
--------------------------------------------------------------------------------
-- Revision History:
--    30.06.2022   Created file
--------------------------------------------------------------------------------

Library ctu_can_fd_tb;
context ctu_can_fd_tb.ieee_context;
context ctu_can_fd_tb.rtl_context;
context ctu_can_fd_tb.tb_common_context;

use ctu_can_fd_tb.feature_test_agent_pkg.all;

package mode_txbbm_4_ftest is
    procedure mode_txbbm_4_ftest_exec(
        signal      chn             : inout  t_com_channel
    );
end package;


package body mode_txbbm_4_ftest is
    procedure mode_txbbm_4_ftest_exec(
        signal      chn             : inout  t_com_channel
    ) is
        variable can_tx_frame       :       t_ctu_frame;
        variable can_rx_frame       :       t_ctu_frame;
        variable frame_sent         :       boolean := false;
        variable frames_equal       :       boolean := false;
        variable mode_1             :       t_ctu_mode := t_ctu_mode_rst_val;
        variable mode_2             :       t_ctu_mode := t_ctu_mode_rst_val;

        variable command_1          :     t_ctu_command := t_ctu_command_rst_val;

        variable err_counters       :       t_ctu_err_ctrs := (0, 0, 0, 0);
        variable err_counters_2     :       t_ctu_err_ctrs := (0, 0, 0, 0);

        variable fault_th           :       t_ctu_fault_thresholds;
        variable fault_th_2         :       t_ctu_fault_thresholds;

        variable txt_buf_count      :       natural;
        variable tmp_int            :       natural;
        variable txt_buf_index      :       natural;

        variable txt_buf_vector     :       std_logic_vector(7 downto 0) := x"00";
        variable txt_buf_state      :       t_ctu_txt_buff_state;
        variable tst_mem            :       t_tgt_test_mem;

        variable corrupt_wrd_index  :       natural;
        variable corrupt_bit_index  :       natural;

        variable r_data             :       std_logic_vector(31 downto 0);
        variable status_1           :       t_ctu_status;

        variable rwcnt              :       natural;

    begin

        -----------------------------------------------------------------------
        -- @1. Set TXT Buffer backup mode and Test mode in DUT.
        -----------------------------------------------------------------------
        info_m("Step 1");

        mode_1.tx_buf_backup := true;
        mode_1.parity_check := true;
        mode_1.test := true;
        ctu_set_mode(mode_1, DUT_NODE, chn);

        ctu_get_txt_buf_cnt(txt_buf_count, DUT_NODE, chn);

        -----------------------------------------------------------------------
        -- @2. Loop 2 times for each TXT Buffer:
        -----------------------------------------------------------------------
        for x in 1 to txt_buf_count loop

            for iteration in 1 to 2 loop
                info_m("Step 2, TXT Buffer: " & integer'image(x) &
                                "iteration: " & integer'image(iteration));

                -------------------------------------------------------------------
                -- @2.1 Generate random priorities of TXT Buffers and apply
                --      them in DUT. Generate random index of TXT Buffer which is
                --      for sure "original" TXT Buffer and insert random frame to it.
                -------------------------------------------------------------------
                info_m("Step 2.1");

                for i in 1 to txt_buf_count loop
                    rand_int_v(7, tmp_int);
                    ctu_set_txt_buf_prio(i, tmp_int, DUT_NODE, chn);
                end loop;

                txt_buf_index := x;
                if (txt_buf_index mod 2 = 0) then
                    txt_buf_index := txt_buf_index - 1;
                end if;

                -- We need to generate frame which has some data bytes, to be able
                -- to corrupt such data bytes
                generate_can_frame(can_tx_frame);
                can_tx_frame.rtr := NO_RTR_FRAME;
                if can_tx_frame.data_length = 0 then
                    can_tx_frame.data_length := 1;
                end if;
                length_to_dlc(can_tx_frame.data_length, can_tx_frame.dlc);
                dlc_to_rwcnt(can_tx_frame.dlc, can_tx_frame.rwcnt);
                ctu_put_tx_frame(can_tx_frame, txt_buf_index, DUT_NODE, chn);
                ctu_put_tx_frame(can_tx_frame, txt_buf_index + 1, DUT_NODE, chn);

                -------------------------------------------------------------------
                -- @2.2 Enable test access to buffer RAMs. Generate random word
                --      index (within data bytesof TXT Buffer), and flip such bit.
                --      Disable test access.
                -------------------------------------------------------------------
                info_m("Step 2.2");

                -- Enable test access
                ctu_set_tst_mem_access(true, DUT_NODE, chn);
                tst_mem := txt_buf_to_test_mem_tgt(txt_buf_index);

                -- Read, flip, and write back
                rand_int_v(31, corrupt_bit_index);
                info_m("RWCNT is: " & integer'image(can_tx_frame.rwcnt));
                rand_int_v(can_tx_frame.rwcnt - 4, corrupt_wrd_index);
                corrupt_wrd_index := corrupt_wrd_index + 4;
                ctu_read_tst_mem(r_data, corrupt_wrd_index, tst_mem, DUT_NODE, chn);
                r_data(corrupt_bit_index) := not r_data(corrupt_bit_index);
                ctu_write_tst_mem(r_data, corrupt_wrd_index, tst_mem, DUT_NODE, chn);

                -- Disable test mem access
                ctu_set_tst_mem_access(false, DUT_NODE, chn);

                -----------------------------------------------------------------------
                -- @2.3 Send Set ready command to selected original TXT Buffer. Wait
                --      until DUT starts transmission, and check that original TXT
                --      Buffer is in "TX in progress". Wait until error frame is
                --      transmitted. Check that "original" TXT Buffer ended in
                --      "Parity Error". Wait until "backup" TXT Buffer becomes
                --      "TX in progress".
                -----------------------------------------------------------------------
                info_m("Step 2.3");

                txt_buf_vector := x"00";
                txt_buf_vector(txt_buf_index - 1) := '1';

                ctu_give_txt_cmd(buf_set_ready, txt_buf_vector, DUT_NODE, chn);

                ctu_wait_frame_start(true, false, DUT_NODE, chn);

                -- Check transmission from "original" TXT Buffer
                ctu_get_txt_buf_state(txt_buf_index, txt_buf_state, DUT_NODE, chn);
                check_m(txt_buf_state = buf_tx_progress, "'Original' TXT Buffer is in 'TX in Progress'");
                ctu_get_txt_buf_state(txt_buf_index + 1, txt_buf_state, DUT_NODE, chn);
                check_m(txt_buf_state = buf_ready, "'Backup' TXT Buffer is in 'TX ready'");

                -- Send Set abort to get covered Abort in Progress -> Parity Error transition!
                if (iteration = 2) then
                    ctu_give_txt_cmd(buf_set_abort, txt_buf_index, DUT_NODE, chn);
                    wait for 30 ns;
                    ctu_get_txt_buf_state(txt_buf_index, txt_buf_state, DUT_NODE, chn);
                    check_m(txt_buf_state = buf_ab_progress,
                            "'Original' TXT Buffer is in 'Abort in Progress'");
                end if;

                ctu_wait_err_frame(DUT_NODE, chn);

                -- Check that original ended in "Parity error"
                ctu_get_txt_buf_state(txt_buf_index, txt_buf_state, DUT_NODE, chn);
                check_m(txt_buf_state = buf_parity_err, "'Original' TXT Buffer is in 'TX Parity error'");

                if (iteration = 1) then
                    ctu_get_txt_buf_state(txt_buf_index + 1, txt_buf_state, DUT_NODE, chn);
                    check_m(txt_buf_state = buf_ready, "'Backup' TXT Buffer is in 'TX ready'");
                else
                    ctu_get_txt_buf_state(txt_buf_index + 1, txt_buf_state, DUT_NODE, chn);
                    check_m(txt_buf_state = buf_aborted, "'Backup' TXT Buffer is in 'Aborted'");
                end if;

                -- Check parity error was set.
                ctu_get_status(status_1, DUT_NODE, chn);
                check_m(status_1.tx_parity_error, "Parity error set.");
                check_false_m(status_1.tx_double_parity_error, "Double parity error not set.");

                -- If abort was issued, then it acted on Both TXT Buffers, so
                -- transmission from Backup Buffer will not follow! Only wait till
                -- bus is idle and go to next TXT Buffer
                if (iteration = 2) then
                    ctu_wait_bus_idle(DUT_NODE, chn);
                    ctu_wait_bus_idle(TEST_NODE, chn);
                    exit;
                end if;

                -- Wait until next "arbitration". This should be during next frame
                ctu_wait_ff(ff_arbitration, DUT_NODE, chn);
                ctu_get_txt_buf_state(txt_buf_index + 1, txt_buf_state, DUT_NODE, chn);
                check_m(txt_buf_state = buf_tx_progress, "'Backup' TXT Buffer is in 'TX in Progress'");

                -----------------------------------------------------------------------
                -- @2.3 Wait until transmission ends and bus is idle. Check that
                --      "original" TXT Buffer is in "TX Parity Error" state and
                --      "backup" TXT buffer ended in "TX OK" state.
                -----------------------------------------------------------------------
                info_m("Step 2.3");

                ctu_wait_frame_sent(DUT_NODE, chn);
                ctu_wait_bus_idle(TEST_NODE, chn);
                ctu_wait_bus_idle(DUT_NODE, chn);

                ctu_get_txt_buf_state(txt_buf_index, txt_buf_state, DUT_NODE, chn);
                check_m(txt_buf_state = buf_parity_err, "'Original' TXT Buffer is in 'Parity error'");
                ctu_get_txt_buf_state(txt_buf_index + 1, txt_buf_state, DUT_NODE, chn);
                check_m(txt_buf_state = buf_done, "'Backup' TXT Buffer is in 'TX OK'");

                -- Check and clear STATUS[TXPE]
                ctu_get_status(status_1, DUT_NODE, chn);
                check_m(status_1.tx_parity_error, "Parity error set.");
                check_false_m(status_1.tx_double_parity_error, "Double parity error not set.");

                command_1.clear_txpe := true;
                ctu_give_cmd(command_1, DUT_NODE, chn);

                ctu_get_status(status_1, DUT_NODE, chn);
                check_false_m(status_1.tx_parity_error, "Parity error not set.");
                check_false_m(status_1.tx_double_parity_error, "Double parity error not set.");

            end loop;

        end loop;

  end procedure;

end package body;