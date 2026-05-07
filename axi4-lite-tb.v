/*          AXI4 - Lite Slave Interface Test-Bench
                    Ganshyam
                      v1.0
*/

`timescale 1ns/1ns

module tb_axi4_lite_slave();

    // Global Signals
    reg         tb_aclk;
    reg         tb_aresetn;
    
    // Write & Resp. Channel Signals
    reg         tb_awvalid;
    reg  [31:0] tb_awaddr;
    reg  [2:0]  tb_awprot;
    wire        tb_awready;
    reg         tb_wvalid;
    reg  [31:0] tb_wdata;
    reg  [3:0]  tb_wstrb;
    wire        tb_wready;
    reg         tb_bready;
    wire        tb_bvalid;
    wire [1:0]  tb_bresp;
    
    // Read Channel Signals
    reg         tb_arvalid;
    reg  [31:0] tb_araddr;
    reg  [2:0]  tb_arprot;
    wire        tb_arready;
    reg         tb_rready;
    wire        tb_rvalid;
    wire [31:0] tb_rdata;
    wire [1:0]  tb_rresp;

    // DUT
    axi4_lite_slave dut (
        .i_aclk(tb_aclk),
        .i_aresetn(tb_aresetn),
        .i_awvalid(tb_awvalid),
        .i_awaddr(tb_awaddr),
        .i_awprot(tb_awprot),
        .o_awready(tb_awready),
        .i_wvalid(tb_wvalid),
        .i_wdata(tb_wdata),
        .i_wstrb(tb_wstrb),
        .o_wready(tb_wready),
        .i_bready(tb_bready),
        .o_bvalid(tb_bvalid),
        .o_bresp(tb_bresp),
        .i_arvalid(tb_arvalid),
        .i_araddr(tb_araddr),
        .i_arprot(tb_arprot),
        .o_arready(tb_arready),
        .i_rready(tb_rready),
        .o_rvalid(tb_rvalid),
        .o_rdata(tb_rdata),
        .o_rresp(tb_rresp)
    );

    // 100MHz Clock
    initial begin
        tb_aclk = 0;
        forever #5 tb_aclk = ~tb_aclk;
    end

    always @(posedge tb_aclk) begin

    end

    // Continously checks if ARVALID is deasserted before ARREADY is asserted
    always @(posedge tb_aclk) begin      
        if(arvalid_prev == 1'b1 && tb_arvalid == 1'b0) begin
            if(arready_prev == 1'b0) begin
                $fatal(1, "PROTOCOL VIOLATION");
            end
        end
        arvalid_prev <= tb_arvalid;
        arready_prev <= tb_arready;
    end

    // Data Write Task
    task axi_write;
        input [31:0] write_address;
        input [31:0] write_data;
        input [3:0]  write_strobe;
        begin
            @(posedge tb_aclk);
            tb_awaddr  = write_address;
            tb_awvalid = 1'b1;
            tb_wdata   = write_data;
            tb_wstrb   = write_strobe;
            tb_wvalid  = 1'b1;
            tb_bready  = 1'b1;
            
            wait(tb_awvalid && tb_awready);
            @(posedge tb_aclk);
            tb_awvalid = 1'b0;
            
            wait(tb_wvalid && tb_wready);
            @(posedge tb_aclk);
            tb_wvalid = 1'b0;
            
            wait(tb_bvalid && tb_bready);
            @(posedge tb_aclk);
            
            $display("[%0t] WRITE | Addr: 0x%0h | Data: 0x%0h | Strb: %b | Resp: %b", 
                     $time, write_address, write_data, write_strobe, tb_bresp);
            tb_bready = 1'b0;
        end
    endtask

    // Data 
    task axi_write_data_first;
        input [31:0] wr_addr;
        input [31:0] wr_data;
        input [3:0]  wr_strobe;
        begin
            @(posedge tb_aclk);
            tb_wvalid = 1'b1;
            tb_bready = 1'b1;
            tb_wdata  = wr_data;
            tb_wstrb  = wr_strobe;

            repeat(3) @(posedge tb_aclk);
            tb_awvalid = 1'b1;
            tb_awaddr  = wr_addr;

            fork
                begin
                    wait(tb_awvalid && tb_awready);
                    @(posedge tb_aclk);
                    tb_awvalid = 1'b0;
                end
                begin
                    wait(tb_wvalid && tb_wready);
                    @(posedge tb_aclk);
                    tb_wvalid = 1'b0;
                end
            join

            wait(tb_bvalid && tb_bready);
            @(posedge tb_aclk);
            tb_bready = 1'b0;

            $display("[%0t] | Addr: 0x%0h | Data: 0x%0h | Strb: %b | Resp: %b",
                     $time, wr_addr, wr_data, wr_strobe, tb_rresp);
        end
    endtask

    task axi_read_with_delay;
        input [31:0] addr;
        input integer delay_cycles;
        begin
            @(posedge tb_aclk);
            tb_arvalid = 1;
            tb_araddr = addr;

            wait(tb_arvalid && tb_arready);
            @(posedge tb_aclk);
            tb_arvalid = 0;

            repeat(delay_cycles) @(posedge tb_aclk);
            tb_rready = 1;

            wait(tb_rvalid && tb_rready);
            @(posedge tb_aclk);
            tb_rready = 0;

            $display("[%0t] READ | Addr: 0x%0h | Data: 0x%0h | Resp: %b",
                    $time, addr, tb_rdata, tb_rresp);
        end
    endtask
    
    // Data Read Task
    task axi_read;
        input [31:0] read_address;
        begin
            @(posedge tb_aclk);
            tb_araddr  = read_address;
            tb_arvalid = 1'b1;
            tb_rready  = 1'b1; 
            
            wait(tb_arvalid && tb_arready);
            @(posedge tb_aclk);
            tb_arvalid = 1'b0; 
            
            wait(tb_rvalid && tb_rready);
            @(posedge tb_aclk);
            
            $display("[%0t] READ  | Addr: 0x%0h | Data: 0x%0h | Resp: %b", 
                     $time, read_address, tb_rdata, tb_rresp);
            tb_rready = 1'b0; 
        end
    endtask

    initial begin
        tb_aresetn = 0;
        tb_awvalid = 0; tb_awaddr = 0; tb_awprot = 0;
        tb_wvalid  = 0; tb_wdata  = 0; tb_wstrb  = 0; tb_bready = 0;
        tb_arvalid = 0; tb_araddr = 0; tb_arprot = 0; tb_rready = 0;

        #20
        tb_aresetn = 1;
        #20

        $display("---------------------------------------------------");
        $display("Test 1: Standard 32-bit Access");

        axi_write(32'h0000_0004, 32'hDEADBEEF, 4'b1111);
        #10

        axi_read(32'h0000_0004);

        $display("---------------------------------------------------");
        $display("Test 2: Byte-Lane Strobing");

        axi_write(32'h0000_0008, 32'h11223344, 4'b1111);
        #10
        axi_write(32'h0000_0008, 32'h00FF0000, 4'b0100); 
        #10

        axi_read(32'h0000_0008);

        $display("---------------------------------------------------");
        $display("Test 3: Out-of-Bounds Error Handling");

        axi_write(32'h0000_0400, 32'hBAD0BAD0, 4'b1111);
        #10
        axi_read(32'h0000_0400);
        
        $display("---------------------------------------------------");
        $display("Simulation Complete");
        #50
        $finish;
    end

endmodule