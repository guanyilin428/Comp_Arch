    module axi_bridge(    
    input               clk,
    input               reset,
    //read request
    output  [ 3:0]      arid,//0:inst,1:data
    output  [31:0]      araddr,
    output  [ 7:0]      arlen,//0
    output  [ 2:0]      arsize,
    output  [ 1:0]      arburst,//1
    output  [ 1:0]      arlock,//0
    output  [ 3:0]      arcache,//0
    output  [ 2:0]      arprot,//0
    output              arvalid,
    input               arready,
    //read response
    input   [ 3:0]      rid,//0:inst,1:data
    input   [31:0]      rdata,
    input   [ 1:0]      rresp,//ignore
    input               rlast,//ignore
    input               rvalid,
    output              rready,
    //write request
    output  [ 3:0]      awid,//1
    output  [31:0]      awaddr,
    output  [ 7:0]      awlen,//0
    output  [ 2:0]      awsize,
    output  [ 1:0]      awburst,//1
    output  [ 1:0]      awlock,//0
    output  [ 3:0]      awcache,//0
    output  [ 2:0]      awprot,//0
    output              awvalid,
    input               awready,
    //write data
    output  [ 3:0]      wid,//1
    output  [31:0]      wdata,
    output  [ 3:0]      wstrb,
    output              wlast,//1
    output              wvalid,
    input               wready,
    //write response
    input   [ 3:0]      bid,//ignore
    input   [ 1:0]      bresp,//ignore
    input               bvalid,
    output              bready,
    // inst sram interface
    input               inst_sram_req,
    input               inst_sram_wr,
    input   [ 3:0]      inst_sram_wstrb,
    input   [31:0]      inst_sram_addr,
    input   [31:0]      inst_sram_wdata,
    output  [31:0]      inst_sram_rdata,
    input   [ 1:0]      inst_sram_size,
    output              inst_sram_addr_ok, 
    output              inst_sram_data_ok, 
    // data sram interface
    input               data_sram_req,
    input               data_sram_wr,
    input   [ 3:0]      data_sram_wstrb,
    input   [31:0]      data_sram_addr,
    input   [31:0]      data_sram_wdata,
    output  [31:0]      data_sram_rdata,
    input   [ 1:0]      data_sram_size,
    output              data_sram_addr_ok,
    output              data_sram_data_ok
);

assign arlen   = 8'b00000000;
assign arburst = 2'b01;
assign arlock  = 2'b00;
assign arcache = 4'b0000;
assign arprot  = 3'b000;

assign awid    = 4'b1;
assign awlen   = 8'b00000000;
assign awburst = 2'b01;
assign awlock  = 2'b00;
assign awcache = 4'b0000;
assign awprot  = 3'b000;

assign wid     = 4'b1;
assign wlast   = 1'b1;

wire inst_arreq;
wire data_arreq;
wire now_arreq;
wire [31:0] now_araddr;
wire [ 2:0] now_arsize;
wire [ 3:0] now_arid;

reg        ar_req;
reg [31:0] araddr_r;
reg [ 2:0] arsize_r;
reg [ 3:0] arid_r;

wire data_awreq;
wire now_awreq;
wire [31:0] now_awaddr;
wire [ 2:0] now_awsize;

reg        aw_req;
reg [31:0] awaddr_r;
reg [ 2:0] awsize_r;

wire [31:0]now_wdata;
wire [ 3:0]now_wstrb;

reg w_write;
reg [3:0]  wstrb_r;
reg [31:0] wdata_r;

//wire data_sram_rdata_ok;
//wire data_sram_wdata_ok;
wire data_sram_raddr_ok;
wire data_sram_waddr_ok;
wire data_relate;

assign inst_arreq = inst_sram_req & ~inst_sram_wr & inst_sram_addr_ok;
assign data_arreq = data_sram_req & ~data_sram_wr & data_sram_addr_ok;//sram_wr=0:read;1:write
assign now_arreq  = inst_arreq | data_arreq;
assign now_araddr = data_arreq ? data_sram_addr : inst_sram_addr;
assign now_arsize = data_arreq ? {1'b0,data_sram_size} :  {1'b0,inst_sram_size};
assign now_arid   = data_arreq ? 4'b1 : 4'b0;

assign araddr = araddr_r;
assign arsize = arsize_r;
assign arid   = arid_r;
assign arvalid= ar_req;

always @(posedge clk) begin
    if(reset) 
        ar_req <= 1'b0;
    else if(~ar_req & now_arreq & ~arready) begin 
        ar_req   <= 1'b1;
        arid_r   <= now_arid;
        araddr_r <= now_araddr;
        arsize_r <= now_arsize;
    end
    else if(ar_req & arready) 
        ar_req <= 1'b0;
end

assign rready = 1'b1;
assign inst_sram_data_ok = rvalid && rid == 4'b0;
assign data_sram_data_ok = bvalid | (rvalid && rid == 4'b1);
assign inst_sram_rdata   = rdata;
assign data_sram_rdata   = rdata;


assign data_awreq = data_sram_req &  data_sram_wr & data_sram_addr_ok; 

assign now_awreq  = data_awreq;
assign now_awaddr = data_sram_addr;
assign now_awsize = {1'b0,data_sram_size};

assign awaddr = awaddr_r;
assign awsize = awsize_r;
assign awvalid= aw_req;

always @(posedge clk) begin
    if(reset) 
        aw_req <= 1'b0;
    else if(~aw_req & now_awreq & ~awready) begin
        aw_req   <= 1'b1;
        awaddr_r <= now_awaddr;
        awsize_r <= now_awsize;
    end
    else if(aw_req & awready) 
        aw_req <= 1'b0;
end

assign now_wstrb  = data_sram_wstrb;
assign now_wdata  = data_sram_wdata;

assign wstrb = wstrb_r;
assign wdata = wdata_r;
assign wvalid= w_write;

always @(posedge clk) begin
    if(reset) 
        w_write <= 1'b0;
    else if(~w_write & now_awreq & ~wready) begin 
        w_write <= 1'b1;
        wstrb_r <= now_wstrb;
        wdata_r <= now_wdata;
    end
    else if(w_write & wready) 
        w_write <= 1'b0;
end

assign bready = 1'b1;
reg write_unfinish;
always @(posedge clk) begin
    if(reset) 
        write_unfinish <= 1'd0;
    else if(~write_unfinish & data_awreq) 
        write_unfinish <= 1'd1;
    else if(write_unfinish & bvalid & ~data_awreq)
        write_unfinish <= 1'd0;
end

assign data_relate = data_sram_addr[31:2] == awaddr_r[31:2];

assign data_sram_waddr_ok = bvalid  | ~write_unfinish;
assign data_sram_raddr_ok = ~ar_req & ~(data_relate & ~data_sram_waddr_ok);
assign data_sram_addr_ok  = data_sram_wr ? data_sram_waddr_ok : data_sram_raddr_ok;

assign inst_sram_addr_ok  = ~ar_req & ~data_arreq;

endmodule