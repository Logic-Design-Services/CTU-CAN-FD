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
--  Maximal values of prescaler
--
-- @Verifies:
--  @1. Node is able to send frame succesfully with maximal possible prescaler
--      (nominal and data), as specified by datasheet.
--
-- @Test sequence:
--  @1. Configure highest possible prescaler as given by datasheet in both nodes.
--      Disable Secondary sampling point.
--  @3. Generate random frame which is FD frame with bit-rate shift. Send the
--      frame by DUT, receive it by Test node and check it.
--
-- @TestInfoEnd
--------------------------------------------------------------------------------
-- Revision History:
--   26.12.2019   Created file
--------------------------------------------------------------------------------

Library ctu_can_fd_tb;
context ctu_can_fd_tb.ieee_context;
context ctu_can_fd_tb.rtl_context;
context ctu_can_fd_tb.tb_common_context;

use ctu_can_fd_tb.feature_test_agent_pkg.all;

package prescaler_maximal_ftest is
    procedure prescaler_maximal_ftest_exec(
        signal      chn             : inout  t_com_channel
    );
end package;


package body prescaler_maximal_ftest is
    procedure prescaler_maximal_ftest_exec(
        signal      chn             : inout  t_com_channel
    ) is
        variable can_frame_1        :       t_ctu_frame;
        variable can_frame_2        :       t_ctu_frame;
        variable frame_sent         :       boolean := false;

        variable bus_timing         :       t_ctu_bit_time_cfg;

        variable clock_per_bit      :       natural := 0;

        variable clock_meas         :       natural := 0;
        variable frames_equal       :       boolean;

        variable tx_delay           :       time;
    begin

        -----------------------------------------------------------------------
        -- @1. Configure highest possible prescaler as given by datasheet in
        --     both nodes. Disable Secondary sampling point.
        -----------------------------------------------------------------------
        info_m("Step 1");

        ctu_turn(false, DUT_NODE, chn);
        ctu_turn(false, TEST_NODE, chn);

        bus_timing.prop_nbt := 2;
        bus_timing.ph1_nbt := 2;
        bus_timing.ph2_nbt := 2;
        bus_timing.sjw_nbt := 1;
        bus_timing.tq_nbt := 255;

        bus_timing.prop_dbt := 1;
        bus_timing.ph1_dbt := 1;
        bus_timing.ph2_dbt := 2;
        bus_timing.sjw_nbt := 1;
        bus_timing.tq_dbt := 255;

        ctu_set_bit_time_cfg(bus_timing, DUT_NODE, chn);
        ctu_set_bit_time_cfg(bus_timing, TEST_NODE, chn);

        ctu_turn(true, DUT_NODE, chn);
        ctu_turn(true, TEST_NODE, chn);

        ctu_wait_err_active(DUT_NODE, chn);
        ctu_wait_err_active(TEST_NODE, chn);

        info_m("CAN bus nominal bit-rate:");
        info_m("PROP: " & integer'image(bus_timing.prop_nbt));
        info_m("PH1: " & integer'image(bus_timing.ph1_nbt));
        info_m("PH2: " & integer'image(bus_timing.ph2_nbt));
        info_m("SJW: " & integer'image(bus_timing.sjw_nbt));

        info_m("CAN bus data bit-rate:");
        info_m("PROP: " & integer'image(bus_timing.prop_dbt));
        info_m("PH1: " & integer'image(bus_timing.ph1_dbt));
        info_m("PH2: " & integer'image(bus_timing.ph2_dbt));
        info_m("SJW: " & integer'image(bus_timing.sjw_dbt));

        -----------------------------------------------------------------------
        -- @2. Generate random frame which is FD frame with bit-rate shift.
        --     Send the frame by DUT, receive it by Test node and check it.
        -----------------------------------------------------------------------
        info_m("Step 2");

        generate_can_frame(can_frame_1);
        info_m("Generated frame");
        -- Make frame as short as possible not to have too long test time.
        can_frame_1.frame_format := FD_CAN;
        can_frame_1.brs := BR_SHIFT;
        can_frame_1.rtr := NO_RTR_FRAME;
        can_frame_1.ident_type := BASE;
        can_frame_1.data_length := 0;
        can_frame_1.identifier := can_frame_1.identifier mod (2 ** 11);
        can_frame_1.dlc := "0000";
        dlc_to_rwcnt(can_frame_1.dlc, can_frame_1.rwcnt);

        ctu_send_frame(can_frame_1, 1, DUT_NODE, chn, frame_sent);
        ctu_wait_frame_sent(TEST_NODE, chn);
        ctu_read_frame(can_frame_2, TEST_NODE, chn);

        compare_can_frames(can_frame_1, can_frame_2, false, frames_equal);
        check_m(frames_equal, "TX/RX frame equal!");

  end procedure;

end package body;