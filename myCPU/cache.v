module cache(
    input          clk_g    ,
    input          resetn   ,
    //CPU        
    input          valid    ,
    //1: write 0: read
    input          op       ,
    input  [  7:0] index    ,
    input  [ 19:0] tag      ,
    input  [  3:0] offset   ,
    input  [  3:0] wstrb    ,
    input  [ 31:0] wdata    ,
    output         addr_ok  ,
    output         data_ok  ,
    output [ 31:0] rdata    ,
    //AXI    
    output         rd_req   ,
    output [  2:0] rd_type  ,
    output [ 31:0] rd_addr  ,
    input          rd_rdy   ,
    input          ret_valid,
    input          ret_last ,
    input  [ 31:0] ret_data ,
    output         wr_req   ,
    output [  2:0] wr_type  ,
    output [ 31:0] wr_addr  ,
    output [  3:0] wr_wstrb ,
    output [127:0] wr_data  ,
    input          wr_rdy   
);
// state
parameter IDLE    = 3'd0;
parameter LOOKUP  = 3'd1;
parameter MISS    = 3'd2;
parameter REPLACE = 3'd3;
parameter REFILL  = 3'd4;
parameter IDLE_W  = 1'b0;
parameter WRITE_W = 1'b1;
reg [2:0] current_state;
reg [2:0] next_state;
reg       wr_current_state;
reg       wr_next_state;

reg       wr_req_reg;
wire      clk;
assign clk = clk_g;
// cache
// tag_v
wire        way0_tagv_we;
wire [ 7:0] way0_tagv_addr;
wire [20:0] way0_tagv_wdata;
wire [20:0] way0_tagv_rdata;
wire        way0_v;
wire [19:0] way0_tag;

wire        way1_tagv_we;
wire [ 7:0] way1_tagv_addr;
wire [20:0] way1_tagv_wdata;
wire [20:0] way1_tagv_rdata;
wire        way1_v;
wire [19:0] way1_tag;

//data_bank
wire [31:0] miss_bank_wdata;
wire [ 3:0] way0_data_bank_we [3:0];
wire [ 7:0] way0_data_bank_addr [3:0];
wire [31:0] way0_data_bank_wdata [3:0];
wire [31:0] way0_data_bank_rdata [3:0];
reg [255:0] way0_d;

wire [ 3:0] way1_data_bank_we [3:0];
wire [ 7:0] way1_data_bank_addr [3:0];
wire [31:0] way1_data_bank_wdata [3:0];
wire [31:0] way1_data_bank_rdata [3:0];
reg [255:0] way1_d;

wire [127:0] way0_data;
wire [127:0] way1_data;
wire [127:0] replace_data;

//req_buff;
reg         op_r;
reg [  7:0] index_r;
reg [ 19:0] tag_r;
reg [  3:0] offset_r;
reg [  3:0] wstrb_r;
reg [ 31:0] wdata_r;

// write buffer
reg         way_wr;
reg [  1:0] bank_wr;
reg [  7:0] index_wr;
reg [  3:0] wstrb_wr;
reg [ 31:0] wdata_wr;

// tag compare
wire way0_hit;
wire way1_hit;
wire cache_hit;
wire hit_write;
wire conflict_hit_write;

// data select
wire [31:0] way0_load_word;
wire [31:0] way1_load_word;

// miss buffer
reg [1:0] ret_cnt;
reg       replace_way_r;
reg [31:0] refill_data;

// request buffer
always @(posedge clk) begin
    if(~resetn) begin
        op_r <= 0;
        index_r <= 0;
        tag_r <= 0;
        offset_r <= 0;
        wstrb_r <= 0;
        wdata_r <= 0;
    end else if(addr_ok)begin
        op_r <= op;
        index_r <= index;
        tag_r <= tag;
        offset_r <= offset;
        wstrb_r <= wstrb;
        wdata_r <= wdata;
    end
end

// D_reg
always @(posedge clk) begin
    if(~resetn) begin
        way0_d <= 256'b0;
    end else if(wr_current_state == WRITE_W && !way_wr) begin
        way0_d[index_r] <= 1;
    end else if(ret_last && !replace_way) begin
        way0_d[index_r] <= op_r;
    end
end

always @(posedge clk) begin
    if(~resetn) begin
        way1_d <= 256'b0;
    end else if(wr_current_state == WRITE_W && way_wr) begin
        way1_d[index_r] <= 1;
    end else if(ret_last && replace_way) begin
        way1_d[index_r] <= op_r;
    end
end

// RAM
// tag_v
tagv_ram way0_tagv_ram(
    .clka  (clk),
    .wea   (way0_tagv_we),
    .addra (way0_tagv_addr), 
    .dina  (way0_tagv_wdata),
    .douta (way0_tagv_rdata)
);

tagv_ram way1_tagv_ram(
    .clka  (clk),
    .wea   (way1_tagv_we),
    .addra (way1_tagv_addr), 
    .dina  (way1_tagv_wdata),
    .douta (way1_tagv_rdata)
);

assign way0_tagv_we = ~replace_way & ret_last;
assign way0_tagv_addr = index_r;
assign way0_tagv_wdata = {tag_r, 1'b1};
assign way1_tagv_we = replace_way & ret_last;
assign way1_tagv_addr = index_r;
assign way1_tagv_wdata = {tag_r, 1'b1};

assign {way0_tag, way0_v} = way0_tagv_rdata;
assign {way1_tag, way1_v} = way1_tagv_rdata;

// data bank
genvar i;
generate
    for(i = 0; i < 4; i = i + 1) 
    begin: way0_data_bank
        data_bank way0_data_bank(
            .clka  (clk),
            .wea   (way0_data_bank_we[i]),
            .addra (way0_data_bank_addr[i]),
            .dina  (way0_data_bank_wdata[i]),
            .douta (way0_data_bank_rdata[i])
        );
    end 
endgenerate

genvar j;
generate
    for(j = 0; j < 4; j = j + 1) 
    begin: way1_data_bank
        data_bank way1_data_bank(
            .clka  (clk),
            .wea   (way1_data_bank_we[j]),
            .addra (way1_data_bank_addr[j]),
            .dina  (way1_data_bank_wdata[j]),
            .douta (way1_data_bank_rdata[j])
        );
    end 
endgenerate


assign way0_data_bank_we[0] = {4{!replace_way && ret_cnt == 0 && ret_valid}} | 
                              {4{wr_current_state == WRITE_W && !way_wr && bank_wr == 0}} & wstrb_wr;
assign way0_data_bank_we[1] = {4{!replace_way && ret_cnt == 1 && ret_valid}} | 
                              {4{wr_current_state == WRITE_W && !way_wr && bank_wr == 1}} & wstrb_wr;
assign way0_data_bank_we[2] = {4{!replace_way && ret_cnt == 2 && ret_valid}} | 
                              {4{wr_current_state == WRITE_W && !way_wr && bank_wr == 2}} & wstrb_wr;
assign way0_data_bank_we[3] = {4{!replace_way && ret_cnt == 3 && ret_valid}} | 
                              {4{wr_current_state == WRITE_W && !way_wr && bank_wr == 3}} & wstrb_wr;
assign way1_data_bank_we[0] = {4{replace_way && ret_cnt == 0 && ret_valid}} | 
                              {4{wr_current_state == WRITE_W && way_wr && bank_wr == 0}} & wstrb_wr;
assign way1_data_bank_we[1] = {4{replace_way && ret_cnt == 1 && ret_valid}} | 
                              {4{wr_current_state == WRITE_W && way_wr && bank_wr == 1}} & wstrb_wr;
assign way1_data_bank_we[2] = {4{replace_way && ret_cnt == 2 && ret_valid}} | 
                              {4{wr_current_state == WRITE_W && way_wr && bank_wr == 2}} & wstrb_wr;
assign way1_data_bank_we[3] = {4{replace_way && ret_cnt == 3 && ret_valid}} | 
                              {4{wr_current_state == WRITE_W && way_wr && bank_wr == 3}} & wstrb_wr;

assign miss_bank_wdata = {wstrb_r[3] & op_r ? wdata_r[31:24] : ret_data[31:24],
                          wstrb_r[2] & op_r ? wdata_r[23:16] : ret_data[23:16],
                          wstrb_r[1] & op_r ? wdata_r[15: 8] : ret_data[15: 8],
                          wstrb_r[0] & op_r ? wdata_r[ 7: 0] : ret_data[ 7: 0]};

genvar k;
generate
    for(k = 0; k < 4; k = k + 1) begin
        assign way0_data_bank_addr[k] = index_r;
        assign way1_data_bank_addr[k] = index_r;
        assign way0_data_bank_wdata[k] = wr_current_state == WRITE_W ? wdata_wr :
                                         ret_cnt == offset_r[3:2] ? miss_bank_wdata : ret_data;
        assign way1_data_bank_wdata[k] = wr_current_state == WRITE_W ? wdata_wr :
                                         ret_cnt == offset_r[3:2] ? miss_bank_wdata : ret_data;
    end
endgenerate

assign way0_data = {way0_data_bank_rdata[3],
                    way0_data_bank_rdata[2],
                    way0_data_bank_rdata[1],
                    way0_data_bank_rdata[0]};
assign way1_data = {way1_data_bank_rdata[3],
                    way1_data_bank_rdata[2],
                    way1_data_bank_rdata[1],
                    way1_data_bank_rdata[0]};

// tag compare
assign way0_hit = way0_v && (way0_tag == tag_r);
assign way1_hit = way1_v && (way1_tag == tag_r);
assign cache_hit = way0_hit || way1_hit;
assign hit_write = op_r && (current_state == LOOKUP) && cache_hit;
assign conflict_hit_write = ~op && ((wr_current_state == WRITE_W) && offset[3:2] == bank_wr ||
                            current_state == LOOKUP && hit_write && {index, offset} == {index_r, offset_r});

// data select
assign way0_load_word = way0_data[offset_r[3:2]*32 +: 32];
assign way1_load_word = way1_data[offset_r[3:2]*32 +: 32];
assign load_res  = {32{way0_hit}} & way0_load_word |
                   {32{way1_hit}} & way1_load_word ;


// miss buffer
always @(posedge clk) begin
    if(~resetn) begin
        replace_way_r <= 0;
    end else if (ret_last) begin
        replace_way_r <= ~replace_way_r;
    end
end
assign replace_way = replace_way_r;

assign replace_data = replace_way ? way1_data : way0_data;

always @(posedge clk) begin
    if(~resetn) begin
        ret_cnt <= 0;
    end
    else if(current_state == REFILL && ret_last) begin
        ret_cnt <= 0;
    end
    else if(current_state == REFILL && ret_valid) begin
        ret_cnt <= ret_cnt + 1;
    end
end

// write buffer
always @(posedge clk) begin
    if(~resetn) begin
        way_wr <= 0;
        bank_wr <= 0;
        index_wr <= 0;
        wstrb_wr <= 0;
        wdata_wr <= 0;
    end else if(hit_write) begin
        way_wr <= ~way0_hit & way1_hit;
        bank_wr <= offset_r[3:2];
        index_wr <= index_r;
        wstrb_wr <= wstrb_r;
        wdata_wr <= wdata_r;
    end
end

// state machine
always @(posedge clk) begin
    if(~resetn) begin
        current_state <= IDLE;
    end
    else begin
        current_state <= next_state;
    end
end

always @(*)begin
    case(current_state)
        IDLE: begin
            if(valid && !conflict_hit_write) begin
                next_state = LOOKUP;
            end else begin
                next_state = current_state;
            end
        end
        LOOKUP: begin
            if(cache_hit && (!valid || valid && conflict_hit_write)) begin
                next_state = IDLE;
            end
            else if(cache_hit && valid) begin
                next_state = LOOKUP;
            end
            else begin
                next_state = MISS;
            end
        end
        MISS: begin
            if(wr_rdy) begin
                next_state = REPLACE;
            end
            else begin
                next_state = current_state;
            end
        end
        REPLACE: begin
            if(rd_rdy) begin
                next_state = REFILL;
            end
            else begin
                next_state = current_state;
            end
        end
        REFILL: begin
            if(ret_valid && ret_last) begin
                next_state = IDLE;
            end
            else begin
                next_state = current_state;
            end
        end

        default:
            next_state = current_state;
    endcase
end

// write state machine
always @(posedge clk) begin
    if(~resetn) begin
        wr_current_state <= IDLE_W;
    end else begin
        wr_current_state <= wr_next_state;
    end
end

always @(*) begin
    case(wr_current_state)
        IDLE_W: begin
            if(hit_write) begin
                wr_next_state = WRITE_W;
            end
            else begin
                wr_next_state = IDLE_W;
            end
        end
        WRITE_W: begin
            if(hit_write) begin
                wr_next_state = WRITE_W;
            end
            else begin
                wr_next_state = IDLE_W;
            end
        end
        default:
            wr_next_state = wr_current_state;
    endcase
end

assign addr_ok = current_state == IDLE ||
                 current_state == LOOKUP && next_state  == LOOKUP;

assign data_ok = current_state == LOOKUP && (cache_hit && !op_r) ||
                 wr_current_state == WRITE_W ||
                 current_state == REFILL && ret_valid && ret_cnt == offset_r[3:2];
                
assign rd_req = current_state == REPLACE;

always @(posedge clk) begin
    if(~resetn) begin
        refill_data <= 0;
    end else if(ret_cnt == offset_r[3:2] && ret_valid) begin
        refill_data <= ret_data;
    end
end

always @(posedge clk) begin
    if(~resetn || current_state == REPLACE) begin
        wr_req_reg <= 0;
    end else if(wr_rdy) begin 
        wr_req_reg <= 1;
    end
end

assign rdata =  ret_valid ? ret_data : load_res;
assign wr_data = replace_data;

assign wr_req = wr_req_reg && current_state == REPLACE && 
                (replace_way ? way1_d[index_r] & way1_v: way0_d[index_r] & way0_v);

assign rd_type = 3'b100;
assign rd_addr = {tag_r, index_r, 4'b0};
assign wr_type = 3'b100;
assign wr_addr = {replace_way ? way1_tag : way0_tag, index_r, 4'b0};
assign wr_wstrb = 4'b0;

endmodule