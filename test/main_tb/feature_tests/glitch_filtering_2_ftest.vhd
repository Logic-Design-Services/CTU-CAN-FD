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
--  Glitch filtering 2 feature test.
--
-- @Verifies:
--  @1. When device is configured as CAN FD Tolerant or CAN FD Enabled,
--      dominant edge pulse on CAN RX longer than one nominal time quanta
--      but not during sample point causes reset of Integration counter
--      during Bus integration.
--
-- @Test sequence:
--  @1. Iterate 4 scenarios of protocol compliance:
--          A) CAN 2.0:                 MODE[FDE] = 0 , SETTINGS[PEX] = 0
--          B) CAN FD Tolerant:         MODE[FDE] = 0 , SETTINGS[PEX] = 1
--          C) CAN FD Eanbled:          MODE[FDE] = 1 , SETTINGS[PEX] = 0
--          D) CAN FD Enabled + PEX:    MODE[FDE] = 1 , SETTINGS[PEX] = 1
--      @1.1 Disable DUT to make it "Bus-off". Configure DUTs nominal bit
--           time presaler to 10 clock cycles. Enable DUT again.
--      @1.2 Wait for 5 bits, and till DUTs sample point. Wait for 15 system clock
--           periods and insert dominant glitch lasting 15 clock cycles.
--      @1.3 Wait for 7 more bits. Check that in Scenario A, DUT became Error
--           active. In all other scenarios, check DUT is still Bus-off.
--
-- @TestInfoEnd
--------------------------------------------------------------------------------
-- Revision History:
--    26.12.2025   Created file
--------------------------------------------------------------------------------

Library ctu_can_fd_tb;
context ctu_can_fd_tb.ieee_context;
context ctu_can_fd_tb.rtl_context;
context ctu_can_fd_tb.tb_common_context;

use ctu_can_fd_tb.feature_test_agent_pkg.all;
use ctu_can_fd_tb.clk_gen_agent_pkg.all;

package glitch_filtering_2_ftest is
    procedure glitch_filtering_2_ftest_exec(
        signal      chn             : inout  t_com_channel
    );
end package;


package body glitch_filtering_2_ftest is
    procedure glitch_filtering_2_ftest_exec(
        signal      chn             : inout  t_com_channel
    ) is
        variable bus_timing         :     t_ctu_bit_time_cfg;
        variable fault_state        :     t_ctu_fault_state;
        variable mode_1             :     t_ctu_mode := t_ctu_mode_rst_val;
    begin

        -------------------------------------------------------------------------------------------
        --  @1. Iterate 4 scenarios of protocol compliance:
        --          A) CAN 2.0:                 MODE[FDE] = 0 , SETTINGS[PEX] = 0
        --          B) CAN FD Tolerant:         MODE[FDE] = 0 , SETTINGS[PEX] = 1
        --          C) CAN FD Eanbled:          MODE[FDE] = 1 , SETTINGS[PEX] = 0
        --          D) CAN FD Enabled + PEX:    MODE[FDE] = 1 , SETTINGS[PEX] = 1
        -------------------------------------------------------------------------------------------
        for settings_pex in boolean'left to boolean'right loop
        for mode_fde in boolean'left to boolean'right loop
            info_m("Step 1");

            -- Disable Test node -> Not needed in the test
            ctu_turn(false, TEST_NODE, chn);

            info_m("SETTINGS[PEX]=" & boolean'image(settings_pex));
            info_m("MODE[FDE]=" & boolean'image(mode_fde));

            ---------------------------------------------------------------------------------------
            -- @1.1 Disable DUT to make it "Bus-off". Configure DUTs nominal bit
            --      time presaler to 10 clock cycles. Enable DUT again.
            ---------------------------------------------------------------------------------------
            info_m("Step 2.1");

            ctu_turn(false, DUT_NODE, chn);

            bus_timing.prop_nbt := 5;
            bus_timing.ph1_nbt := 5;
            bus_timing.ph2_nbt := 5;
            bus_timing.sjw_nbt := 3;
            bus_timing.tq_nbt := 10;

            bus_timing.prop_dbt := 5;
            bus_timing.ph1_dbt := 3;
            bus_timing.ph2_dbt := 3;
            bus_timing.sjw_nbt := 2;
            bus_timing.tq_dbt := 2;
            ctu_set_bit_time_cfg(bus_timing, DUT_NODE, chn);

            mode_1.flexible_data_rate := mode_fde;
            mode_1.pex_support := settings_pex;
            ctu_set_mode(mode_1, DUT_NODE, chn);

            ctu_turn(true, DUT_NODE, chn);

            ---------------------------------------------------------------------------------------
            -- @1.2 Wait for 5 bits, and till DUTs sample point. Wait for 15 system clock
            --      periods and insert dominant glitch lasting 15 clock cycles.
            ---------------------------------------------------------------------------------------
            for i in 1 to 5 loop
                ctu_wait_sample_point(DUT_NODE, chn);
            end loop;

            for i in 1 to 15 loop
                clk_agent_wait_cycle(chn);
            end loop;

            force_bus_level(DOMINANT, chn);

            for i in 1 to 15 loop
                clk_agent_wait_cycle(chn);
            end loop;

            release_bus_level(chn);

            ---------------------------------------------------------------------------------------
            -- @1.3 Wait for 7 more bits. Check that in Scenario A, DUT became Error
            --      active. In all other scenarios, check DUT is still Bus-off.
            ---------------------------------------------------------------------------------------
            for i in 1 to 7 loop
                ctu_wait_sample_point(DUT_NODE, chn);
            end loop;

            ctu_get_fault_state(fault_state, DUT_NODE, chn);

            if (settings_pex = false and mode_fde = false) then
                check_m(fault_state = fc_error_active, "Error active!");
            else
                check_m(fault_state = fc_bus_off, "Bus-off");
            end if;

        end loop;
        end loop;

  end procedure;

end package body;
