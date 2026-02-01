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
--  STATUS[TXS] feature test.
--
-- @Verifies:
--  @1. STATUS[TXS] is set when unit is transmitter.
--  @2. STATUS[TXS] is not set when unit is receiver.
--
-- @Test sequence:
--  @1. Send frame by DUT. Wait until SOF starts and check that STATUS[TXS] is
--      not set till SOF. From SOF further monitor STATUS[TXS] and check it set
--      until the end of Intermission. Check that after the end of intermission,
--      STATUS[TXS] is not set anymore.
--  @2. Send frame by Test node. Monitor STATUS[TXS] of DUT until Intermission
--      and check STATUS[TXS] is not set. Monitor until the end of intermission
--      and check STATUS[TXS] is not set.
--
-- @TestInfoEnd
--------------------------------------------------------------------------------
-- Revision History:
--    31.10.2019   Created file
--------------------------------------------------------------------------------

Library ctu_can_fd_tb;
context ctu_can_fd_tb.ieee_context;
context ctu_can_fd_tb.rtl_context;
context ctu_can_fd_tb.tb_common_context;

use ctu_can_fd_tb.feature_test_agent_pkg.all;
use ctu_can_fd_tb.mem_bus_agent_pkg.all;

package status_txs_ftest is
    procedure status_txs_ftest_exec(
        signal      chn             : inout  t_com_channel
    );
end package;


package body status_txs_ftest is
    procedure status_txs_ftest_exec(
        signal      chn             : inout  t_com_channel
    ) is
        -- Generated frames
        variable frame_1            :     t_ctu_frame;

        -- Node status
        variable stat_1             :     t_ctu_status;

        variable ff             :     t_ctu_frame_field;
        variable frame_sent         :     boolean;
    begin

        -----------------------------------------------------------------------
        --  @1. Send frame by DUT. Wait until SOF starts and check that
        --     STATUS[TXS] is not set till SOF. From SOF further monitor
        --     STATUS[TXS] and check it set until the end of Intermission.
        --     Check that after the end of intermission, STATUS[TXS] is not set
        --     anymore.
        -----------------------------------------------------------------------
        info_m("Step 1");
        generate_can_frame(frame_1);
        ctu_send_frame(frame_1, 1, DUT_NODE, chn, frame_sent);

        ctu_get_curr_ff(ff, DUT_NODE, chn);
        mem_bus_agent_disable_transaction_reporting(chn);
        while (ff /= ff_arbitration) loop
            ctu_get_curr_ff(ff, DUT_NODE, chn);
        end loop;

        while (ff /= ff_intermission) loop
            wait for 200 ns;
            ctu_get_status(stat_1, DUT_NODE, chn);

            ctu_get_curr_ff(ff, DUT_NODE, chn);
            if (ff /= ff_intermission) then
                check_m(stat_1.transmitter, "DUT transmitter!");
            end if;
        end loop;
        mem_bus_agent_enable_transaction_reporting(chn);

        -- There should be no Suspend, Overload frames, so after intermission
        -- we should go to idle
        ctu_wait_not_ff(ff_intermission, DUT_NODE, chn);
        ctu_get_status(stat_1, DUT_NODE, chn);
        check_false_m(stat_1.transmitter, "DUT not transmitter in idle!");

        ctu_wait_bus_idle(DUT_NODE, chn);
        ctu_wait_bus_idle(TEST_NODE, chn);

        -----------------------------------------------------------------------
        -- @2. Send frame by Test node. Monitor STATUS[TXS] of DUT until Inter-
        --    mission and check STATUS[TXS] is not set. Monitor until the end
        --    of intermission and check STATUS[TXS] is not set.
        -----------------------------------------------------------------------
        info_m("Step 2");
        generate_can_frame(frame_1);
        ctu_send_frame(frame_1, 2, TEST_NODE, chn, frame_sent);

        mem_bus_agent_disable_transaction_reporting(chn);
        while (ff /= ff_intermission) loop
            wait for 200 ns;
            ctu_get_status(stat_1, DUT_NODE, chn);

            ctu_get_curr_ff(ff, DUT_NODE, chn);
            check_false_m(stat_1.transmitter, "DUT not transmitter!");
        end loop;
        mem_bus_agent_enable_transaction_reporting(chn);

  end procedure;

end package body;
