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
--  Test to achieve full toggle coverage on ERR_NORM, ERR_FD, RX_FR_CTR and
--  TX_FR_CTR register.
--
-- @Verifies:
--  @1. Full width of ERR_NORM, ERR_FD, RX_FR_CTR and TX_FR_CTR can be accessed
--      from register map.
--
-- @Test sequence:
--  @1. Check DUT supports frame counters. If not, the test will skip forcing
--      of RX_FR_CTR and TX_FR_CTR.
--      Force ERR_NORM, ERR_FD, RX_FR_CTR and TX_FR_CTR to a random value.
--  @2. Read expected value of ERR_NORM, ERR_FD, RX_FR_CTR and TX_FR_CTR
--      from DUT and check it matches value forced to DUT. Value forced to
--      DUT obtained from TB scratchpad (placed there by TB).
--  @3. Release ERR_NORM, ERR_FD, RX_FR_CTR and TX_FR_CTR to a random value.
--
-- @TestInfoEnd
--------------------------------------------------------------------------------
-- Revision History:
--    18.10.2019   Created file
--------------------------------------------------------------------------------

Library ctu_can_fd_tb;
context ctu_can_fd_tb.ieee_context;
context ctu_can_fd_tb.rtl_context;
context ctu_can_fd_tb.tb_common_context;

use ctu_can_fd_tb.feature_test_agent_pkg.all;

package counters_toggle_ftest is
    procedure counters_toggle_ftest_exec(
        signal      chn             : inout  t_com_channel
    );
end package;


package body counters_toggle_ftest is

    procedure counters_toggle_ftest_exec(
        signal      chn             : inout  t_com_channel
    ) is
        variable r_data : std_logic_vector(31 downto 0) := (OTHERS => '0');

        variable exp_tx_err_ctr   : std_logic_vector(31 downto 0);
        variable exp_rx_err_ctr   : std_logic_vector(31 downto 0);
        variable exp_norm_err_ctr : std_logic_vector(15 downto 0);
        variable exp_data_err_ctr : std_logic_vector(15 downto 0);

        variable hw_cfg           : t_ctu_hw_cfg;
    begin

        -----------------------------------------------------------------------
        -- @1. Check DUT supports frame counters. If not, the test will skip
        --     forcing of RX_FR_CTR and TX_FR_CTR.
        --     Force ERR_NORM, ERR_FD, RX_FR_CTR and TX_FR_CTR to a random value.
        -----------------------------------------------------------------------
        info_m("Step 1: Force ERR_NORM, ERR_FD, RX_FR_CTR and TX_FR_CTR");

        ctu_get_hw_config(hw_cfg, DUT_NODE, chn);

        rand_logic_vect_v(exp_tx_err_ctr, 0.5);
        rand_logic_vect_v(exp_rx_err_ctr, 0.5);
        rand_logic_vect_v(exp_norm_err_ctr, 0.5);
        rand_logic_vect_v(exp_data_err_ctr, 0.5);

        if (hw_cfg.sup_traffic_ctrs) then
            tb_force.force_tx_counter(exp_tx_err_ctr);
            tb_force.force_rx_counter(exp_rx_err_ctr);
        end if;
        tb_force.force_err_norm(exp_norm_err_ctr);
        tb_force.force_err_fd(exp_data_err_ctr);

        -----------------------------------------------------------------------
        -- @1. Read expected value of ERR_NORM, ERR_FD, RX_FR_CTR and
        --     TX_FR_CTR from DUT and check it matches value forced to DUT.
        --     Value forced to DUT obtained from TB scratchpad
        --     (placed there by TB).
        -----------------------------------------------------------------------
        info_m("Step 2: Check ERR_NORM, ERR_FD, RX_FR_CTR and TX_FR_CTR");

        ctu_read(r_data, ERR_NORM_ADR, DUT_NODE, chn);
        check_m(r_data(ERR_NORM_VAL_H downto ERR_NORM_VAL_L) = exp_norm_err_ctr,
                "ERR_NORM is OK");
        check_m(r_data(ERR_FD_VAL_H downto ERR_FD_VAL_L) = exp_data_err_ctr,
                "ERR_FD is OK");

        if (hw_cfg.sup_traffic_ctrs) then
            ctu_read(r_data, TX_FR_CTR_ADR, DUT_NODE, chn);
            check_m(r_data = exp_tx_err_ctr, "TX_FR_CTR is OK");

            ctu_read(r_data, RX_FR_CTR_ADR, DUT_NODE, chn);
            check_m(r_data = exp_rx_err_ctr, "RX_FR_CTR is OK");
        end if;

        -----------------------------------------------------------------------
        -- @3. Release ERR_NORM, ERR_FD, RX_FR_CTR and TX_FR_CTR to a random value.
        -----------------------------------------------------------------------
        info_m("Step 3: Release ERR_NORM, ERR_FD, RX_FR_CTR and TX_FR_CTR");

        if (hw_cfg.sup_traffic_ctrs) then
            tb_force.release_tx_counter;
            tb_force.release_rx_counter;
        end if;
        tb_force.release_err_norm;
        tb_force.release_err_fd;

  end procedure;

end package body;
