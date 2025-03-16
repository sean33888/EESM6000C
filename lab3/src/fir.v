`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/03/09 23:06:29
// Design Name: 
// Module Name: fir
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
(* use_dsp = "no" *)
module fir 
#( 
    parameter pADDR_WIDTH = 12,
    parameter pDATA_WIDTH = 32,
    parameter Tape_Num    = 11
)
(
    output reg                     awready,
    output reg                     wready,
    input wire                     awvalid,
    input wire [(pADDR_WIDTH-1):0] awaddr,
    input wire                     wvalid,
    input wire [(pDATA_WIDTH-1):0] wdata,
    output reg                     arready,
    input wire                     rready,
    input wire                     arvalid,
    input wire [(pADDR_WIDTH-1):0] araddr,
    output reg                     rvalid,
    output reg [(pDATA_WIDTH-1):0] rdata,    
    input wire                     ss_tvalid, 
    input wire [(pDATA_WIDTH-1):0] ss_tdata, 
    input wire                     ss_tlast, 
    output reg                     ss_tready, 
    input wire                     sm_tready, 
    output reg                     sm_tvalid, 
    output reg [(pDATA_WIDTH-1):0] sm_tdata, 
    output reg                     sm_tlast, 
    
    // BRAM for tap RAM
    output reg [3:0]               tap_WE,
    output reg                     tap_EN,
    output reg [(pDATA_WIDTH-1):0] tap_Di,
    output reg [(pADDR_WIDTH-1):0] tap_A,
    input wire [(pDATA_WIDTH-1):0] tap_Do,

    // BRAM for data RAM
    output reg [3:0]               data_WE,
    output reg                     data_EN,
    output reg [(pDATA_WIDTH-1):0] data_Di,
    output reg [(pADDR_WIDTH-1):0] data_A,
    input wire [(pDATA_WIDTH-1):0] data_Do,

    input wire                     axis_clk,
    input wire                     axis_rst_n
);

integer k1 = 0;
reg [2:0] ap;
reg [31:0] sum;
reg first;
reg [1:0] clk_count;
reg [11:0] data_A_prev = 0;
reg [31:0] data_Di_prev [0:11-1];
reg [11:0] ss_tdata_prev = 0;
integer i = 0;
integer j = 10; 
integer cal = 0;
always @(posedge axis_clk or negedge axis_rst_n) begin
    if (!axis_rst_n) begin
        awready <= 0;
        wready <= 0;
        arready <= 0;
        rvalid <= 0;
        ss_tready <= 0;
        sm_tvalid <= 0;
        sm_tlast <= 0;
        tap_EN <= 0;
        data_EN <= 0;
        rdata <= 0;
        ap <= 0;
        first <= 0;
        clk_count <= 0;
        for (i = 0; i < 11; i = i + 1) begin
            data_Di_prev[i] <= 32'b0;
        end
    end
end

always @(posedge axis_clk) begin 
    if(ap == 0)begin
        ap[2] <= 1;
        ap[1] <= 0;
    end else if(wdata == 32'h1)begin
        ap[2] <= 0;
        ap[0] <= 1;
    end else if(sm_tlast == 1 && ss_tready)begin
        ap[0] <= 0;
        ap[1] <= 1;
    end
end


always @(*) begin
    if(ap[2]==1)begin
        if (awvalid) begin
            wready <= 1;
        end else begin
            wready <=0;
        end
        awready = awvalid & ~awready;
        if(rready)begin
            arready = rready;
        end else begin
            arready = 0;
        end 
    end
end

always @(posedge axis_clk && ap[2]==1) begin
        if (awvalid) begin
            tap_Di <= wdata;   
            arready <= 0;
            rvalid <= 0;
        end else begin
            rvalid = 1;
        end
        if(arvalid)begin
            rdata <= tap_Do; 
        end        
        tap_EN = ~arvalid | wready & wvalid;
        tap_WE[0] = wready & wvalid;
        tap_WE[1] = wready & wvalid;
        tap_WE[2] = wready & wvalid;
        tap_WE[3] = wready & wvalid;
end

always @(posedge axis_clk&& ap[2]==1) begin
    if (tap_WE && wready)begin
        tap_A = awaddr -12'h20;
    end else if(arvalid) begin
        tap_A = araddr -12'h20;
    end else begin
        tap_A = 3'b0;
    end
    tap_Di = wdata;
end
       

always @(posedge axis_clk && ap[0]==1) begin
    if(wvalid && first == 0)begin
        tap_WE[0] = 1;
        tap_WE[1] = 1;
        tap_WE[2] = 1;
        tap_WE[3] = 1;
        tap_Di = 12'd1;
        first <= 1;
        tap_A = 12'hfe0;
        awready = 0;
        wready = 0;
        data_Di = 32'h1;
    end else if(wvalid && first == 1)begin
        data_A_prev = tap_A;
        if(clk_count != 2'b11)begin
            clk_count <= clk_count + 1;
        end else begin
            clk_count <= 2'b01;
        end   
        if(tap_A == 12'hfe0)begin
            k1 <= 0;
        end else if(k1 != Tape_Num + 1 && tap_EN == 1)begin
            k1 <= k1 + 1;
            sm_tvalid <= 0;
        end else if(k1 == Tape_Num + 1)begin
            k1 <= 0;
            sm_tvalid <= 1;
            data_Di = ss_tdata;
            ss_tdata_prev = ss_tdata;
        end else if(k1 == 0 && tap_EN == 0) begin
            k1 <= k1 + 1;
        end
        awready = ~clk_count[1];
        wready = ~clk_count[1];
        if(k1 != Tape_Num + 1 && k1 != 0)begin
            tap_A <= (araddr - 12'h20 - 4*k1) & {32{data_EN}};
            data_EN <= data_EN + 1;
            tap_EN <= data_EN + 1;
            data_WE[0] <= data_EN + 1;
            data_WE[1] <= data_EN + 1;
            data_WE[2] <= data_EN + 1;
            data_WE[3] <= data_EN + 1;  
            data_A <= ((araddr - 12'h20 - 4*k1 - 12'h4) & {32{data_EN}}) | (data_A_prev & {32{!data_EN}});
        end else if(tap_A == 12'hfe0)begin
            tap_A <= araddr - 12'h20 - 4*k1;
            data_EN <= 0;
            tap_EN <= 0;
            data_WE[0] <= 0;
            data_WE[1] <= 0;
            data_WE[2] <= 0;
            data_WE[3] <= 0; 
            data_A <= araddr - 12'h20 - 4*k1 - 12'h4;            
        end else begin 
            data_A <= araddr - 12'h20 - 4 * k1 - 12'h4;
            tap_A <= 0;
            data_EN <= 0;
            tap_EN <= 0;   
        end
        tap_WE <= 0;
        tap_Di <= 0;
        ss_tready = sm_tvalid; 
        if(ss_tready == 1)begin
            sm_tvalid = 0;
        end
    end
end

always @(posedge ss_tready)begin
    for (i = 0; i < 10; i = i + 1) begin
        data_Di_prev[i] <= data_Di_prev[i + 1];
    end
    data_Di_prev[Tape_Num - 1] <= ss_tdata;
end

always @(posedge axis_clk)begin
    cal <= data_Di_prev[k1]*tap_Do;
    if(tap_Do == 0 && wvalid)begin
        data_Di <= data_Di_prev[k1];
        j <= j - 1;
    end else if(wvalid)begin
        data_Di = ss_tdata;
    end
    if(j == 0)begin
        j <= 10;
    end
//    if(ss_tdata != 32'h00000000)begin
        if(cal === 'bx && sm_tdata === 'bx)begin
            sm_tdata = 0;
        end else if(data_Di === 'bx)begin
            sm_tdata = sm_tdata;
        end else if(sm_tdata === 'bx)begin
            sm_tdata = 0;
        end else begin
            sm_tdata = sm_tdata + cal;
        end
//    end
    if(ss_tdata == 32'hffffffff)begin
        sm_tlast <= 1;
    end
end
always @(negedge ss_tready && ss_tdata!=32'h00000000)begin
    sm_tdata = 0;
end
endmodule






