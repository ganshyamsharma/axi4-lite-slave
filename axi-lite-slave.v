/*          AXI4 - Lite Slave Interface
                    Ganshyam
                      v1.0
*/

`timescale 1ns/1ns

module axi4_lite_slave(
// Global Signals
    input           i_aclk,
    input           i_aresetn,            
// Write Address Channel
    input           i_awvalid,
    input   [31:0]  i_awaddr,
    input   [2:0]   i_awprot,           // Not used   
    output reg      o_awready,
// Write Data Channel
    input           i_wvalid,
    input   [31:0]  i_wdata,
    input   [3:0]   i_wstrb,
    output reg      o_wready,
// Write Response Channel
    input            i_bready,
    output reg       o_bvalid,
    output reg [1:0] o_bresp,
// Read Address Channel
    input           i_arvalid,
    input   [31:0]  i_araddr,
    input   [2:0]   i_arprot,           // Not used
    output reg      o_arready,
// Read Data Channel
    input             i_rready,
    output reg        o_rvalid,
    output reg [31:0] o_rdata,
    output reg [1:0]  o_rresp
);
// Read FSM Start
    reg [1:0]   r_current_state;
    reg [1:0]   r_next_state;
    reg [31:0]  r_rd_addr;
    reg [31:0]  r_mem [255:0];
    reg         r_rdaddr_error;

    localparam  S_IDLE      = 0;
    localparam  S_ADDR_ACK  = 1;
    localparam  S_FETCH     = 2;

    always @(*) begin
        r_next_state = r_current_state;

        case(r_current_state)
            S_IDLE:     r_next_state = i_arvalid ? S_ADDR_ACK : S_IDLE;
            S_ADDR_ACK: r_next_state = S_FETCH;
            S_FETCH:    r_next_state = i_rready ? S_IDLE : S_FETCH;
            default:    r_next_state = S_IDLE;
        endcase
    end

    always @(posedge i_aclk) begin

        if(!i_aresetn) begin
            r_current_state <= S_IDLE;
            o_rvalid        <= 0;
            o_arready       <= 1'b0;
            o_rresp         <= 2'b00;
            o_rdata         <= 32'b0;
            r_rdaddr_error  <= 1'b0;
        end

        else begin
            r_current_state <= r_next_state;

            case(r_next_state)
                S_IDLE: begin
                o_rvalid <= 1'b0;
                end
                S_ADDR_ACK: begin
                    r_rd_addr <= i_araddr;
                    o_arready <= 1'b1;
                    if(i_araddr[31:10] != 0) r_rdaddr_error <= 1'b1;
                    else r_rdaddr_error <= 1'b0;
                end
                S_FETCH: begin
                    o_arready   <= 1'b0;
                    o_rvalid    <= 1'b1;
                    if(!r_rdaddr_error) begin                 
                        o_rdata <= r_mem[r_rd_addr[9:2]];
                        o_rresp <= 2'b00;
                    end
                    else begin
                        o_rdata <= 32'b0;
                        o_rresp <= 2'b10;
                    end            
                end
                default: begin
                    o_rvalid    <= 1'b0;
                    o_arready   <= 1'b0;
                end
            endcase
        end
    end

//Write FSM Start
reg [2:0]   r_w_current_state;
reg [2:0]   r_w_next_state;
reg [31:0]  r_w_addr;
reg         r_waddr_error;

localparam S_W_IDLE      = 0;
localparam S_AW_ADDR_ACK = 1;
localparam S_WVALID_WAIT = 2;
localparam S_WDATA_WRITE = 3;
localparam S_BRESP_ACK   = 4;

always @(*) begin
    r_w_next_state = r_w_current_state;

    case(r_w_current_state)
        S_W_IDLE:       r_w_next_state = i_awvalid ? S_AW_ADDR_ACK : S_W_IDLE;
        S_AW_ADDR_ACK:  r_w_next_state = S_WVALID_WAIT;
        S_WVALID_WAIT:  r_w_next_state = i_wvalid ? S_WDATA_WRITE : S_WVALID_WAIT;
        S_WDATA_WRITE:  r_w_next_state = S_BRESP_ACK;
        S_BRESP_ACK:    r_w_next_state = i_bready ? S_W_IDLE :  S_BRESP_ACK;
        default:        r_w_next_state = S_W_IDLE;
    endcase
end

always @(posedge i_aclk) begin

    if(!i_aresetn) begin
        r_w_current_state <= S_W_IDLE;
        o_awready         <= 0;
        o_bvalid          <= 0;
        o_wready          <= 0;
        o_bresp           <= 0;
        r_waddr_error     <= 0;
    end
    else begin
        r_w_current_state <= r_w_next_state;

        case(r_w_next_state)
            S_W_IDLE: begin
                o_bvalid <= 0;
            end
            S_AW_ADDR_ACK: begin
                o_awready <= 1;
                r_w_addr  <= i_awaddr;
                if (i_awaddr[31:10] != 22'b0) r_waddr_error <= 1'b1;
                else r_waddr_error <= 1'b0;
            end
            S_WVALID_WAIT: begin
                o_awready <= 0;
                o_wready  <= 1;
            end
            S_WDATA_WRITE: begin
                o_wready <= 0;
                if(!r_waddr_error) begin
                    if(i_wstrb[0] == 1'b1) r_mem[r_w_addr[9:2]] [7:0]   <= i_wdata[7:0];
                    if(i_wstrb[1] == 1'b1) r_mem[r_w_addr[9:2]] [15:8]  <= i_wdata[15:8];
                    if(i_wstrb[2] == 1'b1) r_mem[r_w_addr[9:2]] [23:16] <= i_wdata[23:16];
                    if(i_wstrb[3] == 1'b1) r_mem[r_w_addr[9:2]] [31:24] <= i_wdata[31:24];
                end
            end
            S_BRESP_ACK: begin
                o_bvalid <= 1;
                o_bresp  <= r_waddr_error ? 2'b10 : 2'b00;
            end
            default: begin
                o_bvalid   <= 0;
                o_awready  <= 0;
                o_wready   <= 0;
            end
        endcase
    end
end

endmodule
