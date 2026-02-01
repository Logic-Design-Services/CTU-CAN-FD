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
--  Arbitration lost capture - RTR bit after Extended Identifier.
--
-- @Verifies:
--  @1. CAN RTR frame with extended identifier loses arbitration against
--      CAN data frame with the same identifier. 
--  @3. Arbitration lost capture position on RTR bit after Extended identifier.
--
-- @Test sequence:
--  @1. Configure both Nodes to one-shot mode.
--  @2. Generate two CAN frames with both Extended matching Identifiers.
--      Frame 1 is RTR frame, frame 2 is data frame.
--  @3. Wait till sample point in DUT. Send Frame 1 by DUT and Frame 2 by
--      Test node.
--  @4. Wait till arbitration field in DUT. Wait till sample point 31 times
--      (11 Base ID + RTR/SRR + IDE + ID Extension + RTR). Check DUT is
--      transmitting Recessive, Check Test node is transmitting Dominant. Check
--      DUT lost arbitration. Check Test node is still transmitter. Read ALC
--      from DUT and check it.
--
-- @TestInfoEnd
--------------------------------------------------------------------------------
-- Revision History:
--    02.10.2019   Created file
--------------------------------------------------------------------------------

Library ctu_can_fd_tb;
context ctu_can_fd_tb.ieee_context;
context ctu_can_fd_tb.rtl_context;
context ctu_can_fd_tb.tb_common_context;

use ctu_can_fd_tb.feature_test_agent_pkg.all;

package alc_rtr_ext_id_ftest is
    procedure alc_rtr_ext_id_ftest_exec(
        signal      chn             : inout  t_com_channel
    );
end package;


package body alc_rtr_ext_id_ftest is
    procedure alc_rtr_ext_id_ftest_exec(
        signal      chn             : inout  t_com_channel
    ) is
        variable alc                :       natural;

        -- Generated frames
        variable frame_1            :     t_ctu_frame;
        variable frame_2            :     t_ctu_frame;
        variable frame_rx           :     t_ctu_frame;

        -- Node status
        variable stat_1             :     t_ctu_status;
        variable stat_2             :     t_ctu_status;

        variable id_vect            :     std_logic_vector(28 downto 0);
    begin

        -----------------------------------------------------------------------
        -- @1. Configure both Nodes to one-shot mode.
        -----------------------------------------------------------------------
        info_m("Step 1: Configure one -shot mode");
        ctu_set_retr_limit(true, 0, DUT_NODE, chn);
        ctu_set_retr_limit(true, 0, TEST_NODE, chn);

        -----------------------------------------------------------------------
        -- @2. Generate two CAN frames with both Extended matching Identifiers.
        --     Frame 1 is RTR frame, frame 2 is data frame.
        -----------------------------------------------------------------------
        info_m("Step 2: Generate CAN frames with matching IDs!");
        generate_can_frame(frame_1);
        generate_can_frame(frame_2);
        
        frame_1.ident_type := EXTENDED;
        frame_2.ident_type := EXTENDED;
        frame_1.rtr := RTR_FRAME;
        frame_2.rtr := NO_RTR_FRAME;
        frame_1.frame_format := NORMAL_CAN;
        frame_2.frame_format := NORMAL_CAN;
        frame_2.identifier := frame_1.identifier;

        ------------------------------------------------------------------------
        -- @3. Wait till sample point in DUT. Send Frame 1 by DUT and 
        --    Frame 2 by Test node.
        ------------------------------------------------------------------------
        info_m("Step 3: Send frames");
        ctu_put_tx_frame(frame_1, 1, DUT_NODE, chn);
        ctu_put_tx_frame(frame_2, 1, TEST_NODE, chn);
        ctu_wait_sample_point(DUT_NODE, chn);

        ctu_give_txt_cmd(buf_set_ready, 1, DUT_NODE, chn);
        ctu_give_txt_cmd(buf_set_ready, 1, TEST_NODE, chn);

        -----------------------------------------------------------------------
        -- @4. Wait till arbitration field in DUT. Wait till sample point 31
        --     times (11 Base ID + RTR/SRR + IDE + ID Extension + RTR). Check
        --     DUT is transmitting Recessive, Check Test node is transmitting
        --     Dominant. Check DUT lost arbitration. Check Test node is still
        --     transmitter. Read ALC from DUT and check it.
        -----------------------------------------------------------------------
        info_m("Step 4: Check arbitration lost on RTR after Extended ID");
        ctu_wait_ff(ff_arbitration, DUT_NODE, chn);
        for i in 0 to 31 loop
            ctu_wait_sample_point(DUT_NODE, chn);
        end loop;
        check_can_tx(DOMINANT, TEST_NODE, "Dominant RTR transmitted by Test Node!", chn);
        check_can_tx(RECESSIVE, DUT_NODE, "Recessive RTR transmitted by DUT!", chn);
        wait for 20 ns; -- To account for trigger processing
        
        ctu_get_status(stat_1, DUT_NODE, chn);
        check_m(stat_1.receiver, "DUT lost arbitration!");
        ctu_get_status(stat_2, TEST_NODE, chn);
        check_m(stat_2.transmitter, "Test node transmitter!");
        
        ctu_get_alc(alc, DUT_NODE, chn);
        check_m(alc = 32, "Arbitration lost at correct bit by DUT!");

        ctu_wait_bus_idle(DUT_NODE, chn);
        ctu_wait_bus_idle(TEST_NODE, chn);

  end procedure;

end package body;
