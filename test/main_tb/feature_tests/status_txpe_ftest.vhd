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
--  STATUS[TXPE] feature test.
--
-- @Verifies:
--  @1. STATUS[TXPE] is set when there is a parity error detected in TXT Buffer
--      RAM and SETTINGS[PCHKE] = 1.
--  @2. STATUS[TXPE] is not set when there is a parity error detected in TXT
--      Buffer and SETTINGS[PCHKE] = 0.
--  @2. STATUS[TXPE] is cleared by COMMAND[CTXPE].
--
-- @Test sequence:
--  @1. Set DUT to test mode.
--  @2. Loop 4 times for each TXT Buffer:
--      @2.1 Generate Random CAN frame and set random value of SETTINGS[PCHKE] = 1.
--      @2.2 Insert the CAN frame for transmission into a TXT Buffer.
--      @2.3 Generate random bit-flip in FRAME_FORMAT_W (loop 1), IDENTIFIER_W
--           (loop 2), TIMESTAMP_L_W (loop 3), TIMESTAMP_U_W (loop 4) and
--           corrupt this word in the TXT Buffer memory via test interface.
--      @2.4 Send Set Ready command to this TXT Buffer. Wait for some time, and
--           check that when SETTINGS[PCHKE] = 1, TXT Buffer ended up in
--           "Parity Error" state. When SETTINGS[PCHKE] = 0, check that DUT
--           transmit the frame from TXT Buffer.
--      @2.5 Read STATUS[TXPE] and check it is 1 when SETTINGS[PCHKE]=1. Write
--           COMMAND[CTXPE], and check that STATUS[TXPE] = 0.
--      @2.6 Insert the frame again, send Set Ready command.
--      @2.7 Wait until frame is transmitted. Read frame from Test Node and
--           check it is equal to transmitted frame.
--  @3. Loop 10 times for each TXT Buffer:
--      @3.1 Generate random CAN frame and make sure it has some data words.
--           Insert it into random TXT Buffer. Set random value of
--           SETTINGS[PCHKE] = 1.
--      @3.2 Flip random bit within the data word, and write this flipped bit
--           into TXT Buffer via test access to bypass parity encoding.
--      @3.3 Send Set Ready command to TXT Buffer, wait until frame
--           transmission starts.
--      @3.4 When SETTINGS[PCHKE]=1, wait until error frame, check its
--           transmission from status bit, then check that TXT Buffer ended up
--           in Parity Error state. When SETTINGS[PCHKE]=0, check that frame
--           is transmitted sucesfully.
--      @3.5 Insert CAN frame into the TXT Buffer again.
--      @3.6 Send Set Ready command. Wait until CAN frame is transmitted. Read
--           it from Test Node and check that it matches original CAN frame.
--      @3.7 Disable / Enable DUT. Since we are causing error frames to be
--           transmitted randomly, DUT can become bus-off due to TEC being
--           incremented up to 255!
--
-- @TestInfoEnd
--------------------------------------------------------------------------------
-- Revision History:
--    15.6.2022   Created file
--------------------------------------------------------------------------------

Library ctu_can_fd_tb;
context ctu_can_fd_tb.ieee_context;
context ctu_can_fd_tb.rtl_context;
context ctu_can_fd_tb.tb_common_context;

use ctu_can_fd_tb.feature_test_agent_pkg.all;
use ctu_can_fd_tb.mem_bus_agent_pkg.all;

package status_txpe_ftest is
    procedure status_txpe_ftest_exec(
        signal      chn             : inout  t_com_channel
    );
end package;


package body status_txpe_ftest is
    procedure status_txpe_ftest_exec(
        signal      chn             : inout  t_com_channel
    ) is
        -- Generated frames
        variable frame_1            :     t_ctu_frame;
        variable frame_2            :     t_ctu_frame;

        variable stat_1             :     t_ctu_status;
        variable command_1          :     t_ctu_command := t_ctu_command_rst_val;
        variable mode_1             :     t_ctu_mode := t_ctu_mode_rst_val;
        variable rx_buf_status      :     t_ctu_rx_buf_state;

        variable ff             :     t_ctu_frame_field;
        variable frame_sent         :     boolean;
        variable frames_equal       :     boolean;

        variable rptr_pos           :     integer := 0;
        variable r_data             :     std_logic_vector(31 downto 0);
        type t_raw_can_frame is
            array (0 to 19) of std_logic_vector(31 downto 0);
        variable rx_frame_buffer    :     t_raw_can_frame;
        variable rwcnt              :     integer;
        variable corrupt_wrd_index  :     integer;
        variable corrupt_bit_index  :     integer;
        variable corrupt_insert     :     std_logic;

        variable tst_mem            :     t_tgt_test_mem;
        variable txt_buf_state      :     t_ctu_txt_buff_state;
        variable prt_en             :     std_logic;
        variable num_txt_bufs       :     natural;
        variable hw_cfg             :       t_ctu_hw_cfg;
    begin

        -- Read HW config
        ctu_get_hw_config(hw_cfg, DUT_NODE, chn);
        if (hw_cfg.sup_parity = false) then
            info_m("Skipping the test since sup_parity=false");
            return;
        end if;

        -----------------------------------------------------------------------
        -- @1. Set DUT to test mode.
        -----------------------------------------------------------------------
        info_m("Step 1");
        mode_1.test := true;
        ctu_set_mode(mode_1, DUT_NODE, chn);

        -----------------------------------------------------------------------
        -- @2. Loop 4 times for each TXT Buffer
        -----------------------------------------------------------------------
        info_m("Step 2");
        ctu_get_txt_buf_cnt(num_txt_bufs, DUT_NODE, chn);

        for txt_buf in 1 to num_txt_bufs loop
            for i in 0 to 3 loop

                info_m("Step 2, TXT Buffer: " & integer'image(txt_buf) &
                                "Word: " & integer'image(i));

                -------------------------------------------------------------------
                -- @2.1 Generate Random CAN frame and set random value of
                --      SETTINGS[PCHKE] = 1.
                -------------------------------------------------------------------
                info_m("Step 2.1");
                generate_can_frame(frame_1);
                rand_logic_v(prt_en, 0.5);
                if (prt_en = '1') then
                    mode_1.parity_check := true;
                else
                    mode_1.parity_check := false;
                end if;
                ctu_set_mode(mode_1, DUT_NODE, chn);

                -------------------------------------------------------------------
                -- @2.2 Insert the CAN frame for transmission into a TXT Buffer.
                -------------------------------------------------------------------
                info_m("Step 2.2");
                ctu_put_tx_frame(frame_1, txt_buf, DUT_NODE, chn);

                -------------------------------------------------------------------
                -- @2.3 Generate random bit-flip in FRAME_FORMAT_W (loop 1),
                --      IDENTIFIER_W (loop 2), TIMESTAMP_L_W (loop 3), TIMESTAMP_U_W
                --      (loop 4) and corrupt this word in the TXT Buffer memory via
                --      test interface.
                -------------------------------------------------------------------
                info_m("Step 2.3");

                -- Enable test access
                ctu_set_tst_mem_access(true, DUT_NODE, chn);
                tst_mem := txt_buf_to_test_mem_tgt(txt_buf);

                -- Read, flip, and write back
                ctu_read_tst_mem(r_data, i, tst_mem, DUT_NODE, chn);
                rand_int_v(31, corrupt_bit_index);
                r_data(corrupt_bit_index) := not r_data(corrupt_bit_index);
                ctu_write_tst_mem(r_data, i, tst_mem, DUT_NODE, chn);

                -- Disable test mem access
                ctu_set_tst_mem_access(false, DUT_NODE, chn);

                -------------------------------------------------------------------
                -- @2.4 Send Set Ready command to this TXT Buffer. Wait for some
                -- time, and check that when SETTINGS[PCHKE] = 1, TXT Buffer ended
                -- up in "Parity Error" state. When SETTINGS[PCHKE] = 0, check that
                -- DUT transmit the frame from TXT Buffer.
                -------------------------------------------------------------------
                info_m("Step 2.4");

                ctu_give_txt_cmd(buf_set_ready, txt_buf, DUT_NODE, chn);

                -- Waiting for two bits is sufficient for DUT to start transmission.
                wait for 10 us;

                ctu_get_txt_buf_state(txt_buf, txt_buf_state, DUT_NODE, chn);

                -- TXT Buffer shall end up in parity error only when parity error
                -- detection is enabled, otherwise DUT will go on and transmit the
                -- frame. Received frame might not be correct though, since it
                -- contained bit flip!
                if (mode_1.parity_check) then
                    check_m(txt_buf_state = buf_parity_err,
                            "Bit flip + SETTINGS[PCHKE] = 1 -> TXT Buffer in parity error state!");
                else
                    check_m(txt_buf_state = buf_tx_progress or txt_buf_state = buf_done,
                            "Bit flip + SETTINGS[PCHKE] = 0 -> TXT Buffer in TX in progress or Done state!");
                    ctu_wait_bus_idle(DUT_NODE, chn);
                    ctu_wait_bus_idle(TEST_NODE, chn);
                    ctu_get_txt_buf_state(txt_buf, txt_buf_state, DUT_NODE, chn);
                    check_m(txt_buf_state = buf_done, "DUT: TXT Buffer TX OK");

                    ctu_get_rx_buf_state(rx_buf_status, TEST_NODE, chn);
                    check_m(rx_buf_status.rx_frame_count = 1,
                            "TEST_NODE: Frame received!");

                    -- Need to read-out received frame so that it does not block
                    -- RX Buffer FIFO in Test node.
                    ctu_read_frame(frame_2, TEST_NODE, chn);
                end if;

                ctu_get_status(stat_1, DUT_NODE, chn);
                check_false_m(stat_1.transmitter, "DUT is not transmitter.");

                -- Send the TXT Buffer back to Empty and check it!
                ctu_give_txt_cmd(buf_set_empty, txt_buf, DUT_NODE, chn);
                wait for 30 ns;
                ctu_get_txt_buf_state(txt_buf, txt_buf_state, DUT_NODE, chn);
                check_m(txt_buf_state = buf_empty, "DUT: TXT Buffer Empty");

                -------------------------------------------------------------------
                -- @2.5 Read STATUS[TXPE] and check it is 1 when SETTINGS[PCHKE]=1.
                --      Write COMMAND[CTXPE], and check that STATUS[TXPE] = 0.
                -------------------------------------------------------------------
                info_m("Step 2.5");

                ctu_get_status(stat_1, DUT_NODE, chn);

                if (mode_1.parity_check) then
                    check_m(stat_1.tx_parity_error,
                            "Bit flip + SETTINGS[PCHKE] = 1 -> STATUS[TXPE] = 1");
                else
                    check_false_m(stat_1.tx_parity_error,
                            "Bit flip + SETTINGS[PCHKE] = 0 -> STATUS[TXPE] = 0");
                end if;

                command_1.clear_txpe := true;
                ctu_give_cmd(command_1, DUT_NODE, chn);

                ctu_get_status(stat_1, DUT_NODE, chn);
                check_false_m(stat_1.tx_parity_error, "STATUS[TXPE] = 0");

                -------------------------------------------------------------------
                -- @2.6 Insert the frame again, send Set Ready command.
                -------------------------------------------------------------------
                info_m("Step 2.6");

                ctu_put_tx_frame(frame_1, txt_buf, DUT_NODE, chn);
                ctu_give_txt_cmd(buf_set_ready, txt_buf, DUT_NODE, chn);

                -------------------------------------------------------------------
                -- @2.7 Wait until frame is transmitted. Read frame from Test Node
                --      and check it is equal to transmitted frame.
                -------------------------------------------------------------------
                info_m("Step 2.7");

                ctu_wait_frame_sent(DUT_NODE, chn);
                ctu_read_frame(frame_2, TEST_NODE, chn);

                compare_can_frames(frame_1, frame_2, false, frames_equal);
                check_m(frames_equal, "Frames are equal.");

            end loop;
        end loop;

        ---------------------------------------------------------------------------
        --  @3. Loop 10 times for each TX Buffer:
        ---------------------------------------------------------------------------
        info_m("Step 3");
        for txt_buf in 1 to num_txt_bufs loop
            for i in 0 to 9 loop

                -----------------------------------------------------------------------
                -- @3.1 Generate random CAN frame and make sure it has some data words.
                --      Insert it into random TXT Buffer. Set random value of
                --      SETTINGS[PCHKE] = 1.
                -----------------------------------------------------------------------
                info_m("Step 3.1");

                rand_logic_v(prt_en, 0.5);
                if (prt_en = '1') then
                    mode_1.parity_check := true;
                else
                    mode_1.parity_check := false;
                end if;
                ctu_set_mode(mode_1, DUT_NODE, chn);

                generate_can_frame(frame_1);
                frame_1.rtr := NO_RTR_FRAME;
                if frame_1.data_length = 0 then
                    frame_1.data_length := 1;
                end if;
                length_to_dlc(frame_1.data_length, frame_1.dlc);
                dlc_to_rwcnt(frame_1.dlc, frame_1.rwcnt);

                ctu_put_tx_frame(frame_1, txt_buf, DUT_NODE, chn);

                -----------------------------------------------------------------------
                -- @3.2 Flip random bit within the data word, and write this flipped
                --      bit into TXT Buffer via test access to bypass parity encoding.
                -----------------------------------------------------------------------
                info_m("Step 3.2");

                -- Generate random word / bit index to flip
                rand_int_v(31, corrupt_bit_index);
                dlc_to_rwcnt(frame_1.dlc, rwcnt);
                rand_int_v(rwcnt - 4, corrupt_wrd_index);
                corrupt_wrd_index := corrupt_wrd_index + 4;
                info_m("Flipping word index: " & integer'image(corrupt_wrd_index));
                info_m("Flipping bit  index: " & integer'image(corrupt_bit_index));

                -- Enable test access
                ctu_set_tst_mem_access(true, DUT_NODE, chn);
                tst_mem := txt_buf_to_test_mem_tgt(txt_buf);

                -- Read, flip, and write back
                ctu_read_tst_mem(r_data, corrupt_wrd_index, tst_mem, DUT_NODE, chn);
                r_data(corrupt_bit_index) := not r_data(corrupt_bit_index);
                ctu_write_tst_mem(r_data, corrupt_wrd_index, tst_mem, DUT_NODE, chn);

                -- Disable test mem access
                ctu_set_tst_mem_access(false, DUT_NODE, chn);

                -----------------------------------------------------------------------
                -- @3.3 Send Set Ready command to TXT Buffer, wait until frame
                --      transmission starts.
                -----------------------------------------------------------------------
                info_m("Step 3.3");

                ctu_give_txt_cmd(buf_set_ready, txt_buf, DUT_NODE, chn);

                ctu_wait_frame_start(true, false, DUT_NODE, chn);

                -----------------------------------------------------------------------
                -- @3.4 Wait until error frame, check it is being transmitted. Check
                --      that TXT Buffer ended up in Parity Error state.  When
                --      SETTINGS[PCHKE]=0, check that frame is transmitted sucesfully.
                -----------------------------------------------------------------------
                info_m("Step 3.4");

                -- Note: Despite the fact that we flipped bit of data field, we can't
                --       wait till data field. If we flipped bit in first data word, it
                --       will be read out during control field, and thus protocol control
                --       will never get to data field!
                if (mode_1.parity_check) then
                    ctu_wait_err_frame(DUT_NODE, chn);
                    ctu_get_status(stat_1, DUT_NODE, chn);

                    check_m(stat_1.error_transmission, "Error frame is being transmitted");

                    ctu_get_txt_buf_state(txt_buf, txt_buf_state, DUT_NODE, chn);
                    check_m(txt_buf_state = buf_parity_err,
                            "Bit flip + SETTINGS[PCHKE] = 1 -> TXT Buffer in parity error state!");

                -- In the case where we did not cause parity error, expect normal frame
                -- transmission without any error frame!
                else
                    ctu_wait_frame_sent(DUT_NODE, chn);
                    ctu_wait_bus_idle(DUT_NODE, chn);
                    ctu_wait_bus_idle(TEST_NODE, chn);

                    ctu_get_txt_buf_state(txt_buf, txt_buf_state, DUT_NODE, chn);
                    check_m(txt_buf_state = buf_done,
                            "Bit flip + SETTINGS[PCHKE] = 0 -> TXT Buffer in TX OK state!");

                    ctu_get_rx_buf_state(rx_buf_status, TEST_NODE, chn);
                    check_m(rx_buf_status.rx_frame_count = 1,
                            "TEST_NODE: Frame received!");

                    -- Need to read-out received frame so that it does not block
                    -- RX Buffer FIFO in Test node.
                    ctu_read_frame(frame_2, TEST_NODE, chn);
                end if;

                -- Check that parity flag was set, clear it!
                ctu_get_status(stat_1, DUT_NODE, chn);
                if (mode_1.parity_check) then
                    check_m(stat_1.tx_parity_error,
                            "Bit flip + SETTINGS[PCHKE] = 1 -> STATUS[TXPE] = 1");
                else
                    check_false_m(stat_1.tx_parity_error,
                            "Bit flip + SETTINGS[PCHKE] = 0 -> STATUS[TXPE] = 0");
                end if;

                command_1.clear_txpe := true;
                ctu_give_cmd(command_1, DUT_NODE, chn);

                ctu_get_status(stat_1, DUT_NODE, chn);
                check_false_m(stat_1.tx_parity_error, "STATUS[TXPE] = 0");

                ---------------------------------------------------------------------------
                -- @3.5 Insert CAN frame into the TXT Buffer again.
                ---------------------------------------------------------------------------
                info_m("Step 3.5");

                ctu_put_tx_frame(frame_1, txt_buf, DUT_NODE, chn);

                ---------------------------------------------------------------------------
                -- @3.6 Send Set Ready command. Wait until CAN frame is transmitted. Read
                --      it from Test Node and check that it matches original CAN frame.
                ---------------------------------------------------------------------------
                info_m("Step 3.6");

                ctu_give_txt_cmd(buf_set_ready, txt_buf, DUT_NODE, chn);

                ctu_wait_frame_sent(DUT_NODE, chn);
                ctu_read_frame(frame_2, TEST_NODE, chn);

                compare_can_frames(frame_1, frame_2, false, frames_equal);
                check_m(frames_equal, "Frames are equal.");

            end loop;

            ---------------------------------------------------------------------------
            -- @3.7 Disable / Enable DUT. Since we are causing error frames to be
            --      transmitted randomly, DUT can become bus-off due to TEC being
            --      incremented up to 255!
            ---------------------------------------------------------------------------
            info_m("Step 3.7");

            ctu_turn(false, DUT_NODE, chn);
            ctu_turn(true, DUT_NODE, chn);
            ctu_wait_err_active(DUT_NODE, chn);

        end loop;

    end procedure;

end package body;
