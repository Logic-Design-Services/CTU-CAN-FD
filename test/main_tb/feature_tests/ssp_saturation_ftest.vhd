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
--  Secondary sampling point saturation test.
--
-- @Verifies:
--  @1. Transceiver delay measurement saturates to 255 clock cycles.
--  @2. Secondary sampling point saturates to 510 clock cycles.
--
-- @Test sequence:
--  @1. Configure low Nominal Bit Rate, so that even TRV_DELAY = 255 fits within
--      single bit of Nominal bit-time. Configure Data bit time such that
--      TRV_DELAY = 255 and SSP_POS = 255 fits can be correctly sampled.
--      Configure TX -> RX Delay higher than 255.
--  @2. Generate CAN FD CAN frame with bit-rate shift. Send it by DUT node
--      and wait transmission is over.
--  @3. Read the frame from RX Buffer of Test Node. Check it matches transmitted
--      frame. Check that measured TRV_DELAY = 127 in DUT node.
--
-- @TestInfoEnd
--------------------------------------------------------------------------------
-- Revision History:
--    18.7.2024   Created file
--------------------------------------------------------------------------------

Library ctu_can_fd_tb;
context ctu_can_fd_tb.ieee_context;
context ctu_can_fd_tb.rtl_context;
context ctu_can_fd_tb.tb_common_context;

use ctu_can_fd_tb.feature_test_agent_pkg.all;

package ssp_saturation_ftest is
    procedure ssp_saturation_ftest_exec(
        signal      chn             : inout  t_com_channel
    );
end package;


package body ssp_saturation_ftest is

    procedure ssp_saturation_ftest_exec(
        signal      chn                     : inout  t_com_channel
    ) is
        variable TX_frame                   :     t_ctu_frame;
        variable RX_frame                   :     t_ctu_frame;

        variable frame_sent                 :     boolean;
        variable frames_match               :     boolean;

        variable trv_delay                  :     natural;

        variable bus_timing                 :     t_ctu_bit_time_cfg;
    begin

        -----------------------------------------------------------------------
        --  @1. Configure low Nominal Bit Rate, so that even TRV_DELAY = 255
        --      fits within single bit of Nominal bit-time. Configure Data bit
        --      time such that TRV_DELAY = 255 and SSP_POS = 255 fits can be
        --      correctly sampled. Configure TX -> RX Delay higher than 255.
        -----------------------------------------------------------------------
        info_m("Step 1");

        -- PH1_NBT = 400 cycles
        -- Bit Time (DBT) = 360 cycles
        bus_timing.tq_nbt     := 10;
        bus_timing.tq_dbt     := 10;

        bus_timing.prop_nbt   := 20;
        bus_timing.ph1_nbt    := 19;
        bus_timing.ph2_nbt    := 20;
        bus_timing.sjw_nbt    := 5;

        bus_timing.prop_dbt   := 12;
        bus_timing.ph1_dbt    := 11;
        bus_timing.ph2_dbt    := 12;
        bus_timing.sjw_dbt    := 5;

        ctu_turn(false, DUT_NODE, chn);
        ctu_turn(false, TEST_NODE, chn);

        ctu_set_bit_time_cfg(bus_timing, DUT_NODE, chn);
        ctu_set_bit_time_cfg(bus_timing, TEST_NODE, chn);

        -- SSP offset configured = 256.
        -- TX -> RX delay = 280.
        -- TRV_DELAY saturates to 255 (checked by step 3)
        -- Since TX -> RX Delay = 280, then we need SSP between:
        --   280 + 1 = 281
        --   280 + 360 = 640
        -- Only in this range SSP fits within the bit on the fly to be sampled correctly.
        -- With saturated SSP we are at 510 (255 + 255).
        -- Thus, sending frame sucessfully checks the saturation occurs

        -- TODO: We could extend this test to iterate over all all possible SSP offsets.
        --       Based on SSP position we should see:
        --            0 - 25    - Error frame
        --           26 - 255   - Sucessfull transmission
        ctu_set_ssp(ssp_meas_n_offset, x"FF", DUT_NODE, chn);
        ctu_set_ssp(ssp_meas_n_offset, x"FF", TEST_NODE, chn);

        ctu_turn(true, DUT_NODE, chn);
        ctu_turn(true, TEST_NODE, chn);

        ctu_wait_err_active(DUT_NODE, chn);
        ctu_wait_err_active(TEST_NODE, chn);

        -- Higher than 255 * 10 ns
        info_m("TRV_DELAY is: 2800 ns");
        set_transceiver_delay(2800 ns, DUT_NODE, chn);

        -----------------------------------------------------------------------
        -- @2. Generate CAN FD CAN frame with bit-rate shift. Send it by DUT
        --     Node and wait transmission is over.
        -----------------------------------------------------------------------
        info_m("Step 2");

        generate_can_frame(TX_frame);
        TX_frame.frame_format := FD_CAN;
        TX_frame.brs := BR_SHIFT;

        ctu_send_frame(TX_frame, 1, DUT_NODE, chn, frame_sent);
        ctu_wait_frame_sent(DUT_NODE, chn);

        -----------------------------------------------------------------------
        -- @3. Read the frame from RX Buffer of Test Node. Check it matches
        --     transmitted frame.
        --     Check that measured TRV_DELAY = 255 in DUT node.
        -----------------------------------------------------------------------
        info_m("Step 3");

        ctu_read_frame(RX_frame, TEST_NODE, chn);
        compare_can_frames(TX_frame, RX_frame, false, frames_match);
        check_m(frames_match, "TX/RX frame equal");

        ctu_get_trv_delay(trv_delay, DUT_NODE, chn);
        check_m(trv_delay = 255, "Transceiver delay is 255");

        ctu_wait_bus_idle(DUT_NODE, chn);
        ctu_wait_bus_idle(TEST_NODE, chn);

    end procedure;

end package body;
