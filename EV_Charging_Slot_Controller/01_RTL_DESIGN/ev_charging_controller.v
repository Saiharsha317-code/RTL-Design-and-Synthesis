// ev_charging_controller.v
// EV Charging Slot Availability and Smart Allocation Controller
// Synthesizable Verilog-2001. Active-high synchronous reset.
//
// Event priority on one rising edge (all use the live slot_sensor sample):
//   1. Vehicle arrival : reserved slot with sensor=1 loses its reservation.
//   2. Cancellation    : valid only if slot is reserved AND sensor=0 now.
//   3. Reservation     : ignored if cancel_req=1; otherwise grants the lowest
//                        slot that is empty NOW and unreserved, if sensor_valid.
// Availability outputs are derived from registered state only.

module ev_charging_controller (
    input  wire       clk,
    input  wire       rst,
    input  wire [3:0] slot_sensor,
    input  wire       reserve_req,
    input  wire       cancel_req,
    input  wire [1:0] cancel_slot_id,

    output reg  [3:0] slot_status,
    output reg  [3:0] reserved_status,
    output reg        sensor_valid,
    output wire [2:0] available_count,
    output wire       any_available,
    output wire       station_full,
    output reg  [1:0] assigned_slot_id,
    output reg        grant,
    output reg        reject,
    output reg        cancel_done
);

    // ------------------------------------------------------------------
    // Availability: registered state only
    // ------------------------------------------------------------------
    wire [3:0] eligible_reg = ~slot_status & ~reserved_status;
    wire [2:0] count_raw    = {2'b00, eligible_reg[0]} + {2'b00, eligible_reg[1]}
                            + {2'b00, eligible_reg[2]} + {2'b00, eligible_reg[3]};

    assign available_count = sensor_valid ? count_raw : 3'd0;
    assign any_available   = sensor_valid & (count_raw != 3'd0);
    assign station_full    = sensor_valid & (count_raw == 3'd0);

    // ------------------------------------------------------------------
    // Next-state decision logic: live slot_sensor + current reserved_status
    // ------------------------------------------------------------------
    reg [3:0] cancel_mask;
    reg       cancel_ok;
    reg [3:0] eligible_now;
    reg       grant_ok;
    reg       reject_ok;
    reg [1:0] grant_id;
    reg [3:0] grant_mask;
    reg [3:0] reserved_next;

    always @(*) begin
        // decode cancel slot
        case (cancel_slot_id)
            2'b00:   cancel_mask = 4'b0001;
            2'b01:   cancel_mask = 4'b0010;
            2'b10:   cancel_mask = 4'b0100;
            default: cancel_mask = 4'b1000;
        endcase

        // valid cancel: slot reserved and NOT occupied in the current sample
        cancel_ok = cancel_req &
                    ((reserved_status & ~slot_sensor & cancel_mask) != 4'b0000);

        // eligible: empty in the current sample and not reserved
        eligible_now = ~slot_sensor & ~reserved_status;

        grant_ok   = 1'b0;
        reject_ok  = 1'b0;
        grant_id   = 2'b00;
        grant_mask = 4'b0000;

        if (reserve_req & ~cancel_req) begin
            if (sensor_valid & (eligible_now != 4'b0000)) begin
                grant_ok = 1'b1;
                if (eligible_now[0]) begin
                    grant_id   = 2'b00;
                    grant_mask = 4'b0001;
                end else if (eligible_now[1]) begin
                    grant_id   = 2'b01;
                    grant_mask = 4'b0010;
                end else if (eligible_now[2]) begin
                    grant_id   = 2'b10;
                    grant_mask = 4'b0100;
                end else begin
                    grant_id   = 2'b11;
                    grant_mask = 4'b1000;
                end
            end else begin
                reject_ok = 1'b1;
            end
        end

        // reservation next state: arrival clears, then cancel clears, then grant sets
        reserved_next = reserved_status & ~slot_sensor;
        if (cancel_ok) reserved_next = reserved_next & ~cancel_mask;
        if (grant_ok)  reserved_next = reserved_next | grant_mask;
    end

    // ------------------------------------------------------------------
    // Sequential state: nonblocking assignments only
    // ------------------------------------------------------------------
    always @(posedge clk) begin
        // default: event pulses last one cycle
        grant       <= 1'b0;
        reject      <= 1'b0;
        cancel_done <= 1'b0;

        if (rst) begin
            slot_status      <= 4'b0000;
            reserved_status  <= 4'b0000;
            sensor_valid     <= 1'b0;
            assigned_slot_id <= 2'b00;
        end else begin
            slot_status     <= slot_sensor;
            sensor_valid    <= 1'b1;
            reserved_status <= reserved_next;
            grant           <= grant_ok;
            reject          <= reject_ok;
            cancel_done     <= cancel_ok;
            if (grant_ok) assigned_slot_id <= grant_id;
        end
    end

endmodule
