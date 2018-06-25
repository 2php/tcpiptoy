//
// |   | 0~15     | 16~31    |
// | 0 | src port | des port |
// |---+----------+----------|
// | 1 | len      | checksum |
// |---+---------------------|
// | 2 |        data         |
// |---+---------------------|
// | 3 | ...                 |
//
// src port :
// des port :
// len      : head + data
// checksum : (optional) head + data
// 

module udp_pack
  (
   input wire 	     clk,
   input wire 	     rst_n,

   //config
   input wire [15:0] src_port,
   input wire [15:0] des_port,

   //control
   input wire 	     ip_head_end,
   output reg 	     udp_data_end,

   //from app. layer fifo
   input wire 	     app_fifo_empty,
   output reg 	     app_fifo_clk_en,
   input wire [7:0]  app_fifo_dat,
   
   //to buffer RAM
   output reg 	     udp_wram_clk_en,
   output reg [9:0]  udp_wram_addr,
   output reg [7:0]  udp_wram_dat
   
   );

  //
  parameter IDLE = 3'd0;
  parameter HEAD = 3'd1;
  parameter WAIT = 3'd2;
  parameter DATA  = 3'd3;
  parameter DONE = 3'd4;
  
  reg [2:0] 	     udp_cs;
  reg [2:0] 	     udp_ns;

  reg [3:0] 	     udp_head_cnt;
  reg [9:0] 	     udp_data_cnt;
  reg		     app_fifo_dat_en;
  reg [7:0] 	     id_cnt;
  
  always@(posedge clk, negedge rst_n)
    if(!rst_n)
      udp_cs <= IDLE;
    else
      udp_cs <= udp_ns;

  always@(*)
    case(udp_cs)
      IDLE:
	if(ip_head_end)udp_ns = HEAD;
	else udp_ns = IDLE;
      HEAD:
	if(udp_head_cnt == 4'd8)udp_ns = DATA;
	else udp_ns = HEAD;
      WAIT:
	if(!app_fifo_empty)udp_ns = DATA;
	else udp_ns = WAIT;
      DATA:
	if(app_fifo_empty)udp_ns = WAIT;
	else if(udp_data_cnt == 10'd959)udp_ns = DONE;
	else udp_ns = DATA;
      DONE:
	udp_ns = IDLE;
      default:
	udp_ns = IDLE;
    endcase

  //head, data counter
  always@(posedge clk, negedge rst_n)
    if(!rst_n)
      udp_head_cnt <= 4'd0;
    else if(udp_cs == HEAD)
      udp_head_cnt <= udp_head_cnt + 1'b1;
    else
      udp_head_cnt <= 4'd0;
  
  always@(posedge clk, negedge rst_n)
    if(!rst_n)
      app_fifo_dat_en <= 1'b0;
    else
      app_fifo_dat_en <= app_fifo_clk_en && !app_fifo_empty;

  //assign app_fifo_dat_en = app_fifo_clk_en && !app_fifo_empty;
  
  always@(posedge clk, negedge rst_n)
    if(!rst_n)
      udp_data_cnt <= 10'd0;
    //else if(app_fifo_dat_en)
    else if(udp_cs == IDLE)
      udp_data_cnt <= 10'd0;
    else if(app_fifo_dat_en)
      udp_data_cnt <= udp_data_cnt + 1'b1;
  
  //get data from appfifo
  always@(posedge clk, negedge rst_n)
    if(!rst_n)
      app_fifo_clk_en <= 1'b0;
    else if(udp_cs == DATA && !app_fifo_empty)
      app_fifo_clk_en <= 1'b1;
    else
      app_fifo_clk_en <= 1'b0;

  //put data to RAM
  always@(posedge clk, negedge rst_n)
    if(!rst_n)
      udp_wram_clk_en <= 1'b0;
    else if(udp_cs == HEAD)
      udp_wram_clk_en <= 1'b1;
    else
      udp_wram_clk_en <= app_fifo_dat_en;

  always@(posedge clk, negedge rst_n)
    if(!rst_n)
      udp_wram_addr <= 10'd0;
    else if(udp_cs == HEAD)
      udp_wram_addr <= udp_head_cnt + 42;
    else if(udp_cs == DATA)
      udp_wram_addr <= udp_data_cnt + 51;

  always@(posedge clk, negedge rst_n)
    if(!rst_n)
      udp_wram_dat <= 8'h00;
    else if(udp_cs == HEAD)
      case(udp_head_cnt)
	4'd0: udp_wram_dat <= src_port[15:8];
	4'd1: udp_wram_dat <= src_port[7:0];
	4'd2: udp_wram_dat <= des_port[15:8];
	4'd3: udp_wram_dat <= des_port[7:0];
	4'd4: udp_wram_dat <= 8'h03;
	4'd5: udp_wram_dat <= 8'hc9;
	4'd6: udp_wram_dat <= 8'h00; //uncheck sum
	4'd7: udp_wram_dat <= 8'h00; //uncheck sum
	4'd8: udp_wram_dat <= id_cnt;
      endcase
    else if(app_fifo_dat_en)
      udp_wram_dat <= app_fifo_dat;

  reg 		     udp_data_end_tmp;
  always@(posedge clk, negedge rst_n)
    if(!rst_n)
      udp_data_end_tmp <= 1'b0;
    else if(udp_cs == DONE)
      udp_data_end_tmp <= 1'b1;
    else
      udp_data_end_tmp <= 1'b0;

  always@(posedge clk, negedge rst_n)
    if(!rst_n)
      udp_data_end <= 1'b0;
    else
      udp_data_end <= udp_data_end_tmp;

  //id_cnt
  always@(posedge clk, negedge rst_n)
    if(!rst_n)
      id_cnt <= 8'd0;
    else if(udp_cs == DONE)
      begin
	if(id_cnt == 8'd159)
	  id_cnt <= 8'd0;
	else
	  id_cnt <= id_cnt + 1'b1;
      end

      
endmodule // udp_pack
