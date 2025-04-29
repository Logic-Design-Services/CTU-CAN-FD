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
--    Functional coverage for Prescaler
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

entity func_cov_prescaler is
    port (
        -- DUT clock
        clk    :   in  std_logic
    );
end entity;

architecture tb of func_cov_prescaler is

    -----------------------------------------------------------------------------------------------
    -- Aliases to "prescaler" top
    -----------------------------------------------------------------------------------------------

    alias sp_control is
        << signal .tb_top_ctu_can_fd.dut.prescaler_inst.sp_control : std_logic_vector(1 downto 0) >>;

    alias tseg1_nbt is
        << signal .tb_top_ctu_can_fd.dut.prescaler_inst.tseg1_nbt : std_logic_vector(7 downto 0) >>;

    alias tseg2_nbt is
        << signal .tb_top_ctu_can_fd.dut.prescaler_inst.tseg2_nbt : std_logic_vector(5 downto 0) >>;

    alias tseg1_dbt is
        << signal .tb_top_ctu_can_fd.dut.prescaler_inst.tseg1_dbt : std_logic_vector(6 downto 0) >>;

    alias tseg2_dbt is
        << signal .tb_top_ctu_can_fd.dut.prescaler_inst.tseg2_dbt : std_logic_vector(4 downto 0) >>;

    alias brp_nbt is
        << signal .tb_top_ctu_can_fd.dut.prescaler_inst.brp_nbt : std_logic_vector(7 downto 0) >>;

    alias brp_dbt is
        << signal .tb_top_ctu_can_fd.dut.prescaler_inst.brp_dbt : std_logic_vector(7 downto 0) >>;

    alias resync_edge_valid is
        << signal .tb_top_ctu_can_fd.dut.prescaler_inst.resync_edge_valid : std_logic >>;

    alias is_tseg1 is
        << signal .tb_top_ctu_can_fd.dut.prescaler_inst.is_tseg1 : std_logic >>;

    alias is_tseg2 is
        << signal .tb_top_ctu_can_fd.dut.prescaler_inst.is_tseg2 : std_logic >>;

    -----------------------------------------------------------------------------------------------
    -- Aliases to "synchronisation_checker" top
    -----------------------------------------------------------------------------------------------
    alias sync_flag is
        << signal .tb_top_ctu_can_fd.dut.prescaler_inst.synchronisation_checker_inst.sync_flag : std_logic >>;

    alias h_sync_edge is
        << signal .tb_top_ctu_can_fd.dut.prescaler_inst.synchronisation_checker_inst.h_sync_edge : std_logic >>;

    alias resync_edge is
        << signal .tb_top_ctu_can_fd.dut.prescaler_inst.synchronisation_checker_inst.resync_edge : std_logic >>;

    alias h_sync_edge_valid is
        << signal .tb_top_ctu_can_fd.dut.prescaler_inst.synchronisation_checker_inst.h_sync_edge_valid : std_logic >>;

    -----------------------------------------------------------------------------------------------
    -- Aliases to "trigger_generator" top
    -----------------------------------------------------------------------------------------------

    alias rx_trig_req_q is
        << signal .tb_top_ctu_can_fd.dut.prescaler_inst.trigger_generator_inst.rx_trig_req_q : std_logic >>;

    alias tx_trig_req is
        << signal .tb_top_ctu_can_fd.dut.prescaler_inst.trigger_generator_inst.tx_trig_req : std_logic >>;

begin

    -- psl default clock is rising_edge(clk);

    -----------------------------------------------------------------------------------------------
    -- Types of bit-rate / sample point
    -----------------------------------------------------------------------------------------------

    -- psl nominal_sample_cov : cover
    --  {sp_control = NOMINAL_SAMPLE};

    -- psl data_sample_cov : cover
    --  {sp_control = DATA_SAMPLE};

    -- psl secondary_sample_cov : cover
    --  {sp_control = SECONDARY_SAMPLE};


    -----------------------------------------------------------------------------------------------
    -- Minimal / Maximal bit rates
    -----------------------------------------------------------------------------------------------

    -- psl minimal_bit_time_nbt_cov : cover
    --  {to_integer(unsigned(tseg1_nbt)) = 5 and to_integer(unsigned(tseg2_nbt)) = 3
    --   and to_integer(unsigned(brp_nbt)) = 1};

    -- psl minimal_bit_time_dbt_cov : cover
    --  {to_integer(unsigned(tseg1_dbt)) = 3 and to_integer(unsigned(tseg2_dbt)) = 2
    --   and to_integer(unsigned(brp_dbt)) = 1};

    -- psl maximal_bit_time_nbt_cov : cover
    --  {to_integer(unsigned(tseg1_nbt)) = 191 and to_integer(unsigned(tseg2_nbt)) = 63};

    -- psl maximal_bit_time_dbt_cov : cover
    --  {to_integer(unsigned(tseg1_dbt)) = 95 and to_integer(unsigned(tseg2_dbt)) = 31};


    -----------------------------------------------------------------------------------------------
    -- Various other bit rates
    -----------------------------------------------------------------------------------------------

    -- psl brp_bin_1_1_cov : cover
    --  {to_integer(unsigned(brp_nbt)) = 1 and to_integer(unsigned(brp_dbt)) = 1};

    -- psl brp_bin_2_1_cov : cover
    --  {to_integer(unsigned(brp_nbt)) = 2 and to_integer(unsigned(brp_dbt)) = 1};

    -- psl brp_bin_3_1_cov : cover
    --  {to_integer(unsigned(brp_nbt)) = 3 and to_integer(unsigned(brp_dbt)) = 1};

    -- psl brp_bin_4_1_cov : cover
    --  {to_integer(unsigned(brp_nbt)) = 4 and to_integer(unsigned(brp_dbt)) = 1};

    -- psl brp_bin_4_3_cov : cover
    --  {to_integer(unsigned(brp_nbt)) = 4 and to_integer(unsigned(brp_dbt)) = 3};

    -- psl brp_bin_1_2_cov : cover
    --  {to_integer(unsigned(brp_nbt)) = 1 and to_integer(unsigned(brp_dbt)) = 2};


    -----------------------------------------------------------------------------------------------
    -- Maximal prescaler
    -----------------------------------------------------------------------------------------------

    -- psl brp_nbt_max_cov : cover
    --  {to_integer(unsigned(brp_nbt)) = 255};

    -- psl brp_dbt_max_cov : cover
    --  {to_integer(unsigned(brp_dbt)) = 255};


    -----------------------------------------------------------------------------------------------
    -- Resynchronization
    -----------------------------------------------------------------------------------------------

    -- Positive resynchronization in Nominal bit rate
    -- psl pos_resync_in_nominal_bit_rate_cov : cover
    --  {resync_edge_valid = '1' and is_tseg1 = '1' and sp_control = NOMINAL_SAMPLE};

    -- Negative resynchronization in Nominal bit rate!
    -- psl neg_resync_in_nominal_bit_rate_cov : cover
    --  {resync_edge_valid = '1' and is_tseg2 = '1' and sp_control = NOMINAL_SAMPLE};

    -- Negative resynchronization in Data bit rate
    -- psl neg_resync_in_data_bit_rate_cov : cover
    --  {resync_edge_valid = '1' and is_tseg2 = '1' and sp_control = DATA_SAMPLE};

    -- Positive resynchronization in Data bit rate
    -- psl pos_resync_in_data_bit_rate_cov : cover
    --  {resync_edge_valid = '1' and is_tseg1 = '1' and sp_control = DATA_SAMPLE};


    -----------------------------------------------------------------------------------------------
    -- Nominal Bit Time
    -----------------------------------------------------------------------------------------------

    nominal_bit_time : block

        alias exp_seg_length_ce is
            << signal .tb_top_ctu_can_fd.dut.prescaler_inst.bit_segment_meter_nbt_inst.exp_seg_length_ce : std_logic >>;

        alias use_basic_segm_length is
            << signal .tb_top_ctu_can_fd.dut.prescaler_inst.bit_segment_meter_nbt_inst.use_basic_segm_length : std_logic >>;

        alias phase_err is
            << signal .tb_top_ctu_can_fd.dut.prescaler_inst.bit_segment_meter_nbt_inst.phase_err : unsigned(7 downto 0) >>;

        alias sjw is
            << signal .tb_top_ctu_can_fd.dut.prescaler_inst.bit_segment_meter_nbt_inst.sjw : std_logic_vector(4 downto 0) >>;

        alias exit_segm_req is
            << signal .tb_top_ctu_can_fd.dut.prescaler_inst.bit_segment_meter_nbt_inst.exit_segm_req : std_logic >>;

        alias exit_ph2_immediate is
            << signal .tb_top_ctu_can_fd.dut.prescaler_inst.bit_segment_meter_nbt_inst.exit_ph2_immediate : std_logic >>;

        alias exit_segm_regular_tseg1 is
            << signal .tb_top_ctu_can_fd.dut.prescaler_inst.bit_segment_meter_nbt_inst.exit_segm_regular_tseg1 : std_logic >>;

        alias exit_segm_regular_tseg2 is
            << signal .tb_top_ctu_can_fd.dut.prescaler_inst.bit_segment_meter_nbt_inst.exit_segm_regular_tseg2 : std_logic >>;

        constant C_RESIZE_WIDTH : natural := 10;

    begin
        -- Positive resynchronization with E < SJW
        -- psl nbt_pos_resync_e_less_than_sjw_cov : cover
        --  {exp_seg_length_ce = '1' and use_basic_segm_length = '0' and is_tseg1 = '1'
        --   and resync_edge_valid = '1' and
        --   (to_integer(unsigned(phase_err)) < to_integer(unsigned(sjw)))};

        -- Positive resynchronization with E > SJW
        -- psl nbt_pos_resync_e_more_than_sjw_cov : cover
        --  {exp_seg_length_ce = '1' and use_basic_segm_length = '0' and is_tseg1 = '1'
        --   and resync_edge_valid = '1' and
        --   (to_integer(unsigned(phase_err)) > to_integer(unsigned(sjw)))};

        -- Positive resynchronization with E = SJW
        -- psl nbt_pos_resync_e_equal_sjw_cov : cover
        --  {exp_seg_length_ce = '1' and use_basic_segm_length = '0' and is_tseg1 = '1'
        --   and resync_edge_valid = '1' and
        --   (to_integer(unsigned(phase_err)) = to_integer(unsigned(sjw)))};

        -- Negative resynchronization with E < SJW
        -- psl nbt_neg_resync_e_less_than_sjw_cov : cover
        --  {exp_seg_length_ce = '1' and resync_edge_valid = '1' and is_tseg2 = '1' and
        --   (to_integer(unsigned(phase_err)) < to_integer(unsigned(sjw)))};

        -- Negative resynchronization with E > SJW
        -- psl nbt_neg_resync_e_more_than_sjw_cov : cover
        --  {exp_seg_length_ce = '1' and resync_edge_valid = '1' and is_tseg2 = '1' and
        --   (to_integer(unsigned(phase_err)) > to_integer(unsigned(sjw)))};

        -- Negative resynchronization with E = SJW
        -- psl nbt_neg_resync_e_equal_sjw_cov : cover
        --  {exp_seg_length_ce = '1' and resync_edge_valid = '1' and is_tseg2 = '1' and
        --   (to_integer(unsigned(phase_err)) = to_integer(unsigned(sjw)))};

        -- psl nbt_exit_segm_immediate_cov : cover
        --  {exit_segm_req = '1' and exit_ph2_immediate = '1'};

        -- psl nbt_exit_segm_regular_tseg1_cov : cover
        --  {exit_segm_req = '1' and exit_segm_regular_tseg1 = '1' and exit_segm_regular_tseg2 = '0'};

        -- psl nbt_exit_segm_regular_tseg2_cov : cover
        --  {exit_segm_req = '1' and exit_segm_regular_tseg1 = '0' and exit_segm_regular_tseg2 = '1'};

    end block;

    -----------------------------------------------------------------------------------------------
    -- Data Bit Time
    -----------------------------------------------------------------------------------------------

    data_bit_time : block

        alias exp_seg_length_ce is
            << signal .tb_top_ctu_can_fd.dut.prescaler_inst.bit_segment_meter_dbt_inst.exp_seg_length_ce : std_logic >>;

        alias use_basic_segm_length is
            << signal .tb_top_ctu_can_fd.dut.prescaler_inst.bit_segment_meter_dbt_inst.use_basic_segm_length : std_logic >>;

        alias phase_err is
            << signal .tb_top_ctu_can_fd.dut.prescaler_inst.bit_segment_meter_dbt_inst.phase_err : unsigned(6 downto 0) >>;

        alias sjw is
            << signal .tb_top_ctu_can_fd.dut.prescaler_inst.bit_segment_meter_dbt_inst.sjw : std_logic_vector(4 downto 0) >>;

        alias exit_segm_req is
            << signal .tb_top_ctu_can_fd.dut.prescaler_inst.bit_segment_meter_dbt_inst.exit_segm_req : std_logic >>;

        alias exit_ph2_immediate is
            << signal .tb_top_ctu_can_fd.dut.prescaler_inst.bit_segment_meter_dbt_inst.exit_ph2_immediate : std_logic >>;

        alias exit_segm_regular_tseg1 is
            << signal .tb_top_ctu_can_fd.dut.prescaler_inst.bit_segment_meter_dbt_inst.exit_segm_regular_tseg1 : std_logic >>;

        alias exit_segm_regular_tseg2 is
            << signal .tb_top_ctu_can_fd.dut.prescaler_inst.bit_segment_meter_dbt_inst.exit_segm_regular_tseg2 : std_logic >>;

        constant C_RESIZE_WIDTH : natural := 10;

    begin
        -- Positive resynchronization with E < SJW
        -- psl dbt_pos_resync_e_less_than_sjw_cov : cover
        --  {exp_seg_length_ce = '1' and use_basic_segm_length = '0' and is_tseg1 = '1'
        --   and resync_edge_valid = '1' and
        --   (to_integer(unsigned(phase_err)) < to_integer(unsigned(sjw)))};

        -- Positive resynchronization with E > SJW
        -- psl dbt_pos_resync_e_more_than_sjw_cov : cover
        --  {exp_seg_length_ce = '1' and use_basic_segm_length = '0' and is_tseg1 = '1'
        --   and resync_edge_valid = '1' and
        --   (to_integer(unsigned(phase_err)) > to_integer(unsigned(sjw)))};

        -- Positive resynchronization with E = SJW
        -- psl dbt_pos_resync_e_equal_sjw_cov : cover
        --  {exp_seg_length_ce = '1' and use_basic_segm_length = '0' and is_tseg1 = '1'
        --   and resync_edge_valid = '1' and
        --   (to_integer(unsigned(phase_err)) = to_integer(unsigned(sjw)))};

        -- Negative resynchronization with E < SJW
        -- psl dbt_neg_resync_e_less_than_sjw_cov : cover
        --  {exp_seg_length_ce = '1' and resync_edge_valid = '1' and is_tseg2 = '1' and
        --   (to_integer(unsigned(phase_err)) < to_integer(unsigned(sjw)))};

        -- Negative resynchronization with E > SJW
        -- psl dbt_neg_resync_e_more_than_sjw_cov : cover
        --  {exp_seg_length_ce = '1' and resync_edge_valid = '1' and is_tseg2 = '1' and
        --   (to_integer(unsigned(phase_err)) > to_integer(unsigned(sjw)))};

        -- Negative resynchronization with E = SJW
        -- psl dbt_neg_resync_e_equal_sjw_cov : cover
        --  {exp_seg_length_ce = '1' and resync_edge_valid = '1' and is_tseg2 = '1' and
        --   (to_integer(unsigned(phase_err)) = to_integer(unsigned(sjw)))};

        -- psl dbt_exit_segm_immediate_cov : cover
        --  {exit_segm_req = '1' and exit_ph2_immediate = '1'};

        -- psl dbt_exit_segm_regular_tseg1_cov : cover
        --  {exit_segm_req = '1' and exit_segm_regular_tseg1 = '1' and exit_segm_regular_tseg2 = '0'};

        -- psl dbt_exit_segm_regular_tseg2_cov : cover
        --  {exit_segm_req = '1' and exit_segm_regular_tseg1 = '0' and exit_segm_regular_tseg2 = '1'};

    end block;

    -----------------------------------------------------------------------------------------------
    -- Synchronization
    -----------------------------------------------------------------------------------------------

    -- psl h_sync_ignored_due_to_previous_sync_cov : cover
    --  {sync_flag = '1' and h_sync_edge = '1'}
    --  report "Hard synchronisation ignored due to previous synchronization";

    -- psl re_sync_ignored_due_to_previous_sync_cov : cover
    --  {sync_flag = '1' and resync_edge = '1'}
    --  report "Re-synchronisation ignored due to previous synchronization";

    -- psl h_sync_in_tseg_1_cov : cover
    --  {h_sync_edge_valid = '1' and is_tseg1 = '1'}
    --  report "Hard synchronization in TSEG1";

    -- psl h_sync_in_tseg_2_cov : cover
    --  {h_sync_edge_valid = '1' and is_tseg2 = '1'}
    --  report "Hard synchronization in TSEG2";

    -- Hard synchronization in TSEG1
    -- psl re_sync_in_tseg_1_cov : cover
    --  {resync_edge_valid = '1' and is_tseg1 = '1'};

    -- psl re_sync_in_tseg_2_cov : cover
    --  {resync_edge_valid = '1' and is_tseg2 = '1'}
    --  report "Hard synchronization in TSEG2";


    -----------------------------------------------------------------------------------------------
    -- Trigger generation
    -----------------------------------------------------------------------------------------------

    -- psl tx_trigger_throttling_cov : cover
    --  {rx_trig_req_q = '1' and tx_trig_req = '1'}
    --  report "TX trigger throtlled!";

end architecture;