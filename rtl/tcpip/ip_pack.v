//
// |   | 0~3    | 4~7      | 8~11     | 12~15   | 16~18   | 19~23  | 24~27 | 28~31 |
// |---+--------+----------+----------+---------+---------+--------+-------+-------|
// | 0 | ver    | head len |       service      |        total length              |
// |---+--------+----------+----------+---------+---------+--------+-------+-------|
// | 1 |                  id                    | flag    |          offset        |
// |---+--------+----------+----------+---------+---------+--------+-------+-------|
// | 2 |      life         |       protocol     |       checksum of head           |
// |---+--------+----------+----------+---------+---------+--------+-------+-------|
// | 3 |                            source ip addr                                 |
// |---+---------------------------------------------------------------------------|
// | 4 |                              des ip addr                                  |
// |===+===========================================================================|
// | 5 |                                data                                       |
// |---+---------------------------------------------------------------------------|
// | 6 |                                ...                                        |
// |---+---------------------------------------------------------------------------|
//
//  ver       : 4'h4 (IPv4)
//  head len  : 4'h5 (5*4Bytes = 20Bytes)
//  service   : 8'h00 (normal service)
//  total len : include head + data, max is 65535
//  id        : a 16bit counter, increse 1
//  flag      : 3bit, if segment, 
//  offset    : 13bit, offset of segment
//  life      : max num. of router, decrease 1 through one router. discard data if lift decrease to 0
//              usually set to 32, 64, 128
//  prototol  : TCP(6), UDP(17)
//  CS of head: from ver to des ip addr
//
  
module ip_pack
  (
   //system
   input wire 	     clk,
   input wire 	     rst_n,

   //config
   input wire [7:0]  prot_type, //tcp: 6, udp: 17
   input wire [31:0] src_ip_addr,
   input wire [31:0] des_ip_addr,

   //control
   input wire 	     mac_head_end, //from mac_pack
   output reg 	     ip_head_end, //to udp_pack

   //to buffer RAM
   output reg 	     ip_wram_clk_en,
   output reg [9:0]  ip_wram_addr,
   output reg [7:0]  ip_wram_dat
   
   );

  parameter IDLE   = 3'd0;
  parameter HEAD   = 3'd1;
  parameter WAIT   = 3'd2;
  parameter CHKSUM = 3'd3;
  parameter DONE   = 3'd4;

  reg [2:0] 	     ip_cs;
  reg [2:0] 	     ip_ns;

  reg [4:0] 	     ip_head_cnt; //0~19
  reg [15:0] 	     id_cnt;

  reg 		     ip_chksum_cnt;
  wire [31:0] 	     checksum;
  
  always@(posedge clk, negedge rst_n)
    if(!rst_n)
      ip_cs <= IDLE;
    else
      ip_cs <= ip_ns;

  always@(*)
    case(ip_cs)
      IDLE:
	if(mac_head_end)ip_ns = HEAD;
	else ip_ns = IDLE;
      HEAD:
	if(ip_head_cnt == 5'd19)ip_ns = WAIT;
	else ip_ns = HEAD;
      WAIT:
	ip_ns = CHKSUM;
      CHKSUM:
	if(ip_chksum_cnt == 1'b1)ip_ns = DONE;
	else ip_ns = CHKSUM;
      DONE:
	ip_ns = IDLE;
      default:
	ip_ns = IDLE;
    endcase
     
  //write ip head to buffer RAM
  always@(posedge clk, negedge rst_n)
    if(!rst_n)
      ip_head_cnt <= 5'd0;
    else if(ip_cs == HEAD)
      ip_head_cnt <= ip_head_cnt + 1'b1;
    else
      ip_head_cnt <= 5'd0;

  always@(posedge clk, negedge rst_n)
    if(!rst_n)
      ip_chksum_cnt <= 1'b0;
    else if(ip_cs == CHKSUM)
      ip_chksum_cnt <= ip_chksum_cnt + 1'b1;
    else
      ip_chksum_cnt <= 1'b0;
  
  always@(posedge clk, negedge rst_n)
    if(!rst_n)
      ip_wram_clk_en <= 1'b0;
    else if(ip_cs == HEAD || ip_cs == CHKSUM)
      ip_wram_clk_en <= 1'b1;
    else
      ip_wram_clk_en <= 1'b0;

  always@(posedge clk, negedge rst_n)
    if(!rst_n)
      ip_wram_addr <= 10'd0;
    else if(ip_cs == HEAD)
      ip_wram_addr <= ip_head_cnt + 10'd22;
    else if(ip_cs == CHKSUM)
      ip_wram_addr <= ip_chksum_cnt + 10'd32;
  
  always@(posedge clk, negedge rst_n)
    if(!rst_n)
      ip_wram_dat <= 8'h00;
    else if(ip_cs == HEAD)
      begin
	case(ip_head_cnt)
	  5'd0: ip_wram_dat <= 8'h45; //ipv4,head len
	  5'd1: ip_wram_dat <= 8'h00; //normal service
	  5'd2: ip_wram_dat <= 8'h03; //03, dc
	  5'd3: ip_wram_dat <= 8'hdd;
	  5'd4: ip_wram_dat <= id_cnt[15:8];
	  5'd5: ip_wram_dat <= id_cnt[7:0];
	  5'd6: ip_wram_dat <= 8'h00; //offset, flag
	  5'd7: ip_wram_dat <= 8'h00;
	  5'd8: ip_wram_dat <= 8'h40; //life: 128
	  5'd9: ip_wram_dat <= prot_type; //protocol
	  5'd10: ip_wram_dat <= 8'h00; //unset checksum
	  5'd11: ip_wram_dat <= 8'h00;
	  5'd12: ip_wram_dat <= src_ip_addr[31:24]; //src ip addr
	  5'd13: ip_wram_dat <= src_ip_addr[23:16];
	  5'd14: ip_wram_dat <= src_ip_addr[15:8];
	  5'd15: ip_wram_dat <= src_ip_addr[7:0];
	  5'd16: ip_wram_dat <= des_ip_addr[31:24]; //des ip addr
	  5'd17: ip_wram_dat <= des_ip_addr[23:16];
	  5'd18: ip_wram_dat <= des_ip_addr[15:8];
	  5'd19: ip_wram_dat <= des_ip_addr[7:0];
	endcase
      end
    else if(ip_cs == CHKSUM)
      begin
	if(ip_chksum_cnt == 1'b0)ip_wram_dat <= ~checksum[15:8];
	else ip_wram_dat <= ~checksum[7:0];
      end

  //end
  always@(posedge clk, negedge rst_n)
    if(!rst_n)
      ip_head_end <= 1'b0;
    else if(ip_cs == CHKSUM && ip_chksum_cnt == 1'b1)
      ip_head_end <= 1'b1;
    else
      ip_head_end <= 1'b0;

  //ip id_cnt
  always@(posedge clk, negedge rst_n)
    if(!rst_n)
      id_cnt <= 16'd0;
    else if(ip_cs == DONE)
      id_cnt <= id_cnt + 1'b1;

  //checksum
  reg [7:0]ip_wram_dat_dly;
  always@(posedge clk, negedge rst_n)
    if(!rst_n)
      ip_wram_dat_dly <= 8'h00;
    else
      ip_wram_dat_dly <= ip_wram_dat;

  reg 	   st_head_dly;
  always@(posedge clk, negedge rst_n)
    if(!rst_n)
      st_head_dly <= 1'b0;
    else if(ip_cs == HEAD)
      st_head_dly <= 1'b1;
    else
      st_head_dly <= 1'b0;
  
  reg [31:0] sum_ext;
  always@(posedge clk, negedge rst_n)
    if(!rst_n)
      sum_ext <= 32'b0;
    else if(st_head_dly && 
	    !ip_head_cnt[0] && ip_head_cnt != 5'd0)
      begin
	sum_ext <= checksum + {ip_wram_dat_dly,ip_wram_dat};
      end
    else if(ip_cs == DONE)
      sum_ext <= 32'b0;
  
  assign checksum = sum_ext[31:16] + sum_ext[15:0];

  
endmodule // ip_pack
