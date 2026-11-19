module vnir_isolation #(
    parameter int SESSION_BITS = 128,
    parameter int AUDIT_BITS = 64
) (
    input  logic                    clk,
    input  logic                    rst_n,

    input  logic                    session_write_en,
    input  logic [SESSION_BITS-1:0] session_write_data,

    input  logic                    terminal_event,
    input  logic [7:0]              terminal_reason_code,

    input  logic                    audit_append_ready,
    output logic                    audit_append_valid,
    output logic [AUDIT_BITS-1:0]   audit_append_data,

    output logic [SESSION_BITS-1:0] vnir_state,
    output logic                    protected_release_allowed
);

    logic [SESSION_BITS-1:0] session_registers;
    logic                    terminal_latched;

    function automatic logic [AUDIT_BITS-1:0] minimal_audit_projection(
        input logic [7:0] reason_code
    );
        minimal_audit_projection = {
            48'b0,
            8'h01,
            reason_code
        };
    endfunction

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            session_registers <= '0;
            terminal_latched <= 1'b0;
            audit_append_valid <= 1'b0;
            audit_append_data <= '0;
        end else begin
            audit_append_valid <= 1'b0;

            if (terminal_event) begin
                session_registers <= '0;
                terminal_latched <= 1'b1;

                if (audit_append_ready) begin
                    audit_append_valid <= 1'b1;
                    audit_append_data <= minimal_audit_projection(
                        terminal_reason_code
                    );
                end
            end else if (session_write_en && !terminal_latched) begin
                session_registers <= session_write_data;
            end
        end
    end

    assign vnir_state = session_registers;

    assign protected_release_allowed =
        rst_n
        && !terminal_latched
        && (session_registers != '0);

`ifdef FORMAL
    always_ff @(posedge clk) begin
        if (!$initstate) begin
            assert(!(terminal_latched && protected_release_allowed));

            if (terminal_latched) begin
                assert(session_registers == '0);
            end

            if (audit_append_valid) begin
                assert(audit_append_data[63:16] == '0);
                assert(audit_append_data[15:8] == 8'h01);
            end
        end
    end
`endif

endmodule
