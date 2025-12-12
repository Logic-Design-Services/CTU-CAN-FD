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
--  STATUS[RXPE] feature test.
--
-- @Verifies:
--  @1. STATUS[RXPE] is set when there is a parity error inserted in RX Buffer
--      RAM and SETTINGS[PCHKE] = 1.
--  @2. STATUS[RXPE] is cleared by COMMAND[CRXPE].
--  @3. STATUS[RXPE] is not set when SETTINGS[PCHKE] = 0, and there is parity
--      error inserted in RX Buffer RAM.
--
-- @Test sequence:
--  @1. Set DUT to test mode.
--  @2. Loop 10 times.
--      @2.1 Randomly enable/disable parity enable!
--      @2.2 Generate random CAN Frame, and send it by Test node. Wait until
--           frame is received by DUT.
--      @2.3 Read CAN frame from DUT via Test registers. Flip random bit in the
--           CAN frame, and store it right back. This should corrupt parity
--           bit value and cause parity error.
--      @2.4 Read CAN frame via RX_DATA register. Check that STATUS[RXPE]=1.
--      @2.5 Write COMMAND[CRXPE]=1, then read STATUS register and check that
--           STATUS[RXPE]=0.
--
-- @TestInfoEnd
--------------------------------------------------------------------------------
-- Revision History:
--    7.5.2022   Created file
--------------------------------------------------------------------------------

Library ctu_can_fd_tb;
context ctu_can_fd_tb.ieee_context;
context ctu_can_fd_tb.rtl_context;
context ctu_can_fd_tb.tb_common_context;

use ctu_can_fd_tb.feature_test_agent_pkg.all;
use ctu_can_fd_tb.mem_bus_agent_pkg.all;

package status_rxpe_ftest is
    procedure status_rxpe_ftest_exec(
        signal      chn             : inout  t_com_channel
    );
end package;


package body status_rxpe_ftest is
    procedure status_rxpe_ftest_exec(
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

        variable rptr_pos           :     integer := 0;
        variable r_data             :     std_logic_vector(31 downto 0);
        type t_raw_can_frame is
            array (0 to 19) of std_logic_vector(31 downto 0);
        variable rx_frame_buffer    :     t_raw_can_frame;
        variable rwcnt              :     integer;
        variable corrupt_wrd_index  :     integer;
        variable corrupt_bit_index  :     integer;
        variable corrupt_insert     :     std_logic;
        variable prt_en             :     std_logic;
        variable hw_cfg             :     t_ctu_hw_cfg;
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
        mode_1.test := true;
        ctu_set_mode(mode_1, DUT_NODE, chn);
        ctu_get_rx_buf_state(rx_buf_status, DUT_NODE, chn);

        for i in 1 to 10 loop
            info_m("Loop nr.: " & integer'image(i));

            -------------------------------------------------------------------
            -- @2.1
            -------------------------------------------------------------------
            info_m("Step 2.1");

            rand_logic_v(prt_en, 0.5);
            if (prt_en = '1') then
                mode_1.parity_check := true;
            else
                mode_1.parity_check := false;
            end if;
            ctu_set_mode(mode_1, DUT_NODE, chn);

            -------------------------------------------------------------------
            -- @2.2. Generate random CAN Frame, and send it by Test node. Wait
            --       until frame is received by DUT.
            -------------------------------------------------------------------
            info_m("Step 2.2");

            generate_can_frame(frame_1);
            ctu_send_frame(frame_1, 1, TEST_NODE, chn, frame_sent);
            ctu_wait_frame_sent(DUT_NODE, chn);

            -- Disable due to many transfers when reading whole RX Buffer RAM!
            mem_bus_agent_disable_transaction_reporting(chn);

            -------------------------------------------------------------------
            -- @2.3. Read CAN frame from DUT via Test registers. Flip random
            --       bit in the CAN frame, and store it right back. This should
            --       corrupt parity bit value and cause parity error.
            -------------------------------------------------------------------
            info_m("Step 2.3");

            -- Read FRAME_FORMAT_W and Decode number of remaining words in
            -- the frame
            ctu_set_tst_mem_access(true, DUT_NODE, chn);
            ctu_read_tst_mem(r_data, rptr_pos, TST_TGT_RX_BUF, DUT_NODE, chn);
            rx_frame_buffer(0) := r_data;
            dlc_to_rwcnt(r_data(DLC_H downto DLC_L), rwcnt);

            -- Read rest of the frame
            for j in 1 to rwcnt loop
                ctu_read_tst_mem(r_data, rptr_pos + j, TST_TGT_RX_BUF, DUT_NODE, chn);
                rx_frame_buffer(j) := r_data;
            end loop;

            -- Choose if to corrupt a bit or not
            -- Choose random word (but less than RWCNT) and bit between 0 and 31
            rand_logic_v(corrupt_insert, 0.7);
            rand_int_v(rwcnt, corrupt_wrd_index);
            rand_int_v(31, corrupt_bit_index);

            -- Flip selected bit
            if (corrupt_insert = '1') then
                rx_frame_buffer(corrupt_wrd_index)(corrupt_bit_index) :=
                    not rx_frame_buffer(corrupt_wrd_index)(corrupt_bit_index);
            end if;

            -- Write frame back
            for j in 0 to rwcnt loop
                ctu_write_tst_mem(rx_frame_buffer(j), rptr_pos + j, TST_TGT_RX_BUF, DUT_NODE, chn);
            end loop;

            -- We must read once again from FRAME_FORMAT_W position to get RX Buffer RAM
            -- register output at FRAME_FORMAT_W position.
            ctu_read_tst_mem(r_data, rptr_pos, TST_TGT_RX_BUF, DUT_NODE, chn);

            rptr_pos := (rptr_pos + rwcnt + 1) mod rx_buf_status.rx_buff_size;

            -- We must disable test memory access, since it has priority over regular
            -- access!
            ctu_set_tst_mem_access(false, DUT_NODE, chn);

            -------------------------------------------------------------------
            -- @2.4 Read CAN frame via RX_DATA register.
            --      Check that STATUS[RXPE]=1.
            -------------------------------------------------------------------
            info_m("Step 2.4");

            -- Frame is corrupted, but we got RWCNT uncorrupted due to original
            -- read. Get it from RX Buffer. Note that if we read more words
            -- than the frame contains, we would read from un-initialized
            -- memory, and get parity error set!
            for j in 0 to rwcnt loop
                ctu_read(r_data, RX_DATA_ADR, DUT_NODE, chn);
            end loop;

            ctu_get_status(stat_1, DUT_NODE, chn);

            if (corrupt_insert = '1') then
                if (mode_1.parity_check) then
                    check_m(stat_1.rx_parity_error,
                        "MODE[PCHKE]=1 -> STATUS[RXPE]=1 when parity error was inserted!");
                else
                    check_false_m(stat_1.rx_parity_error,
                        "MODE[PCHKE]=0 -> STATUS[RXPE]=0 when parity error was inserted!");
                end if;
            else
                if (mode_1.parity_check) then
                    check_false_m(stat_1.rx_parity_error,
                        "MODE[PCHKE]=1 -> STATUS[RXPE]=0 when parity error was NOT inserted!");
                else
                    check_false_m(stat_1.rx_parity_error,
                        "MODE[PCHKE]=0 -> STATUS[RXPE]=0 when parity error was NOT inserted!");
                end if;
            end if;

            -------------------------------------------------------------------
            -- @2.5 Write COMMAND[CRXPE]=1, then read STATUS register and check
            --      that STATUS[RXPE]=0.
            -------------------------------------------------------------------
            info_m("Step 2.5");

            command_1.clear_rxpe := true;
            ctu_give_cmd(command_1, DUT_NODE, chn);
            ctu_get_status(stat_1, DUT_NODE, chn);
            check_false_m(stat_1.rx_parity_error, "DUT: STATUS[RXPE] not cleared!");

            -- Datasheet, section 2.13.1
            --
            -- If Parity error occured during FRAME_FORMAT_W, then RWCNT read
            -- might be corrupted. We read RWCNT uncorrupted (since we read it
            -- before flipping random bit), but we could have flipped RWCNT bit.
            -- Due to this, CTU CAN FD can wrongly understand RWCNT, and if the
            -- frame being read, is the only frame in the RX Buffer, it can set
            -- RX_STATUS[MOF] and RX_STATUS[RXE] sooner than at the end of
            -- frame. This is because "read_counter" inside RX Buffer depends on
            -- RWCNT read from RX Buffer. If empty, is set too soon due to such
            -- parity error, R/W pointers will get inconsistent in the HW, and
            -- not allow read pointer to reach value of write pointer!
            --
            -- Due to this reason, RXPE handling procedure applies RX Buffer
            -- flush, if parity error has been detected in FRAME_FORMAT_W, since
            -- there is always danger of having RWCNT or MOF wrong, and therefore
            -- never being able to synchronize back. HW can get inconsistent
            -- since it operates with RWCNT during frame read-out.
            --
            -- So, we do exactly as the datasheet says, we flush the RX Buffer
            -- if the error occured during FRAME_FORMAT_W.
            command_1.clear_rxpe := false;
            command_1.release_rec_buffer := true;
            ctu_give_cmd(command_1, DUT_NODE, chn);
            rptr_pos := 0;

        end loop;

  end procedure;

end package body;
