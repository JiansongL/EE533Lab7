`timescale 1ns/1ps

module pipeline_processor 
   #(
      // parameter DATA_WIDTH = 64,
      // parameter CTRL_WIDTH = DATA_WIDTH/8,
      // parameter UDP_REG_SRC_WIDTH = 2
   )
   ( 
      // --- Register interface
      input                               reg_req_in,
      input                               reg_ack_in,
      input                               reg_rd_wr_L_in,
      input  [`UDP_REG_ADDR_WIDTH-1:0]    reg_addr_in,
      input  [`CPCI_NF2_DATA_WIDTH-1:0]   reg_data_in,
      input  [1:0]      reg_src_in,

      output                              reg_req_out,
      output                              reg_ack_out,
      output                              reg_rd_wr_L_out,
      output  [`UDP_REG_ADDR_WIDTH-1:0]   reg_addr_out,
      output  [`CPCI_NF2_DATA_WIDTH-1:0]  reg_data_out,
      output  [1:0]     reg_src_out,

      // misc
      input                                reset,
      input                                clk
   );

   // RTL of schematic of the pipeline datapath
   
   //------------------------- Signals-------------------------------

   wire [31:0]                    reg_dmem_data_lo;
   wire [31:0]                    reg_dmem_data_hi;
   wire [31:0]                    reg_dmem_addr;
   wire [31:0]                    reg_imem_addr;
   wire [31:0]                    reg_pipeline_c;
   wire [31:0]                    reg_proc_reset;

   reg  [31:0]                    reg_imem_out;

   reg  [31:0]                    inst_write_data;
   reg                            inst_wr_en;
   reg  [31:0]                    imem_addr_prev;

`ifdef PIPELINE_PROCESSOR_BLOCK_ADDR
   localparam [3:0] MODULE_TAG = `PIPELINE_PROCESSOR_BLOCK_ADDR;
`else
   localparam [3:0] MODULE_TAG = 4'h0;
`endif

`ifdef PIPELINE_PROCESSOR_REG_ADDR_WIDTH
   localparam MODULE_REG_ADDR_WIDTH = `PIPELINE_PROCESSOR_REG_ADDR_WIDTH;
`else
   localparam MODULE_REG_ADDR_WIDTH = 4;
`endif

   //------------------------- Datapath -------------------------------

   PipelinedDatapath processor_inst (
      .clk      (clk),
      .InstData (inst_write_data),
      .wea      (inst_wr_en)
   );

   generic_regs
   #( 
      .UDP_REG_SRC_WIDTH   (2),
      .TAG                 (`PIPELINE_PROCESSOR_BLOCK_ADDR),          // Tag -- eg. MODULE_TAG
      .REG_ADDR_WIDTH      (`PIPELINE_PROCESSOR_REG_ADDR_WIDTH),     // Width of block addresses -- eg. MODULE_REG_ADDR_WIDTH
      .NUM_COUNTERS        (0),                 // Number of counters
      //change the number of software and hardware registers
      .NUM_SOFTWARE_REGS   (6),                 // Number of sw regs
      .NUM_HARDWARE_REGS   (1)                  // Number of hw regs
   ) module_regs (
      .reg_req_in       (reg_req_in),
      .reg_ack_in       (reg_ack_in),
      .reg_rd_wr_L_in   (reg_rd_wr_L_in),
      .reg_addr_in      (reg_addr_in),
      .reg_data_in      (reg_data_in),
      .reg_src_in       (reg_src_in),

      .reg_req_out      (reg_req_out),
      .reg_ack_out      (reg_ack_out),
      .reg_rd_wr_L_out  (reg_rd_wr_L_out),
      .reg_addr_out     (reg_addr_out),
      .reg_data_out     (reg_data_out),
      .reg_src_out      (reg_src_out),

      // --- counters interface
      .counter_updates  (),
      .counter_decrement(),

      // --- SW regs interface
      //important: the order should be the same order in register file .xml (from high address to low address)
      .software_regs    ({reg_proc_reset, reg_pipeline_c, reg_imem_addr,
                          reg_dmem_addr, reg_dmem_data_hi, reg_dmem_data_lo}),
      
      // --- HW regs interface
      //TODO: modify the hardware register interface
      .hardware_regs    (reg_imem_out),

      .clk              (clk),
      .reset            (reset)
    );

endmodule 
