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
--  @Purpose:
--    Functional coverage for CAN Core
--
--------------------------------------------------------------------------------
-- Revision History:
--    27.4.2025   Created file
--------------------------------------------------------------------------------

Library ctu_can_fd_tb;
context ctu_can_fd_tb.ieee_context;
context ctu_can_fd_tb.tb_common_context;
context ctu_can_fd_tb.rtl_context;

use ctu_can_fd_tb.clk_gen_agent_pkg.all;
use ctu_can_fd_tb.tb_shared_vars_pkg.all;

entity func_cov_can_core is
    port (
        -- DUT clock
        clk    :   in  std_logic
    );
end entity;

architecture tb of func_cov_can_core is

    alias tran_ident_type is
        << signal .tb_top_ctu_can_fd.dut.can_core_inst.tran_ident_type : std_logic >>;

    alias tran_frame_type is
        << signal .tb_top_ctu_can_fd.dut.can_core_inst.tran_ident_type : std_logic >>;

    alias tran_is_rtr is
        << signal .tb_top_ctu_can_fd.dut.can_core_inst.tran_is_rtr : std_logic >>;

    alias tran_frame_valid is
        << signal .tb_top_ctu_can_fd.dut.can_core_inst.tran_frame_valid : std_logic >>;

begin

    -- psl default clock is rising_edge(clk);

    -----------------------------------------------------------------------------------------------
    -- Transmitted frame combinations
    -----------------------------------------------------------------------------------------------

    -- psl tx_base_id_can_2_0_cov : cover
    --  {tran_ident_type  = BASE        and
    --   tran_frame_type  = NORMAL_CAN  and
    --   tran_is_rtr      = '0'         and
    --   tran_frame_valid = '1'};

    -- psl tx_extended_id_can_2_0_cov : cover
    --  {tran_ident_type  = EXTENDED    and
    --   tran_frame_type  = NORMAL_CAN  and
    --   tran_is_rtr      = '0'         and
    --   tran_frame_valid = '1'};

    -- psl tx_base_id_can_fd_cov : cover
    --  {tran_ident_type  = BASE        and
    --   tran_frame_type  = FD_CAN      and
    --   tran_is_rtr      = '0'         and
    --   tran_frame_valid = '1'};

    -- psl tx_extended_id_can_fd_cov : cover
    --  {tran_ident_type  = EXTENDED    and
    --   tran_frame_type  = FD_CAN      and
    --   tran_is_rtr      = '0'         and
    --   tran_frame_valid = '1'};

    -- psl tx_base_id_can_2_0_rtr_cov : cover
    --  {tran_ident_type  = BASE        and
    --   tran_frame_type  = NORMAL_CAN  and
    --   tran_is_rtr      = '1'         and
    --   tran_frame_valid = '1'};

    -- psl tx_extended_id_can_2_0_rtr_cov : cover
    --  {tran_ident_type  = EXTENDED    and
    --   tran_frame_type  = NORMAL_CAN  and
    --   tran_is_rtr      = '1'         and
    --   tran_frame_valid = '1'};

    -- psl tx_base_id_can_fd_rtr_cov : cover
    --  {tran_ident_type  = BASE        and
    --   tran_frame_type  = FD_CAN      and
    --   tran_is_rtr      = '1'         and
    --   tran_frame_valid = '1'};

    -- psl tx_extended_id_can_fd_rtr_cov : cover
    --  {tran_ident_type  = EXTENDED    and
    --   tran_frame_type  = FD_CAN      and
    --   tran_is_rtr      = '1'         and
    --   tran_frame_valid = '1'};

end architecture;