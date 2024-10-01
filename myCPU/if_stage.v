`include "mycpu.h"

module if_stage(
    input                          clk            ,
    input                          reset          ,
    //allwoin
    input                          ds_allowin     ,
    //brbus
    input  [`BR_BUS_WD       -1:0] br_bus         ,
    //to ds
    output                         fs_to_ds_valid ,
    output [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus   ,
    // inst sram interface
    output        inst_sram_req   ,
    output        inst_sram_wr    ,
    output [ 3:0] inst_sram_wstrb ,
    output [31:0] inst_sram_addr ,
    output [31:0] inst_sram_wdata,
    input  [31:0] inst_sram_rdata,
    output [ 1:0] inst_sram_size,
    input         inst_sram_addr_ok,
    input         inst_sram_data_ok,
    //exception
    input  [`WS_FLUSH_FS_BUS_WD-1:0] ws_flush_fs_bus,
    //csr
    input  [`TO_FS_CSR_BUS_WD -1:0] to_fs_csr_bus,
    // search port 0 (for fetch)
    output [              18:0] s0_vppn,
    output                      s0_va_bit12,
    output [               9:0] s0_asid,
    input                       s0_found,
    input  [               3:0] s0_index,
    input  [              19:0] s0_ppn,
    input  [               5:0] s0_ps,
    input  [               1:0] s0_plv,
    input  [               1:0] s0_mat,
    input                       s0_d,
    input                       s0_v

);

//pre-fs
wire       prfs_ready_go;
wire       to_fs_valid;
reg        prfs_flush_taken;
reg        prfs_br_taken;
reg [31:0] prfs_br_target;
reg [31:0] prfs_ex_entry;


reg         fs_valid;
wire        fs_ready_go;
wire        fs_allowin;
reg         cancel_reg;
reg         cancel_flush_reg;
reg         cancel_three;


wire [31:0] seq_pc;
wire [31:0] nextpc;

wire [31:0] csr_asid_rvalue;
wire [31:0] csr_crmd_rvalue;
wire [31:0] csr_dmw1_rvalue;
wire [31:0] csr_dmw0_rvalue;
wire        csr_crmd_da;
wire        csr_crmd_pg;
wire [ 1:0] csr_crmd_plv;

wire [31:0] drct_map_pa;
wire [31:0] tlb_map_pa;
wire        is_drct_trans;
wire        is_map_trans;
wire        is_tlb_trans;
wire        drct_map_hit;
wire        dmw0_hit;
wire        dmw1_hit;

wire        fs_tlb_refill;
wire        inst_page_fault;
wire        fs_plv_illegal;
wire        fs_mmu_ex;

wire         br_stall;
wire         br_taken;
wire [ 31:0] br_target;
assign {br_stall,br_taken,br_target} = br_bus;

wire [31:0] fs_inst;
reg  [31:0] fs_buff_inst;
reg         fs_buff_valid;

reg  [31:0] fs_pc;

wire ex_ADEF = (|nextpc[1:0]) | (&csr_crmd_plv & nextpc[31]);

assign fs_to_ds_bus = {fs_mmu_ex,
                       fs_tlb_refill,
                       inst_page_fault,
                       fs_plv_illegal,
                       ex_ADEF,
                       fs_inst,
                       fs_pc  };

wire flush_taken;
wire [31:0]ex_entry;//exception_entry
assign {flush_taken,ex_entry} = ws_flush_fs_bus;

// pre-IF stage
assign to_fs_valid  = ~reset & prfs_ready_go; // prfs_valid == 1
assign seq_pc       = fs_pc + 3'h4;
assign nextpc       = flush_taken   ? ex_entry :
                      prfs_flush_taken ? prfs_ex_entry :
                      br_taken      ? br_target : 
                      prfs_br_taken ? prfs_br_target : seq_pc;

//analysis csr
assign {csr_dmw0_rvalue, csr_dmw1_rvalue, csr_crmd_rvalue, csr_asid_rvalue} = to_fs_csr_bus;
assign csr_crmd_da = csr_crmd_rvalue[`CSR_CRMD_DA];
assign csr_crmd_pg = csr_crmd_rvalue[`CSR_CRMD_PG];
assign csr_crmd_plv = csr_crmd_rvalue[`CSR_CRMD_PLV];

// fetch port to tlb module
assign s0_vppn = nextpc[31:13];
assign s0_va_bit12 = nextpc[12];
assign s0_asid = csr_asid_rvalue[9:0];

// addr translation
assign drct_map_pa = {32{dmw0_hit}} & {csr_dmw0_rvalue[27:25], nextpc[28:0]} |
                     {32{dmw1_hit}} & {csr_dmw1_rvalue[27:25], nextpc[28:0]}; //crmd_pseg
assign tlb_map_pa  = {32{s0_ps==6'd22}} & {s0_ppn[19:10], nextpc[21:0]}|
                     {32{s0_ps==6'd12}} & {s0_ppn[19: 0], nextpc[11:0]};
assign is_drct_trans = csr_crmd_da & ~csr_crmd_pg;
assign is_map_trans  = ~csr_crmd_da & csr_crmd_pg;
assign is_tlb_trans  = is_map_trans & ~drct_map_hit;
assign drct_map_hit = dmw0_hit | dmw1_hit;
assign dmw0_hit = (csr_dmw0_rvalue[31:29] == nextpc[31:29]) && // vseg_legal
                      ((&csr_crmd_plv && csr_dmw0_rvalue[3])||
                      (~|csr_crmd_plv && csr_dmw0_rvalue[0]));
assign dmw1_hit = (csr_dmw1_rvalue[31:29] == nextpc[31:29]) && // vseg_legal
                      ((&csr_crmd_plv && csr_dmw1_rvalue[3])||
                      (~|csr_crmd_plv && csr_dmw1_rvalue[0])); 

// tlb ex
assign fs_tlb_refill = ~s0_found & is_tlb_trans;
assign inst_page_fault = s0_found & ~s0_v & is_tlb_trans;
assign fs_plv_illegal = s0_found & s0_v & (csr_crmd_plv > s0_plv)& is_tlb_trans;
assign fs_mmu_ex = fs_tlb_refill | inst_page_fault | fs_plv_illegal;

assign prfs_ready_go = inst_sram_addr_ok & inst_sram_req; // | fs_mmu_ex & fs_allowin;

always @(posedge clk) begin
    if(reset | prfs_ready_go) begin
        prfs_flush_taken <= 0;
        prfs_br_taken <= 0;
        prfs_br_target <= 0;
        prfs_ex_entry <= 0;
    end
    else if(flush_taken) begin
        prfs_flush_taken <= 1;
        prfs_ex_entry    <= ex_entry;
    end
    else if(br_taken) begin
        prfs_br_taken <= 1;
        prfs_br_target <= br_target;
    end
end

// IF stage
assign fs_ready_go    = (inst_sram_data_ok | fs_buff_valid) & ~cancel_reg;
assign fs_allowin     = ~fs_valid | fs_ready_go & ds_allowin;
assign fs_to_ds_valid =  fs_valid && fs_ready_go; 

always @(posedge clk) begin
    if (reset) begin
        fs_valid <= 1'b0;
    end
    else if (flush_taken & ~to_fs_valid) begin
        fs_valid <= 1'b0;
    end 
    else if(fs_allowin)begin
        fs_valid <= to_fs_valid;
    end
    else if(br_taken) begin
        fs_valid <= 1'b0;
    end
    if (reset) begin
        fs_pc <= 32'h1bfffffc;  //trick: to make nextpc be 0x1c000000 during reset 
    end
    else if (to_fs_valid && fs_allowin) begin
        fs_pc <= nextpc;
    end
end

always @(posedge clk) begin
    if(reset) begin
        cancel_reg <= 0;
    end
    else if( ~fs_ready_go & ~fs_allowin & (flush_taken | br_taken)) begin
        cancel_reg <= 1;
    end
    else if(inst_sram_data_ok) begin
        cancel_reg <= cancel_flush_reg;
    end
    
    if (reset) begin
        cancel_flush_reg <= 0;
    end
    else if ( ~fs_ready_go & ~fs_allowin & (flush_taken | br_taken) & cancel_reg & ~inst_sram_data_ok) begin
        cancel_flush_reg <= 1;
    end
    else if (inst_sram_data_ok) begin
        cancel_flush_reg <= cancel_three;
    end
    
    if (reset) begin
        cancel_three <= 0;
    end
    else if ( ~fs_ready_go & ~fs_allowin & (flush_taken | br_taken) & cancel_flush_reg) begin
        cancel_three <= 1;
    end
    else if (inst_sram_data_ok) begin
        cancel_three <= 0;
    end
end

// fs_buff
always @(posedge clk) begin
    if(reset | flush_taken) begin
        fs_buff_valid <= 0;
        fs_buff_inst <= 32'b0;
    end
    else if(inst_sram_data_ok & ~ds_allowin) begin
        fs_buff_inst <= inst_sram_rdata;
        fs_buff_valid <= 1'b1;
    end
    else if(ds_allowin) begin
        fs_buff_valid <= 1'b0;
        fs_buff_inst <= 32'b0;
    end
end



assign inst_sram_req   = ~reset & fs_allowin & ~br_stall; // &~fs_mmu_ex 
assign inst_sram_wstrb = 4'h0;
assign inst_sram_addr  = {32{is_drct_trans}}                & nextpc |
                         {32{is_map_trans &  drct_map_hit}} & drct_map_pa |
                         {32{is_tlb_trans}} & tlb_map_pa;

assign inst_sram_wdata = 32'b0;
assign inst_sram_wr    = 1'b0;
assign inst_sram_size  = 2'd2;

assign fs_inst   = {32{ fs_buff_valid}} & fs_buff_inst |
                   {32{~fs_buff_valid}} & inst_sram_rdata;

endmodule
