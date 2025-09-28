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
--  Arbitration lost capture - SRR/RTR bit feature test 2.
--
-- @Verifies:
--  @1. CAN FD frame wins over CAN 2.0 RTR frame with the same identifier.
--  @2. CAN FD frame wins over CAN frame with Extended identifier with the same
--      base identifier.
--  @3. Arbitration lost capture position on SRR/RTR bit after Base identifier.
--
-- @Test sequence:
--  @1. Configure both Nodes to one-shot mode.
--  @2. Generate two CAN frames: Frame 1 - CAN FD Base frame, Frame 2 - CAN 2.0
--      RTR frame with Base ID. Base identifier of both CAN frames is matching!
--  @3. Wait till sample point in DUT. Send Frame 1 by Test Node and Frame 2 by
--      DUT.
--  @4. Wait till arbitration field in Test Node. Wait till sample point 12 times
--      (11 Base ID + RTR/SRR). Check Test Node is transmitting dominant, Check
--      DUT is transmitting recessive. Check DUT lost arbitration. Check
--      Test Node is still transmitter. Read ALC from DUT and check it.
--  @5. Generate two CAN Frames: Frame 1 - CAN FD frame with Base ID. Frame 2 -
--      Frame with Extended Identifier.
--  @6. Wait till sample point in Test Node. Send Frame 1 by Test Node and Frame 2
--      by DUT.
--  @7. Wait till arbitration field in DUT. Wait till sample point 12 times
--      (11 Base ID + RTR/SRR). Check DUT is transmitting recessive, Check
--      Test Node is transmitting dominant. Check Test node lost arbitration.
--      Check Test Node is still transmitter. Read ALC from DUT and check it.
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

package alc_srr_rtr_2_ftest is
    procedure alc_srr_rtr_2_ftest_exec(
        signal      chn             : inout  t_com_channel
    );
end package;


package body alc_srr_rtr_2_ftest is
    procedure alc_srr_rtr_2_ftest_exec(
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
        
        ctu_set_retr_limit(true, 0, TEST_NODE, chn);
        ctu_set_retr_limit(true, 0, DUT_NODE, chn);

        -----------------------------------------------------------------------
        -- @2. Generate two CAN frames: Frame 1 - CAN FD Base frame, Frame 2 - 
        --    CAN 2.0 RTR frame with Base ID. Base identifier of both CAN 
        --    frames is matching!
        -----------------------------------------------------------------------
        info_m("Step 2: Generate CAN frames with matching IDs!");
        
        generate_can_frame(frame_1);
        generate_can_frame(frame_2);
        
        frame_1.ident_type := BASE;
        frame_2.ident_type := BASE;
        frame_2.rtr := RTR_FRAME;
        frame_1.frame_format := FD_CAN;
        frame_2.frame_format := NORMAL_CAN;
        frame_2.identifier := (frame_2.identifier mod 2**11);
        frame_1.identifier := frame_2.identifier;

        ------------------------------------------------------------------------
        -- @3. Wait till sample point in Test Node. Send Frame 1 by Test Node and 
        --    Frame 2 by DUT.
        ------------------------------------------------------------------------
        info_m("Step 3: Send frames");
        
        ctu_put_tx_frame(frame_1, 1, TEST_NODE, chn);
        ctu_put_tx_frame(frame_2, 1, DUT_NODE, chn);
        ctu_wait_sample_point(TEST_NODE, chn);

        ctu_give_txt_cmd(buf_set_ready, 1, TEST_NODE, chn);
        ctu_give_txt_cmd(buf_set_ready, 1, DUT_NODE, chn);

        -----------------------------------------------------------------------
        -- @4. Wait till arbitration field in Test Node. Wait till sample point
        --    12 times (11 Base ID + RTR/SRR). Check Test Node is transmitting
        --    dominant, Check DUT is transmitting recessive. Check DUT 
        --    lost arbitration. Check Test Node is still transmitter. Read ALC
        --    from DUT and check it.
        -----------------------------------------------------------------------
        info_m("Step 4: Check arbitration lost on SRR/RTR");
        
        ctu_wait_frame_field(pc_deb_arbitration, DUT_NODE, chn);
        for i in 0 to 11 loop
            ctu_wait_sample_point(DUT_NODE, chn);
        end loop;
        check_can_tx(DOMINANT, TEST_NODE, "Dominant SRR transmitted!", chn);
        check_can_tx(RECESSIVE, DUT_NODE, "Recessive RTR transmitted!", chn);
        wait for 20 ns; -- To account for trigger processing
        
        ctu_get_status(stat_2, DUT_NODE, chn);
        check_m(stat_2.receiver, "DUT lost arbitration!");
        ctu_get_status(stat_1, TEST_NODE, chn);
        check_m(stat_1.transmitter, "Test Node transmitter!");
        
        ctu_get_alc(alc, DUT_NODE, chn);
        check_m(alc = 12, "Arbitration lost at correct bit by DUT!");

        ctu_wait_bus_idle(TEST_NODE, chn);
        ctu_wait_bus_idle(DUT_NODE, chn);

        -----------------------------------------------------------------------
        -- @5. Generate two CAN Frames: Frame 1 - CAN FD frame with Base ID. 
        --    Frame 2 - Frame with Extended Identifier.
        -----------------------------------------------------------------------
        info_m("Step 5: Generate frames");
        
        generate_can_frame(frame_1);
        generate_can_frame(frame_2);

        frame_1.identifier := (frame_1.identifier mod 2**11);
        frame_1.frame_format := FD_CAN;
        frame_1.ident_type := BASE;
        
        id_vect := std_logic_vector(to_unsigned(frame_1.identifier, 29));

        -- Shift base ID up for extended id to match Base ID of Test node!
        id_vect := id_vect(10 downto 0) & "000000000000000000";
        frame_2.identifier := to_integer(unsigned(id_vect));
        frame_2.ident_type := EXTENDED;

        -----------------------------------------------------------------------
        -- @6. Wait till sample point in Test Node. Send Frame 1 by Test node 
        --     and Frame 2 by DUT.
        -----------------------------------------------------------------------
        info_m("Step 6: Send frames");
        
        ctu_put_tx_frame(frame_1, 1, TEST_NODE, chn);
        ctu_put_tx_frame(frame_2, 1, DUT_NODE, chn);
        ctu_wait_sample_point(TEST_NODE, chn);
        
        ctu_give_txt_cmd(buf_set_ready, 1, TEST_NODE, chn);
        ctu_give_txt_cmd(buf_set_ready, 1, DUT_NODE, chn);
        
        -----------------------------------------------------------------------
        -- @7. Wait till arbitration field in DUT. Wait till sample point 12
        --    times (11 Base ID + RTR/SRR). Check DUT is transmitting 
        --    recessive, Check Test Node is transmitting dominant. Check DUT
        --    lost arbitration. Check Test Node is still transmitter. Read ALC 
        --    from DUT and check it.
        -----------------------------------------------------------------------
        info_m("Step 7: Check arbitration lost on SRR/RTR");
        
        ctu_wait_frame_field(pc_deb_arbitration, DUT_NODE, chn);
        for i in 0 to 11 loop
            ctu_wait_sample_point(DUT_NODE, chn);
        end loop;
        check_can_tx(DOMINANT, TEST_NODE, "Dominant RTR transmitted!", chn);
        check_can_tx(RECESSIVE, DUT_NODE, "Recessive RTR transmitted!", chn);
        
        -- Wait for up to one bit time since triggers can be shifted! 
        wait for 1000 ns;
        
        ctu_get_status(stat_2, DUT_NODE, chn);
        check_m(stat_2.receiver, "DUT lost arbitration!");
        ctu_get_status(stat_1, TEST_NODE, chn);
        check_m(stat_1.transmitter, "Test Node transmitter!");
        
        ctu_get_alc(alc, DUT_NODE, chn);
        check_m(alc = 12, "Arbitration lost at correct bit by DUT!");
        
        ctu_wait_bus_idle(TEST_NODE, chn);
        ctu_wait_bus_idle(DUT_NODE, chn);

  end procedure;

end package body;
