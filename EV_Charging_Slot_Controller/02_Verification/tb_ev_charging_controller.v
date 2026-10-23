// tb_ev_charging_controller.v
// Self-checking testbench. Inputs change at the falling edge (plus a mid-cycle
// glitch window); the model advances at the rising edge; outputs are compared
// 1 ns after the rising edge. Pre-edge, outputs must still equal the old state.

`timescale 1ns/1ps

module tb_ev_charging_controller;

    // ---------------- DUT connections ----------------
    reg        clk;
    reg        rst;
    reg  [3:0] slot_sensor;
    reg        reserve_req;
    reg        cancel_req;
    reg  [1:0] cancel_slot_id;

    wire [3:0] slot_status;
    wire [3:0] reserved_status;
    wire       sensor_valid;
    wire [2:0] available_count;
    wire       any_available;
    wire       station_full;
    wire [1:0] assigned_slot_id;
    wire       grant;
    wire       reject;
    wire       cancel_done;

    ev_charging_controller dut (
        .clk              (clk),
        .rst              (rst),
        .slot_sensor      (slot_sensor),
        .reserve_req      (reserve_req),
        .cancel_req       (cancel_req),
        .cancel_slot_id   (cancel_slot_id),
        .slot_status      (slot_status),
        .reserved_status  (reserved_status),
        .sensor_valid     (sensor_valid),
        .available_count  (available_count),
        .any_available    (any_available),
        .station_full     (station_full),
        .assigned_slot_id (assigned_slot_id),
        .grant            (grant),
        .reject           (reject),
        .cancel_done      (cancel_done)
    );

    // ---------------- clock ----------------
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // ---------------- bookkeeping ----------------
    integer errors;
    integer checks;
    integer cycle;
    integer test_err_start;
    reg [8*48-1:0] test_name;
    reg pre_check_en;

    reg       last_rst;
    reg [3:0] last_sensor;
    reg       last_rsv;
    reg       last_cnc;
    reg [1:0] last_cid;

    // ---------------- reference model state ----------------
    reg       m_occ [0:3];
    reg       m_res [0:3];
    reg       o_res [0:3];
    reg       m_valid;
    reg [1:0] m_aid;
    reg       m_grant;
    reg       m_reject;
    reg       m_cdone;

    integer n_grant;
    integer n_reject;
    integer n_cancel;
    integer n_arrival_clear;
    integer n_reset;

    reg [3:0] e_status;
    reg [3:0] e_resv;
    reg [2:0] e_count;
    reg       e_any;
    reg       e_full;

    // ---------------- stimulus variables ----------------
    integer    k;
    integer    n;
    integer    seed;
    reg [31:0] rnd;
    reg [31:0] rnd2;
    reg [3:0]  mask;
    reg [3:0]  cur_sensor;
    reg [3:0]  gl;
    reg        rv;
    reg        cv;
    reg        rs;
    reg [1:0]  cid;

    // ======================================================================
    // Comparison helper
    // ======================================================================
    task cmp;
        input [8*24-1:0] sig;
        input [3:0]      expv;
        input [3:0]      actv;
        begin
            checks = checks + 1;
            if (expv !== actv) begin
                errors = errors + 1;
                $display("FAIL [%0s] cycle=%0d inputs(rst=%b sensor=%b rsv=%b cnc=%b cid=%0d) signal=%0s expected=%b actual=%b",
                         test_name, cycle, last_rst, last_sensor, last_rsv,
                         last_cnc, last_cid, sig, expv, actv);
            end
        end
    endtask

    task exp_events;
        input g;
        input r;
        input c;
        begin
            cmp("grant",       {3'b000, g}, grant);
            cmp("reject",      {3'b000, r}, reject);
            cmp("cancel_done", {3'b000, c}, cancel_done);
        end
    endtask

    // ======================================================================
    // Reference model (per-slot loops over arrays; independent of DUT masks)
    // ======================================================================
    task model_update;
        input       rstv;
        input [3:0] s;
        input       r;
        input       c;
        input [1:0] id;
        integer i;
        integer pick;
        reg     was_valid;
        reg     cancel_ok;
        reg     newr;
        begin
            if (rstv) begin
                for (i = 0; i < 4; i = i + 1) begin
                    m_occ[i] = 1'b0;
                    m_res[i] = 1'b0;
                end
                m_valid  = 1'b0;
                m_aid    = 2'b00;
                m_grant  = 1'b0;
                m_reject = 1'b0;
                m_cdone  = 1'b0;
                n_reset  = n_reset + 1;
            end else begin
                was_valid = m_valid;
                for (i = 0; i < 4; i = i + 1) o_res[i] = m_res[i];
                m_grant  = 1'b0;
                m_reject = 1'b0;
                m_cdone  = 1'b0;

                // cancellation: reserved and not occupied in the current sample
                cancel_ok = 1'b0;
                if (c) begin
                    if (o_res[id] && !s[id]) cancel_ok = 1'b1;
                end
                if (cancel_ok) m_cdone = 1'b1;

                // reservation: lowest slot empty now and unreserved
                pick = -1;
                if (r && !c) begin
                    for (i = 3; i >= 0; i = i - 1) begin
                        if (!s[i] && !o_res[i]) pick = i;
                    end
                    if (was_valid && (pick >= 0)) begin
                        m_grant = 1'b1;
                        m_aid   = pick;
                    end else begin
                        m_reject = 1'b1;
                    end
                end

                // state update
                for (i = 0; i < 4; i = i + 1) begin
                    newr = o_res[i] && !s[i];
                    if (o_res[i] && s[i]) n_arrival_clear = n_arrival_clear + 1;
                    if (cancel_ok && (i == id)) newr = 1'b0;
                    if (m_grant && (i == pick)) newr = 1'b1;
                    m_res[i] = newr;
                    m_occ[i] = s[i];
                end
                m_valid = 1'b1;

                if (m_grant)  n_grant  = n_grant  + 1;
                if (m_reject) n_reject = n_reject + 1;
                if (m_cdone)  n_cancel = n_cancel + 1;
            end
        end
    endtask

    task compute_expected;
        integer i;
        integer cnt;
        begin
            e_status = 4'b0000;
            e_resv   = 4'b0000;
            cnt      = 0;
            for (i = 0; i < 4; i = i + 1) begin
                if (m_occ[i]) e_status[i] = 1'b1;
                if (m_res[i]) e_resv[i]   = 1'b1;
                if (!m_occ[i] && !m_res[i]) cnt = cnt + 1;
            end
            if (m_valid) begin
                e_count = cnt;
                e_any   = (cnt > 0);
                e_full  = (cnt == 0);
            end else begin
                e_count = 3'd0;
                e_any   = 1'b0;
                e_full  = 1'b0;
            end
        end
    endtask

    task check_outputs;
        begin
            compute_expected;
            cmp("slot_status",      e_status, slot_status);
            cmp("reserved_status",  e_resv,   reserved_status);
            cmp("sensor_valid",     {3'b000, m_valid}, sensor_valid);
            cmp("available_count",  {1'b0, e_count},   available_count);
            cmp("any_available",    {3'b000, e_any},   any_available);
            cmp("station_full",     {3'b000, e_full},  station_full);
            cmp("assigned_slot_id", {2'b00, m_aid},    assigned_slot_id);
            cmp("grant",            {3'b000, m_grant},  grant);
            cmp("reject",           {3'b000, m_reject}, reject);
            cmp("cancel_done",      {3'b000, m_cdone},  cancel_done);
            // model-independent invariants
            cmp("pulse_mutual_exclusion", 4'd1,
                ((grant + reject + cancel_done) <= 1) ? 4'd1 : 4'd0);
            cmp("no_resv_on_occupied", 4'b0000, slot_status & reserved_status);
            cmp("grant_implies_reserved", 4'd1,
                ((!grant) || reserved_status[assigned_slot_id]) ? 4'd1 : 4'd0);
        end
    endtask

    // ======================================================================
    // One clock cycle. Inputs change at the falling edge; sg is a glitch value
    // that is replaced by the final sample s before the rising edge.
    // ======================================================================
    task step_full;
        input       rstv;
        input [3:0] sg;
        input [3:0] s;
        input       r;
        input       c;
        input [1:0] id;
        begin
            @(negedge clk);
            last_rst    = rstv;
            last_sensor = s;
            last_rsv    = r;
            last_cnc    = c;
            last_cid    = id;
            rst            = rstv;
            slot_sensor    = sg;
            reserve_req    = r;
            cancel_req     = c;
            cancel_slot_id = id;
            #1;
            // registered outputs must not react to input changes between edges
            if (pre_check_en) check_outputs;
            #1;
            slot_sensor = s;
            @(posedge clk);
            cycle = cycle + 1;
            model_update(rstv, s, r, c, id);
            #1;
            check_outputs;
            if (rstv) pre_check_en = 1'b1;
        end
    endtask

    task step;
        input [3:0] s;
        input       r;
        input       c;
        input [1:0] id;
        begin
            step_full(1'b0, s, s, r, c, id);
        end
    endtask

    task idle;
        input [3:0] s;
        begin
            step_full(1'b0, s, s, 1'b0, 1'b0, 2'b00);
        end
    endtask

    task reserve;
        input [3:0] s;
        begin
            step_full(1'b0, s, s, 1'b1, 1'b0, 2'b00);
        end
    endtask

    task cancel;
        input [3:0] s;
        input [1:0] id;
        begin
            step_full(1'b0, s, s, 1'b0, 1'b1, id);
        end
    endtask

    task do_reset;
        input [3:0] s;
        begin
            step_full(1'b1, s, s, 1'b0, 1'b0, 2'b00);
            step_full(1'b1, s, s, 1'b0, 1'b0, 2'b00);
        end
    endtask

    // reset, release, and capture the first valid sample
    task bring_up;
        input [3:0] s;
        begin
            do_reset(s);
            idle(s);
        end
    endtask

    task occ_case;
        input [3:0] s;
        input [2:0] cnt;
        begin
            idle(s);
            idle(s);
            cmp("slot_status",     s, slot_status);
            cmp("available_count", {1'b0, cnt}, available_count);
            cmp("any_available",   (cnt != 0) ? 4'd1 : 4'd0, any_available);
            cmp("station_full",    (cnt == 0) ? 4'd1 : 4'd0, station_full);
        end
    endtask

    task begin_test;
        input [8*48-1:0] name;
        begin
            test_name      = name;
            test_err_start = errors;
        end
    endtask

    task end_test;
        begin
            if (errors == test_err_start)
                $display("PASS: %0s (through cycle %0d)", test_name, cycle);
            else
                $display("FAIL: %0s - %0d mismatches", test_name, errors - test_err_start);
        end
    endtask

    // ======================================================================
    // Waveform dump and watchdog
    // ======================================================================
    initial begin
        $dumpfile("ev_charging_controller.vcd");
        $dumpvars(0, tb_ev_charging_controller);
    end

    initial begin
        #5000000;
        $display("FAIL: watchdog timeout");
        $fatal(1, "watchdog timeout");
    end

    // ======================================================================
    // Main test sequence
    // ======================================================================
    initial begin
        errors = 0; checks = 0; cycle = 0; test_err_start = 0;
        pre_check_en = 1'b0;
        test_name = "init";
        last_rst = 1'b0; last_sensor = 4'b0000; last_rsv = 1'b0;
        last_cnc = 1'b0; last_cid = 2'b00;
        n_grant = 0; n_reject = 0; n_cancel = 0; n_arrival_clear = 0; n_reset = 0;
        m_valid = 1'b0; m_aid = 2'b00; m_grant = 1'b0; m_reject = 1'b0; m_cdone = 1'b0;
        for (k = 0; k < 4; k = k + 1) begin
            m_occ[k] = 1'b0;
            m_res[k] = 1'b0;
            o_res[k] = 1'b0;
        end
        rst = 1'b0; slot_sensor = 4'b0000; reserve_req = 1'b0;
        cancel_req = 1'b0; cancel_slot_id = 2'b00;
        #1;

        // ---------------- T01 ----------------
        begin_test("T01 reset and sensor validity");
        do_reset(4'b0000);
        cmp("sensor_valid",    4'd0, sensor_valid);
        cmp("available_count", 4'd0, available_count);
        cmp("any_available",   4'd0, any_available);
        cmp("station_full",    4'd0, station_full);
        cmp("slot_status",     4'd0, slot_status);
        cmp("reserved_status", 4'd0, reserved_status);
        exp_events(1'b0, 1'b0, 1'b0);
        // requests and sensors during reset: no pulses, sensors not captured
        step_full(1'b1, 4'b1111, 4'b1111, 1'b1, 1'b1, 2'd1);
        exp_events(1'b0, 1'b0, 1'b0);
        cmp("slot_status",  4'd0, slot_status);
        cmp("sensor_valid", 4'd0, sensor_valid);
        cmp("station_full", 4'd0, station_full);
        // first edge after release with a reserve request: rejected, sample captured
        step(4'b0000, 1'b1, 1'b0, 2'b00);
        exp_events(1'b0, 1'b1, 1'b0);
        cmp("sensor_valid",     4'd1, sensor_valid);
        cmp("available_count",  4'd4, available_count);
        cmp("reserved_status",  4'd0, reserved_status);
        idle(4'b0000);
        exp_events(1'b0, 1'b0, 1'b0);
        // first sample with occupied slots
        do_reset(4'b0000);
        idle(4'b1010);
        cmp("slot_status",     4'b1010, slot_status);
        cmp("available_count", 4'd2,    available_count);
        // first sample all occupied: valid and full
        do_reset(4'b0000);
        idle(4'b1111);
        cmp("station_full", 4'd1, station_full);
        cmp("any_available", 4'd0, any_available);
        // cancel request while invalid: no pulses
        do_reset(4'b0000);
        step(4'b0000, 1'b0, 1'b1, 2'd0);
        exp_events(1'b0, 1'b0, 1'b0);
        end_test;

        // ---------------- T02 ----------------
        begin_test("T02 all 16 occupancy combinations");
        do_reset(4'b0000);
        for (k = 0; k < 16; k = k + 1) begin
            idle(k[3:0]);
            idle(k[3:0]);
            cmp("slot_status",     k[3:0], slot_status);
            cmp("available_count", 4 - (k[0] + k[1] + k[2] + k[3]), available_count);
            cmp("any_available",   (k != 15) ? 4'd1 : 4'd0, any_available);
            cmp("station_full",    (k == 15) ? 4'd1 : 4'd0, station_full);
            cmp("reserved_status", 4'd0, reserved_status);
        end
        end_test;

        // ---------------- T03 to T05 ----------------
        begin_test("T03 all slots empty");
        do_reset(4'b0000);
        occ_case(4'b0000, 3'd4);
        end_test;

        begin_test("T04 one, two and three occupied");
        occ_case(4'b0001, 3'd3);
        occ_case(4'b0010, 3'd3);
        occ_case(4'b0100, 3'd3);
        occ_case(4'b1000, 3'd3);
        occ_case(4'b0011, 3'd2);
        occ_case(4'b0101, 3'd2);
        occ_case(4'b1010, 3'd2);
        occ_case(4'b1100, 3'd2);
        occ_case(4'b0111, 3'd1);
        occ_case(4'b1011, 3'd1);
        occ_case(4'b1101, 3'd1);
        occ_case(4'b1110, 3'd1);
        end_test;

        begin_test("T05 all slots occupied");
        occ_case(4'b1111, 3'd0);
        end_test;

        // ---------------- T06 ----------------
        begin_test("T06 lowest-numbered eligible slot");
        bring_up(4'b0000);
        reserve(4'b0000);
        exp_events(1'b1, 1'b0, 1'b0);
        cmp("assigned_slot_id", 4'd0, assigned_slot_id);
        cmp("reserved_status",  4'b0001, reserved_status);

        bring_up(4'b0100);
        reserve(4'b0100);
        exp_events(1'b1, 1'b0, 1'b0);
        cmp("assigned_slot_id", 4'd0, assigned_slot_id);
        cmp("reserved_status",  4'b0001, reserved_status);

        bring_up(4'b0111);
        reserve(4'b0111);
        exp_events(1'b1, 1'b0, 1'b0);
        cmp("assigned_slot_id", 4'd3, assigned_slot_id);
        cmp("reserved_status",  4'b1000, reserved_status);

        bring_up(4'b0011);
        reserve(4'b0011);
        exp_events(1'b1, 1'b0, 1'b0);
        cmp("assigned_slot_id", 4'd2, assigned_slot_id);
        cmp("reserved_status",  4'b0100, reserved_status);

        bring_up(4'b1001);
        reserve(4'b1001);
        exp_events(1'b1, 1'b0, 1'b0);
        cmp("assigned_slot_id", 4'd1, assigned_slot_id);
        cmp("reserved_status",  4'b0010, reserved_status);
        end_test;

        // ---------------- T07 ----------------
        begin_test("T07 sequential allocations and full station");
        bring_up(4'b0000);
        reserve(4'b0000);
        exp_events(1'b1, 1'b0, 1'b0);
        cmp("assigned_slot_id", 4'd0, assigned_slot_id);
        cmp("reserved_status",  4'b0001, reserved_status);
        cmp("available_count",  4'd3, available_count);
        reserve(4'b0000);
        exp_events(1'b1, 1'b0, 1'b0);
        cmp("assigned_slot_id", 4'd1, assigned_slot_id);
        cmp("reserved_status",  4'b0011, reserved_status);
        cmp("available_count",  4'd2, available_count);
        reserve(4'b0000);
        exp_events(1'b1, 1'b0, 1'b0);
        cmp("assigned_slot_id", 4'd2, assigned_slot_id);
        cmp("reserved_status",  4'b0111, reserved_status);
        cmp("available_count",  4'd1, available_count);
        reserve(4'b0000);
        exp_events(1'b1, 1'b0, 1'b0);
        cmp("assigned_slot_id", 4'd3, assigned_slot_id);
        cmp("reserved_status",  4'b1111, reserved_status);
        cmp("available_count",  4'd0, available_count);
        cmp("any_available",    4'd0, any_available);
        cmp("station_full",     4'd1, station_full);
        reserve(4'b0000);
        exp_events(1'b0, 1'b1, 1'b0);
        cmp("reserved_status",  4'b1111, reserved_status);
        cmp("assigned_slot_id", 4'd3, assigned_slot_id);
        idle(4'b0000);
        exp_events(1'b0, 1'b0, 1'b0);
        end_test;

        // ---------------- T08 ----------------
        begin_test("T08 rejection when no slot is eligible");
        bring_up(4'b1111);
        reserve(4'b1111);
        exp_events(1'b0, 1'b1, 1'b0);
        cmp("reserved_status",  4'd0, reserved_status);
        cmp("assigned_slot_id", 4'd0, assigned_slot_id);
        // empty slots all reserved: full, rejects
        bring_up(4'b1100);
        reserve(4'b1100);
        exp_events(1'b1, 1'b0, 1'b0);
        cmp("available_count", 4'd1, available_count);
        reserve(4'b1100);
        exp_events(1'b1, 1'b0, 1'b0);
        cmp("available_count", 4'd0, available_count);
        cmp("station_full",    4'd1, station_full);
        reserve(4'b1100);
        exp_events(1'b0, 1'b1, 1'b0);
        cmp("reserved_status", 4'b0011, reserved_status);
        end_test;

        // ---------------- T09 ----------------
        begin_test("T09 no double reservation");
        bring_up(4'b1110);
        reserve(4'b1110);
        exp_events(1'b1, 1'b0, 1'b0);
        cmp("assigned_slot_id", 4'd0, assigned_slot_id);
        reserve(4'b1110);
        exp_events(1'b0, 1'b1, 1'b0);
        cmp("reserved_status",  4'b0001, reserved_status);
        cmp("assigned_slot_id", 4'd0, assigned_slot_id);
        end_test;

        // ---------------- T10 ----------------
        begin_test("T10 cancellation of each reservation");
        bring_up(4'b0000);
        reserve(4'b0000);
        reserve(4'b0000);
        reserve(4'b0000);
        reserve(4'b0000);
        cmp("reserved_status", 4'b1111, reserved_status);
        cancel(4'b0000, 2'd2);
        exp_events(1'b0, 1'b0, 1'b1);
        cmp("reserved_status", 4'b1011, reserved_status);
        cmp("available_count", 4'd1, available_count);
        cancel(4'b0000, 2'd0);
        exp_events(1'b0, 1'b0, 1'b1);
        cmp("reserved_status", 4'b1010, reserved_status);
        cancel(4'b0000, 2'd3);
        exp_events(1'b0, 1'b0, 1'b1);
        cmp("reserved_status", 4'b0010, reserved_status);
        cancel(4'b0000, 2'd1);
        exp_events(1'b0, 1'b0, 1'b1);
        cmp("reserved_status", 4'b0000, reserved_status);
        cmp("available_count", 4'd4, available_count);
        idle(4'b0000);
        exp_events(1'b0, 1'b0, 1'b0);
        reserve(4'b0000);
        exp_events(1'b1, 1'b0, 1'b0);
        cmp("assigned_slot_id", 4'd0, assigned_slot_id);
        // valid cancel while a different slot is occupied
        bring_up(4'b0000);
        reserve(4'b0000);
        reserve(4'b0000);
        idle(4'b0010);
        cmp("reserved_status", 4'b0001, reserved_status);
        cancel(4'b0010, 2'd0);
        exp_events(1'b0, 1'b0, 1'b1);
        cmp("reserved_status", 4'b0000, reserved_status);
        end_test;

        // ---------------- T11 ----------------
        begin_test("T11 cancellation of an unreserved slot");
        bring_up(4'b0000);
        cancel(4'b0000, 2'd1);
        exp_events(1'b0, 1'b0, 1'b0);
        cmp("reserved_status", 4'd0, reserved_status);
        reserve(4'b0000);
        exp_events(1'b1, 1'b0, 1'b0);
        cancel(4'b0000, 2'd2);
        exp_events(1'b0, 1'b0, 1'b0);
        cmp("reserved_status", 4'b0001, reserved_status);
        cancel(4'b0000, 2'd3);
        exp_events(1'b0, 1'b0, 1'b0);
        cancel(4'b0000, 2'd0);
        exp_events(1'b0, 1'b0, 1'b1);
        cancel(4'b0000, 2'd0);
        exp_events(1'b0, 1'b0, 1'b0);
        cmp("reserved_status", 4'd0, reserved_status);
        end_test;

        // ---------------- T12 ----------------
        begin_test("T12 cancellation when selected slot is occupied");
        bring_up(4'b0000);
        reserve(4'b0000);
        cmp("reserved_status", 4'b0001, reserved_status);
        cancel(4'b0001, 2'd0);
        exp_events(1'b0, 1'b0, 1'b0);
        cmp("reserved_status", 4'b0000, reserved_status);
        cmp("slot_status",     4'b0001, slot_status);
        cmp("available_count", 4'd3, available_count);
        bring_up(4'b0100);
        cancel(4'b0100, 2'd2);
        exp_events(1'b0, 1'b0, 1'b0);
        end_test;

        // ---------------- T13 ----------------
        begin_test("T13 vehicle arrival at reserved slot");
        bring_up(4'b0000);
        reserve(4'b0000);
        reserve(4'b0000);
        cmp("reserved_status", 4'b0011, reserved_status);
        cmp("available_count", 4'd2, available_count);
        idle(4'b0010);
        cmp("reserved_status", 4'b0001, reserved_status);
        cmp("slot_status",     4'b0010, slot_status);
        cmp("available_count", 4'd2, available_count);
        idle(4'b0011);
        cmp("reserved_status", 4'b0000, reserved_status);
        cmp("available_count", 4'd2, available_count);
        idle(4'b0001);
        cmp("available_count", 4'd3, available_count);
        reserve(4'b0001);
        exp_events(1'b1, 1'b0, 1'b0);
        cmp("assigned_slot_id", 4'd1, assigned_slot_id);
        end_test;

        // ---------------- T14 ----------------
        begin_test("T14 simultaneous cancel and reserve");
        bring_up(4'b0000);
        reserve(4'b0000);
        cmp("reserved_status", 4'b0001, reserved_status);
        step(4'b0000, 1'b1, 1'b1, 2'd0);
        exp_events(1'b0, 1'b0, 1'b1);
        cmp("reserved_status", 4'b0000, reserved_status);
        reserve(4'b0000);
        exp_events(1'b1, 1'b0, 1'b0);
        cmp("assigned_slot_id", 4'd0, assigned_slot_id);
        cmp("reserved_status",  4'b0001, reserved_status);
        // invalid cancel plus reserve: reserve is dropped, no pulses at all
        step(4'b0000, 1'b1, 1'b1, 2'd3);
        exp_events(1'b0, 1'b0, 1'b0);
        cmp("reserved_status", 4'b0001, reserved_status);
        bring_up(4'b1111);
        step(4'b1111, 1'b1, 1'b1, 2'd0);
        exp_events(1'b0, 1'b0, 1'b0);
        end_test;

        // ---------------- T15 ----------------
        begin_test("T15 vehicle arrival coinciding with reserve");
        bring_up(4'b0000);
        reserve(4'b0001);
        exp_events(1'b1, 1'b0, 1'b0);
        cmp("assigned_slot_id", 4'd1, assigned_slot_id);
        cmp("reserved_status",  4'b0010, reserved_status);
        cmp("slot_status",      4'b0001, slot_status);
        bring_up(4'b0000);
        reserve(4'b1111);
        exp_events(1'b0, 1'b1, 1'b0);
        cmp("reserved_status", 4'b0000, reserved_status);
        cmp("slot_status",     4'b1111, slot_status);
        bring_up(4'b0000);
        reserve(4'b0000);
        cmp("reserved_status", 4'b0001, reserved_status);
        reserve(4'b0011);
        exp_events(1'b1, 1'b0, 1'b0);
        cmp("assigned_slot_id", 4'd2, assigned_slot_id);
        cmp("reserved_status",  4'b0100, reserved_status);
        cmp("available_count",  4'd1, available_count);
        end_test;

        // ---------------- T16 ----------------
        begin_test("T16 reset during operation");
        bring_up(4'b0000);
        reserve(4'b0000);
        reserve(4'b0000);
        cmp("reserved_status",  4'b0011, reserved_status);
        cmp("assigned_slot_id", 4'd1, assigned_slot_id);
        step_full(1'b1, 4'b0101, 4'b0101, 1'b1, 1'b0, 2'b00);
        cmp("reserved_status",  4'd0, reserved_status);
        cmp("slot_status",      4'd0, slot_status);
        cmp("sensor_valid",     4'd0, sensor_valid);
        cmp("assigned_slot_id", 4'd0, assigned_slot_id);
        cmp("available_count",  4'd0, available_count);
        cmp("any_available",    4'd0, any_available);
        cmp("station_full",     4'd0, station_full);
        exp_events(1'b0, 1'b0, 1'b0);
        step(4'b0101, 1'b1, 1'b0, 2'b00);
        exp_events(1'b0, 1'b1, 1'b0);
        cmp("available_count", 4'd2, available_count);
        reserve(4'b0101);
        exp_events(1'b1, 1'b0, 1'b0);
        cmp("assigned_slot_id", 4'd1, assigned_slot_id);
        end_test;

        // ---------------- T17 ----------------
        begin_test("T17 one-cycle pulses and mutual exclusion");
        bring_up(4'b0000);
        reserve(4'b0000);
        exp_events(1'b1, 1'b0, 1'b0);
        idle(4'b0000);
        exp_events(1'b0, 1'b0, 1'b0);
        reserve(4'b0000);
        exp_events(1'b1, 1'b0, 1'b0);
        reserve(4'b0000);
        exp_events(1'b1, 1'b0, 1'b0);
        cancel(4'b0000, 2'd0);
        exp_events(1'b0, 1'b0, 1'b1);
        idle(4'b0000);
        exp_events(1'b0, 1'b0, 1'b0);
        bring_up(4'b1111);
        reserve(4'b1111);
        exp_events(1'b0, 1'b1, 1'b0);
        idle(4'b1111);
        exp_events(1'b0, 1'b0, 1'b0);
        end_test;

        // ---------------- T18 ----------------
        begin_test("T18 sensor changes between clock edges");
        bring_up(4'b0000);
        // sensor glitches to 1111 mid-cycle, but the edge sample is 0000
        step_full(1'b0, 4'b1111, 4'b0000, 1'b1, 1'b0, 2'b00);
        exp_events(1'b1, 1'b0, 1'b0);
        cmp("assigned_slot_id", 4'd0, assigned_slot_id);
        cmp("slot_status",      4'b0000, slot_status);
        cmp("reserved_status",  4'b0001, reserved_status);
        // glitch value 0101, edge sample 1000: slot 1 granted
        step_full(1'b0, 4'b0101, 4'b1000, 1'b1, 1'b0, 2'b00);
        exp_events(1'b1, 1'b0, 1'b0);
        cmp("assigned_slot_id", 4'd1, assigned_slot_id);
        cmp("slot_status",      4'b1000, slot_status);
        cmp("reserved_status",  4'b0011, reserved_status);
        step_full(1'b0, 4'b1111, 4'b1111, 1'b0, 1'b0, 2'b00);
        cmp("slot_status",      4'b1111, slot_status);
        end_test;

        // ---------------- T19 ----------------
        begin_test("T19 all four slot IDs");
        for (k = 0; k < 4; k = k + 1) begin
            mask = 4'b0001 << k;
            // slots below k occupied: slot k is the lowest eligible
            bring_up(mask - 4'b0001);
            reserve(mask - 4'b0001);
            exp_events(1'b1, 1'b0, 1'b0);
            cmp("assigned_slot_id", k, assigned_slot_id);
            cmp("reserved_status",  mask, reserved_status);
            cancel(mask - 4'b0001, k);
            exp_events(1'b0, 1'b0, 1'b1);
            cmp("reserved_status",  4'd0, reserved_status);
            // only slot k empty
            bring_up(~mask);
            reserve(~mask);
            exp_events(1'b1, 1'b0, 1'b0);
            cmp("assigned_slot_id", k, assigned_slot_id);
            cmp("reserved_status",  mask, reserved_status);
            cmp("station_full",     4'd1, station_full);
        end
        end_test;

        // ---------------- T20 ----------------
        begin_test("T20 constrained random sequence");
        n_grant = 0; n_reject = 0; n_cancel = 0; n_arrival_clear = 0; n_reset = 0;
        seed = 32'h1BADB002;
        bring_up(4'b0000);
        cur_sensor = 4'b0000;
        for (n = 0; n < 20000; n = n + 1) begin
            rnd  = $random(seed);
            rnd2 = $random(seed);
            if (rnd[2:0] < 3'd3)       cur_sensor[rnd[5:4]] = ~cur_sensor[rnd[5:4]];
            else if (rnd[2:0] == 3'd7) cur_sensor = rnd[11:8];
            rv  = (rnd[13:12] != 2'b00);
            cv  = (rnd[17:16] == 2'b00);
            cid = rnd[21:20];
            gl  = rnd2[0] ? rnd2[7:4] : cur_sensor;
            rs  = (rnd2[15:9] == 7'd0);
            step_full(rs, gl, cur_sensor, rv, cv, cid);
        end
        $display("INFO: random seed 1BADB002, cycles 20000: grants=%0d rejects=%0d cancels=%0d arrival_clears=%0d resets=%0d",
                 n_grant, n_reject, n_cancel, n_arrival_clear, n_reset);
        if ((n_grant == 0) || (n_reject == 0) || (n_cancel == 0) ||
            (n_arrival_clear == 0) || (n_reset == 0)) begin
            errors = errors + 1;
            $display("FAIL [T20] random stimulus did not exercise every event type");
        end
        end_test;

        // ---------------- summary ----------------
        $display("SUMMARY: %0d cycles, %0d checks, %0d errors", cycle, checks, errors);
        if (errors == 0) begin
            $display("ALL TESTS PASSED");
            $finish;
        end else begin
            $display("TESTS FAILED");
            $fatal(1, "%0d mismatches detected", errors);
        end
    end

endmodule
