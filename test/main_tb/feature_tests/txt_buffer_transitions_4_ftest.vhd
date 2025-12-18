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
--  TXT Buffer FSMs corner-case transitions 4
--
-- @Verifies:
--  @1. When TXT Buffer is in Abort in Progress, and parity error occurs, it
--      moves to Parity Error state
--  @2. When Set Empty TXT Buffer command is applied on TXT Buffer in
--      Parity Error state, the TXT Buffer will move to TX Empty state.
--
-- @Test sequence:
--  @1. Loop for all TXT Buffers:
--      @1.1. Insert a CAN frame into to a TXT Buffer. Insert a bit-flip
--            into a data word inside TXT Buffer.
--      @1.2. Send Set Ready Command. Wait until DUT starts transmitting the
--            frame, and then send Set Abort Command.
--      @1.3. Wait until bus is idle. Check TXT Buffer ended in Parity Error.
--      @1.4. Issue Set Empty Command. Check TXT Buffer is empty.
--
-- @TestInfoEnd
--------------------------------------------------------------------------------
-- Revision History:
--      12.11.2023   Created file
--------------------------------------------------------------------------------

Library ctu_can_fd_tb;
context ctu_can_fd_tb.ieee_context;
context ctu_can_fd_tb.rtl_context;
context ctu_can_fd_tb.tb_common_context;

use ctu_can_fd_tb.feature_test_agent_pkg.all;
use ctu_can_fd_tb.clk_gen_agent_pkg.all;

package txt_buffer_transitions_4_ftest is
    procedure txt_buffer_transitions_4_ftest_exec(
        signal      chn             : inout  t_com_channel
    );
end package;


package body txt_buffer_transitions_4_ftest is

    procedure txt_buffer_transitions_4_ftest_exec(
        signal      chn             : inout  t_com_channel
    ) is
        variable can_frame          :       t_ctu_frame;
        variable command            :       t_ctu_command := t_ctu_command_rst_val;
        variable status             :       t_ctu_status;
	    variable txt_buf_state	    :	    t_ctu_txt_buff_state;
        variable mode               :       t_ctu_mode := t_ctu_mode_rst_val;
        variable num_txt_bufs       :       natural;
        variable frame_sent         :       boolean;
        variable err_counters       :       t_ctu_err_ctrs;
        variable fault_state        :       t_ctu_fault_state;
        variable can_tx_val         :       std_logic;
        variable bus_timing         :       t_ctu_bit_time_cfg;
        variable tseg1              :       natural;

        variable tst_mem            :       t_tgt_test_mem;
        variable corrupt_wrd_index  :       natural;
        variable corrupt_bit_index  :       natural;
        variable r_data             :       std_logic_vector(31 downto 0);
        variable hw_cfg             :       t_ctu_hw_cfg;
    begin

        ctu_get_hw_config(hw_cfg, DUT_NODE, chn);
        if (hw_cfg.sup_parity = false) then
            info_m("Skipping the test since sup_parity = false -> Can't invoke Parity Error");
            return;
        end if;

        -------------------------------------------------------------------------------------------
        -- @1. Loop for all TXT Buffers and incrementing wait times within a bit:
        -------------------------------------------------------------------------------------------
        info_m("Step 1");
        ctu_get_txt_buf_cnt(num_txt_bufs, DUT_NODE, chn);

        -- Configure test mode to allow bit-flips via test channel in TXT Buffer Memory.
        mode.test := true;
        mode.parity_check := true;
        ctu_set_mode(mode, DUT_NODE, chn);

        -- Generate single common frame
        generate_can_frame(can_frame);
        can_frame.frame_format := FD_CAN;
        can_frame.data_length := 16;
        can_frame.rtr := NO_RTR_FRAME;
        length_to_dlc(can_frame.data_length, can_frame.dlc);

        for txt_buf_index in 1 to num_txt_bufs loop

            -----------------------------------------------------------------------------------
            -- @1.1. Insert a frame into a TXT Buffer. Insert a bit-flip into a data word
            --       inside TXT Buffer.
            -----------------------------------------------------------------------------------
            info_m("Step 1.1");

            ctu_put_tx_frame(can_frame, txt_buf_index, DUT_NODE, chn);

            ctu_set_tst_mem_access(true, DUT_NODE, chn);

            tst_mem := txt_buf_to_test_mem_tgt(txt_buf_index);

            -- Read, flip, and write back
            corrupt_wrd_index := 5;             -- Flip bit in data bytes 5-8
            rand_int_v(31, corrupt_bit_index);
            ctu_read_tst_mem(r_data, corrupt_wrd_index, tst_mem, DUT_NODE, chn);
            r_data(corrupt_bit_index) := not r_data(corrupt_bit_index);
            ctu_write_tst_mem(r_data, corrupt_wrd_index, tst_mem, DUT_NODE, chn);

            -- Disable test mem access
            ctu_set_tst_mem_access(false, DUT_NODE, chn);

            ---------------------------------------------------------------------------------------
            -- @1.2. Send Set Ready Command. Wait until DUT starts transmitting the frame, and then
            --       send Set Abort Command.
            ---------------------------------------------------------------------------------------
            info_m("Step 1.2");

            ctu_give_txt_cmd(buf_set_ready, txt_buf_index, DUT_NODE, chn);
            ctu_wait_frame_start(true, false, DUT_NODE, chn);
            wait for 1000 ns;

            ctu_give_txt_cmd(buf_set_abort, txt_buf_index, DUT_NODE, chn);

            ---------------------------------------------------------------------------------------
            -- @1.3. Wait until bus is idle. Check TXT Buffer ended in Parity Error.
            ---------------------------------------------------------------------------------------
            info_m("Step 1.3");

            ctu_wait_bus_idle(DUT_NODE, chn);
            ctu_wait_bus_idle(TEST_NODE, chn);

            ctu_get_txt_buf_state(txt_buf_index, txt_buf_state, DUT_NODE, chn);

            check_m(txt_buf_state = buf_parity_err, "TXT Buffer in parity error state");

            ---------------------------------------------------------------------------------------
            -- @1.4. Issue Set Empty Command. Check TXT Buffer is empty.
            ---------------------------------------------------------------------------------------
            info_m("Step 1.4");

            ctu_give_txt_cmd(buf_set_empty, txt_buf_index, DUT_NODE, chn);
            wait for 20 ns; -- Command is pipelined

            ctu_get_txt_buf_state(txt_buf_index, txt_buf_state, DUT_NODE, chn);
            check_m(txt_buf_state = buf_empty, "TXT Buffer in Empty state");

        end loop;

  end procedure;
end package body;
