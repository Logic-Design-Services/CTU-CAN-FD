--------------------------------------------------------------------------------
--
-- CTU CAN FD IP Core
-- Copyright (C) 2021-2023 Ondrej Ille
-- Copyright (C) 2023-2026 Logic Design Services Ltd.
-- Copyright (C) 2026-     SELOSYS Ltd.
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
--  Feature test which disables node while it is transmitting frame.
--
-- @Verifies:
--  @1. When attempting to disable DUT while transmission is in progress,
--      DUT will finish transmission of current frame.
--
-- @Test sequence:
--  @1. Generate random frame and send it by DUT.
--  @2. Wait until frame starts in DUT, and disable DUT.
--  @3. Check that DUT is still enabled, and that it is transmitter.
--  @4. Poll until DUT is disabled. Check that while DUT is enabled, the
--      DUT is still a transmitter.
--  @5. Read frame from Test Node and check it matches transmitted frame.
--
-- @TestInfoEnd
--------------------------------------------------------------------------------
-- Revision History:
--    29.05.2021   Created file
--------------------------------------------------------------------------------

Library ctu_can_fd_tb;
context ctu_can_fd_tb.ieee_context;
context ctu_can_fd_tb.rtl_context;
context ctu_can_fd_tb.tb_common_context;

use ctu_can_fd_tb.feature_test_agent_pkg.all;

package disable_in_tx_ftest is
    procedure disable_in_tx_ftest_exec(
        signal      chn             : inout  t_com_channel
    );
end package;


package body disable_in_tx_ftest is

    procedure disable_in_tx_ftest_exec(
        signal      chn             : inout  t_com_channel
    ) is
        variable can_frame  : t_ctu_frame;
        variable can_frame_2: t_ctu_frame;
        variable outcome    : boolean;
        variable frame_sent : boolean;
        variable enabled    : boolean;
        variable status     : t_ctu_status;
    begin

        -----------------------------------------------------------------------
        -- @1. Generate random frame and send it by DUT.
        -----------------------------------------------------------------------
        info_m("Step 1");

        generate_can_frame(can_frame);
        ctu_send_frame(can_frame, 1, DUT_NODE, chn, frame_sent);
        
        -----------------------------------------------------------------------
        -- @2. Wait until frame starts in DUT, and disable DUT.
        -----------------------------------------------------------------------
        info_m("Step 2");

        ctu_wait_ff(ff_sof, DUT_NODE, chn);
        ctu_turn(false, DUT_NODE, chn);

        -----------------------------------------------------------------------
        -- @3. Check that DUT is still enabled, and that it is transmitter.
        -----------------------------------------------------------------------
        info_m("Step 3");

        ctu_is_enabled(enabled, DUT_NODE, chn);
        check_m(enabled, "DUT still enabled after disable request!");

        ctu_get_status(status, DUT_NODE, chn);
        check_m(status.transmitter, "DUT is transmitter!");

        -----------------------------------------------------------------------
        -- @4. Poll until DUT is disabled. Check that while DUT is enabled,
        --     the DUT is still a transmitter.
        -----------------------------------------------------------------------
        info_m("Step 4");

        loop
            ctu_get_status(status, DUT_NODE, chn);
            ctu_is_enabled(enabled, DUT_NODE, chn);
            exit when (not enabled);
            check_m(status.transmitter, "DUT transmitter while enabled!");
        end loop;

        -----------------------------------------------------------------------
        -- @5. Read frame from Test Node and check it matches transmitted
        --     frame.
        -----------------------------------------------------------------------
        info_m("Step 5");

        ctu_wait_bus_idle(TEST_NODE, chn);
        ctu_wait_bus_idle(DUT_NODE, chn);

        ctu_read_frame(can_frame_2, TEST_NODE, chn);
        compare_can_frames(can_frame, can_frame_2, false, outcome);
        check_m(outcome, "TX/RX frames equal");

  end procedure;

end package body;
