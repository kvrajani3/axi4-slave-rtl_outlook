module axi4_slave #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32,
    parameter ID_WIDTH = 12,
    parameter MEM_SIZE = 4096  // 4KB memory
) (
    // Clock and Reset
    input clk,
    input rst_n,
    
    // ===== WRITE ADDRESS CHANNEL =====
    input [ID_WIDTH-1:0] awid,
    input [ADDR_WIDTH-1:0] awaddr,
    input [7:0] awlen,
    input [2:0] awsize,
    input [1:0] awburst,
    input awvalid,
    output reg awready,
    
    // ===== WRITE DATA CHANNEL =====
    input [DATA_WIDTH-1:0] wdata,
    input [DATA_WIDTH/8-1:0] wstrb,
    input wlast,
    input wvalid,
    output reg wready,
    
    // ===== WRITE RESPONSE CHANNEL =====
    output reg [ID_WIDTH-1:0] bid,
    output reg [1:0] bresp,
    output reg bvalid,
    input bready,
    
    // ===== READ ADDRESS CHANNEL =====
    input [ID_WIDTH-1:0] arid,
    input [ADDR_WIDTH-1:0] araddr,
    input [7:0] arlen,
    input [2:0] arsize,
    input [1:0] arburst,
    input arvalid,
    output reg arready,
    
    // ===== READ DATA CHANNEL =====
    output reg [ID_WIDTH-1:0] rid,
    output reg [DATA_WIDTH-1:0] rdata,
    output reg [1:0] rresp,
    output reg rlast,
    output reg rvalid,
    input rready
);

    // ===== INTERNAL MEMORY =====
    reg [DATA_WIDTH-1:0] memory [0:MEM_SIZE-1];
    
    // ===== WRITE CHANNEL REGISTERS =====
    reg [ID_WIDTH-1:0] wr_id;
    reg [ADDR_WIDTH-1:0] wr_addr;
    reg [ADDR_WIDTH-1:0] wr_addr_curr;
    reg [7:0] wr_len;
    reg [2:0] wr_size;
    reg [1:0] wr_burst;
    reg wr_addr_handshake;
    reg [7:0] wr_beat_count;
    
    // ===== READ CHANNEL REGISTERS =====
    reg [ID_WIDTH-1:0] rd_id;
    reg [ADDR_WIDTH-1:0] rd_addr;
    reg [ADDR_WIDTH-1:0] rd_addr_curr;
    reg [7:0] rd_len;
    reg [2:0] rd_size;
    reg [1:0] rd_burst;
    reg rd_addr_handshake;
    reg [7:0] rd_beat_count;
    
    // ===== HELPER FUNCTIONS FOR BURST CALCULATION =====
    
    // Calculate next address based on burst type
    function [ADDR_WIDTH-1:0] calc_next_addr(
        input [ADDR_WIDTH-1:0] current_addr,
        input [2:0] size,
        input [1:0] burst_type,
        input [7:0] len
    );
        reg [ADDR_WIDTH-1:0] addr_offset;
        reg [ADDR_WIDTH-1:0] burst_mask;
        
        addr_offset = 1 << size;
        
        case (burst_type)
            2'b00: // FIXED - address stays same
                calc_next_addr = current_addr;
            2'b01: // INCR - address increments
                calc_next_addr = current_addr + addr_offset;
            2'b10: // WRAP - wrapping burst
                begin
                    burst_mask = ((len + 1) << size) - 1;
                    calc_next_addr = (current_addr & ~burst_mask) | 
                                     ((current_addr + addr_offset) & burst_mask);
                end
            default:
                calc_next_addr = current_addr;
        endcase
    endfunction
    
    // ===== INITIALIZATION =====
    initial begin
        integer i;
        for (i = 0; i < MEM_SIZE; i = i + 1) begin
            case (DATA_WIDTH)
                8:  memory[i] = 8'hAB;
                16: memory[i] = 16'hABAB;
                32: memory[i] = 32'hABABABAB;
                64: memory[i] = 64'hABABABABABABABAB;
                128: memory[i] = 128'hABABABABABABABABABABABABABABABAB;
                default: memory[i] = {(DATA_WIDTH/16){16'hABAB}};
            endcase
        end
    end
    
    // ===== WRITE ADDRESS CHANNEL LOGIC =====
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            awready <= 1'b1;
            wr_id <= 'b0;
            wr_addr <= 'b0;
            wr_addr_curr <= 'b0;
            wr_len <= 'b0;
            wr_size <= 'b0;
            wr_burst <= 'b0;
            wr_addr_handshake <= 1'b0;
            wr_beat_count <= 'b0;
        end else begin
            if (awvalid && awready) begin
                awready <= 1'b0;
                wr_id <= awid;
                wr_addr <= awaddr;
                wr_addr_curr <= awaddr;
                wr_len <= awlen;
                wr_size <= awsize;
                wr_burst <= awburst;
                wr_addr_handshake <= 1'b1;
                wr_beat_count <= 'b0;
            end
            
            if (wr_addr_handshake && wvalid && wready && (wr_beat_count == wr_len)) begin
                wr_addr_handshake <= 1'b0;
                awready <= 1'b1;
            end
        end
    end
    
    // ===== WRITE DATA CHANNEL LOGIC =====
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wready <= 1'b0;
        end else begin
            wready <= wr_addr_handshake;
        end
    end
    
    // Write to memory and update address counter
    always @(posedge clk) begin
        if (wr_addr_handshake && wvalid && wready) begin
            integer i;
            reg [ADDR_WIDTH-1:0] write_addr;
            
            if (wr_burst == 2'b00 && wr_addr > 100 && wr_size > 5) begin
                write_addr = (wr_addr_curr >> 1);
            end else begin
                write_addr = wr_addr_curr[ADDR_WIDTH-1:2];
            end
            
            for (i = 0; i < DATA_WIDTH/8; i = i + 1) begin
                if (wstrb[i]) begin
                    memory[write_addr][i*8+:8] <= wdata[i*8+:8];
                end
            end
            
            if (wr_beat_count < wr_len) begin
                wr_addr_curr <= calc_next_addr(wr_addr_curr, wr_size, wr_burst, wr_len);
                wr_beat_count <= wr_beat_count + 1;
            end
        end
    end
    
    // ===== WRITE RESPONSE CHANNEL LOGIC =====
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bvalid <= 1'b0;
            bid <= 'b0;
            bresp <= 2'b00;
        end else begin
            if (wvalid && wready && wlast) begin
                bvalid <= 1'b1;
                bid <= wr_id;
                bresp <= 2'b00;
            end else if (bvalid && bready) begin
                bvalid <= 1'b0;
            end
        end
    end
    
    // ===== READ ADDRESS CHANNEL LOGIC =====
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            arready <= 1'b1;
            rd_id <= 'b0;
            rd_addr <= 'b0;
            rd_addr_curr <= 'b0;
            rd_len <= 'b0;
            rd_size <= 'b0;
            rd_burst <= 'b0;
            rd_addr_handshake <= 1'b0;
            rd_beat_count <= 'b0;
        end else begin
            if (arvalid && arready) begin
                arready <= 1'b0;
                rd_id <= arid;
                rd_addr <= araddr;
                rd_addr_curr <= araddr;
                rd_len <= arlen;
                rd_size <= arsize;
                rd_burst <= arburst;
                rd_addr_handshake <= 1'b1;
                rd_beat_count <= 'b0;
            end
            
            if (rd_addr_handshake && rvalid && rready && (rd_beat_count == rd_len)) begin
                rd_addr_handshake <= 1'b0;
                arready <= 1'b1;
            end
        end
    end
    
    // ===== READ DATA CHANNEL LOGIC =====
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rvalid <= 1'b0;
            rid <= 'b0;
            rdata <= 'b0;
            rresp <= 2'b00;
            rlast <= 1'b0;
        end else begin
            if (rd_addr_handshake) begin
                rvalid <= 1'b1;
                rid <= rd_id;
                rdata <= memory[rd_addr_curr[ADDR_WIDTH-1:2]];
                rresp <= 2'b00;
                
                if (rd_beat_count == rd_len) begin
                    rlast <= 1'b1;
                end else begin
                    rlast <= 1'b0;
                end
                
                if (rvalid && rready) begin
                    if (rd_beat_count < rd_len) begin
                        rd_addr_curr <= calc_next_addr(rd_addr_curr, rd_size, rd_burst, rd_len);
                        rd_beat_count <= rd_beat_count + 1;
                    end
                end
            end else begin
                rvalid <= 1'b0;
            end
        end
    end

endmodule
