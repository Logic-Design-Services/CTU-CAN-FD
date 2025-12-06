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
--  Frame filters A,B,C feature test
--
-- @Verifies:
--  @1. FILTER_*_MASK and FILTER_*_VALUE correctly filter received RX frames.
--  @3. FILTER_CONTROL register correctly filters each combination of Frame
--      format / Identifier type.
--
-- @Test sequence:
--  @1. Read HW configuration to check if HW filters are present.
--  @2. Loop through all combinations of FILTER_CONTROL on each of the filters.
--      For bit filters loop through different masks (random, checkerboard, etc...)
--      @2.1 Generate Random frame and send it by Test node. Wait until the
--           frame is received by DUT Node.
--      @2.2 Pre-compute the expected result of filtering.
--      @2.3 Check that if filter should match the frame, the frame is stored
--           in RX Buffer of DUT Node. Read the frame from RX Buffer.
--
-- @TestInfoEnd
--------------------------------------------------------------------------------
-- Revision History:
--    15.11.2023   Created file
--------------------------------------------------------------------------------

Library ctu_can_fd_tb;
context ctu_can_fd_tb.ieee_context;
context ctu_can_fd_tb.rtl_context;
context ctu_can_fd_tb.tb_common_context;

use ctu_can_fd_tb.feature_test_agent_pkg.all;

package frame_filters_mask_ftest is
    procedure frame_filters_mask_ftest_exec(
        signal      chn             : inout  t_com_channel
    );
end package;


package body frame_filters_mask_ftest is
    procedure frame_filters_mask_ftest_exec(
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
        variable txt_buf_index      :       natural;

        variable status_1           :       t_ctu_status;

        variable txt_buf_vector     :       std_logic_vector(7 downto 0) := x"00";
        variable txt_buf_state      :       t_ctu_txt_buff_state;

        variable swap_dlc           :       natural;
        variable expected_dlc       :       std_logic_vector(3 downto 0) := "0000";
        variable real_dlc           :       std_logic_vector(3 downto 0) := "0000";

        variable err_capt           :       t_ctu_err_capt;
        variable range_cfg          :       t_ctu_ran_filt_cfg;
        variable should_pass        :       boolean;
        variable rx_buf_state       :       t_ctu_rx_buf_state;
        variable filt_cfg           :       t_ctu_mask_filt_cfg;

        variable exp_base_mask      :       std_logic_vector(10 downto 0);
        variable exp_base_val       :       std_logic_vector(10 downto 0);
        variable exp_base_id        :       std_logic_vector(10 downto 0);

        variable exp_ext_mask       :       std_logic_vector(28 downto 0);
        variable exp_ext_val        :       std_logic_vector(28 downto 0);
        variable exp_ext_id         :       std_logic_vector(28 downto 0);

        variable tmp_base           :       std_logic_vector(10 downto 0);
        variable tmp_ext            :       std_logic_vector(28 downto 0);

        variable hw_cfg           : t_ctu_hw_cfg;
    begin

        -------------------------------------------------------------------------------------------
        -- @2. Loop through all combinations of FILTER_CONTROL on each of the filters.
        -------------------------------------------------------------------------------------------
        info_m("Step 2");

        -- Filters Need to be globally enabled, otherwise they are ignored.
        mode_1.acceptance_filter := true;
        ctu_set_mode(mode_1, DUT_NODE, chn);

        -- Read HW configuration
        ctu_get_hw_config(hw_cfg, DUT_NODE, chn);

        -- Disable Range filter here
        range_cfg.acc_CAN_2_0 := false;
        range_cfg.acc_CAN_2_0 := false;
        range_cfg.ident_type := BASE;
        ctu_set_ran_filter(range_cfg, DUT_NODE, chn);

        for filter in t_ctu_mask_filt_kind'left to t_ctu_mask_filt_kind'right loop

            -- Skip the filter if not present
            if (filter = filter_A and hw_cfg.sup_filtA = false) then
                info_m("Skipping filter A since it is not present in HW");
                next;
            end if;

            if (filter = filter_B and hw_cfg.sup_filtB = false) then
                info_m("Skipping filter B since it is not present in HW");
                next;
            end if;

            if (filter = filter_C and hw_cfg.sup_filtC = false) then
                info_m("Skipping filter C since it is not present in HW");
                next;
            end if;

            for ident_type in BASE to EXTENDED loop
                for can_2_0_en in boolean'left to boolean'right loop
                    for can_fd_en in boolean'left to boolean'right loop
                        for frame_index in 1 to 5 loop

                            -- Disable all filters
                            filt_cfg.acc_CAN_2_0 := false;
                            filt_cfg.acc_CAN_FD := false;
                            filt_cfg.ident_type := BASE;
                            filt_cfg.ID_value := 0;
                            filt_cfg.ID_mask := 0;
                            ctu_set_mask_filter(filter_A, filt_cfg, DUT_NODE, chn);
                            ctu_set_mask_filter(filter_B, filt_cfg, DUT_NODE, chn);
                            ctu_set_mask_filter(filter_C, filt_cfg, DUT_NODE, chn);

                            -- Only enable the target filter
                            if (ident_type = BASE) then
                                rand_int_v(2 ** 11 - 1, filt_cfg.ID_value);
                                -- Make mask sparse enough so that we actually match something
                                rand_logic_vect_v(tmp_base, 0.1);
                                filt_cfg.ID_mask := to_integer(unsigned(tmp_base));
                            else
                                rand_int_v(2 ** 29 - 1, filt_cfg.ID_value);
                                -- Make mask sparse enough so that we actually match something
                                rand_logic_vect_v(tmp_ext, 0.1);
                                filt_cfg.ID_mask := to_integer(unsigned(tmp_ext));
                            end if;

                            filt_cfg.ident_type := ident_type;
                            filt_cfg.acc_CAN_2_0 := can_2_0_en;
                            filt_cfg.acc_CAN_FD := can_fd_en;
                            ctu_set_mask_filter(filter, filt_cfg, DUT_NODE, chn);

                            -------------------------------------------------------------------------------
                            -- @2.1 Generate Random frame and send it by Test node. Wait until the
                            --      frame is received by DUT Node.
                            -------------------------------------------------------------------------------
                            info_m("Step 2.1");

                            generate_can_frame(can_tx_frame);
                            ctu_send_frame(can_tx_frame, 1, TEST_NODE, chn, frame_sent);
                            ctu_wait_frame_sent(DUT_NODE, chn);
                            ctu_wait_bus_idle(DUT_NODE, chn);

                            -------------------------------------------------------------------------------
                            -- @2.2 Pre-compute the expected result of filtering.
                            -------------------------------------------------------------------------------
                            info_m("Step 2.2");

                            should_pass := true;

                            if (can_tx_frame.frame_format = NORMAL_CAN and filt_cfg.acc_CAN_2_0 = false) then
                                should_pass := false;
                            end if;

                            if (can_tx_frame.frame_format = FD_CAN and filt_cfg.acc_CAN_FD = false) then
                                should_pass := false;
                            end if;

                            if (can_tx_frame.ident_type /= filt_cfg.ident_type) then
                                should_pass := false;
                            end if;

                            if (ident_type = BASE) then
                                exp_base_mask := std_logic_vector(to_unsigned(filt_cfg.ID_mask, 11));
                                exp_base_val  := std_logic_vector(to_unsigned(filt_cfg.ID_value, 11));
                                exp_base_id   := std_logic_vector(to_unsigned(can_tx_frame.identifier, 11));
                                if ((exp_base_val and exp_base_mask) /= (exp_base_id and exp_base_mask)) then
                                    should_pass := false;
                                end if;
                            else
                                exp_ext_mask := std_logic_vector(to_unsigned(filt_cfg.ID_mask, 29));
                                exp_ext_val  := std_logic_vector(to_unsigned(filt_cfg.ID_value, 29));
                                exp_ext_id   := std_logic_vector(to_unsigned(can_tx_frame.identifier, 29));
                                if ((exp_ext_val and exp_ext_mask) /= (exp_ext_id and exp_ext_mask)) then
                                    should_pass := false;
                                end if;
                            end if;

                            -------------------------------------------------------------------------------
                            -- @2.3 Check that if filter should match the frame, the frame is stored
                            --      in RX Buffer of DUT Node. Read the frame from RX Buffer.
                            -------------------------------------------------------------------------------
                            info_m("Step 2.3");

                            ctu_get_rx_buf_state(rx_buf_state, DUT_NODE, chn);
                            if (should_pass) then
                                check_m(rx_buf_state.rx_frame_count = 1, "Frame received when expected!");
                                ctu_read_frame(can_rx_frame, DUT_NODE, chn);
                                compare_can_frames(can_rx_frame, can_tx_frame, false, frames_equal);
                                check_m(frames_equal, "Frames are equal");
                            else
                                check_m(rx_buf_state.rx_frame_count = 0, "Frame NOT received when NOT expected!");
                            end if;

                        end loop;
                    end loop;
                end loop;
            end loop;
        end loop;

  end procedure;

end package body;