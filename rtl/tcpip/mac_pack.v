
// Ethernet II
//  
// | 8 bytes      | 6 bytes      | 6 bytes      | 2 bytes   | 46~1500 bytes  | 4 bytes |           |
// |--------------+--------------+--------------+-----------+----------------+---------+-----------|
// | 55 ... 55 D5 | des mac addr | src mac addr | prot_type | IP packet data | FCS     | variable  |
// |--------------+--------------+--------------+-----------+----------------+---------+-----------|
// |              |              |              | 0800      |                | CRC32   | totoal len|
// |              |              |              |           |                |         | min 512 B |
// |--------------+--------------+--------------+-----------+----------------+---------+-----------|

module mac_pack
  (
   input wire 	     clk, //from pll, 125Mhz
   input wire 	     rst_n,

   input wire [47:0] des_mac_addr, 
   input wire [47:0] src_mac_addr,
   input wire [15:0] prot_type,

   //control
   input wire 	     app_fifo_empty,
   output reg 	     mac_head_end, //to   ip_head_start
   input wire 	     mac_data_end, //from udp_data_end

   //to buffer RAM
   output reg 	     mac_wram_clk_en,
   output reg [9:0]  mac_wram_addr,
   output reg [7:0]  mac_wram_dat,
   //from buffer RAM
   output reg 	     mac_rram_clk_en,
   output reg [9:0]  mac_rram_addr,
   input wire [7:0]  mac_rram_dat,

   //calc fcs
   output wire 	     fcs_get,
   input wire 	     fcs_en,
   input wire [31:0] fcs,
   
   //GMII/MII tx
   //output reg      gtx_clk, //125Mhz
   output reg 	     tx_en, //transmit enable
   output reg [7:0]  txd,
   output reg 	     tx_er,

   //status
   output wire 	     tx_busy
   );


  parameter IDLE      = 3'd0;
  parameter HEAD      = 3'd1;
  parameter PKT_DATA  = 3'd2;
  parameter FCS_START = 3'd3;
  parameter SEND      = 3'd4;
  parameter FCS	      = 3'd5;
  parameter DONE      = 3'd6;
  
  reg [2:0] 	     mac_cs;
  reg [2:0] 	     mac_ns;

  reg [4:0] 	     mac_head_cnt; //0~21
  reg [1:0] 	     mac_fcs_cnt; //0~3
  reg [9:0] 	     mac_send_cnt; //0~1013
  
  
  always@(posedge clk, negedge rst_n)
    if(!rst_n)
      mac_cs <= IDLE;
    else
      mac_cs <= mac_ns;

  always@(*)
    case(mac_cs)
      IDLE:
	if(!app_fifo_empty)mac_ns = HEAD;
	else mac_ns = IDLE;
      HEAD:
	if(mac_head_cnt == 5'd21)mac_ns = PKT_DATA;
	else mac_ns = HEAD;
      PKT_DATA:
	if(mac_data_end)mac_ns = FCS_START;
	else mac_ns = PKT_DATA;
      FCS_START:
	mac_ns = SEND;
      SEND:
	if(mac_send_cnt == 10'd1010)mac_ns = FCS;
	else mac_ns = SEND;
      FCS:
	if(mac_fcs_cnt == 2'd3)mac_ns = DONE;
	else mac_ns = FCS;
      DONE:
	mac_ns = IDLE;
      default:
	mac_ns = IDLE;
    endcase // case (mac_cs)

  //counter
  always@(posedge clk, negedge rst_n)
    if(!rst_n)
      mac_head_cnt <= 5'd0;
    else if(mac_cs == HEAD)
      mac_head_cnt <= mac_head_cnt + 1'b1;
    else
      mac_head_cnt <= 5'd0;

  always@(posedge clk, negedge rst_n)
    if(!rst_n)
      mac_fcs_cnt <= 2'd0;
    else if(mac_cs == FCS)
      mac_fcs_cnt <= mac_fcs_cnt + 1'b1;
    else
      mac_fcs_cnt <= 2'd0;

  always@(posedge clk, negedge rst_n)
    if(!rst_n)  
      mac_send_cnt <= 10'd0;
    else if(mac_cs == SEND)
      mac_send_cnt <= mac_send_cnt + 1'b1;
    else
      mac_send_cnt <= 10'd0;
  
  //store mac head and fcs to RAM
  always@(posedge clk, negedge rst_n)
    if(!rst_n)
      mac_wram_clk_en <= 1'b0;
    else if(mac_cs == HEAD)
      mac_wram_clk_en <= 1'b1;
    else
      mac_wram_clk_en <= 1'b0;

  always@(posedge clk, negedge rst_n)
    if(!rst_n)
      mac_wram_addr <= 10'd0;
    else if(mac_cs == HEAD)
      mac_wram_addr <= {5'b0, mac_head_cnt};
    //else if(mac_cs == FCS)
    //  mac_wram_addr <= 10'd1010 + mac_fcs_cnt;

  always@(posedge clk, negedge rst_n)
    if(!rst_n)
      mac_wram_dat <= 8'd0;
    else if(mac_cs == HEAD)
      begin
	case(mac_head_cnt)
	  //preamble
	  5'd0, 5'd1, 5'd2, 5'd3, 5'd4, 5'd5, 5'd6:
	    mac_wram_dat <= 8'h55;
	  5'd7:
	    mac_wram_dat <= 8'hd5;
	  //dec mac addr
	  5'd8:
	    mac_wram_dat <= des_mac_addr[47:40];
	  5'd9:
	    mac_wram_dat <= des_mac_addr[39:32];
	  5'd10:
	    mac_wram_dat <= des_mac_addr[31:24];
	  5'd11:
	    mac_wram_dat <= des_mac_addr[23:16];
	  5'd12:
	    mac_wram_dat <= des_mac_addr[15:8];
	  5'd13:
	    mac_wram_dat <= des_mac_addr[7:0];
	  //src mac addr
	  5'd14:
	    mac_wram_dat <= src_mac_addr[47:40];
	  5'd15:
	    mac_wram_dat <= src_mac_addr[39:32];
	  5'd16:
	    mac_wram_dat <= src_mac_addr[31:24];
	  5'd17:
	    mac_wram_dat <= src_mac_addr[23:16];
	  5'd18:
	    mac_wram_dat <= src_mac_addr[15:8];
	  5'd19:
	    mac_wram_dat <= src_mac_addr[7:0];
	  //prot_type
	  5'd20:
	    mac_wram_dat <= prot_type[15:8];
	  5'd21:
	    mac_wram_dat <= prot_type[7:0];
	endcase
      end
    //else if(mac_cs == FCS)
    //  begin
    // 	case(mac_fcs_cnt)
    // 	  2'b00: mac_wram_dat <= fcs[31:24];
    // 	  2'b01: mac_wram_dat <= fcs[23:16];
    // 	  2'b10: mac_wram_dat <= fcs[15:8];
    // 	  2'b11: mac_wram_dat <= fcs[7:0];
    // 	endcase
    //  end
    else
      mac_wram_dat <= 8'd0;

  always@(posedge clk, negedge rst_n)
    if(!rst_n)
      mac_head_end <= 1'b0;
    else if(mac_cs == HEAD && mac_head_cnt == 5'd21)
      mac_head_end <= 1'b1;
    else
      mac_head_end <= 1'b0;
  
  //send to phy
  always@(posedge clk, negedge rst_n)
    if(!rst_n)
      mac_rram_clk_en <= 1'b0;
    else if(mac_cs == SEND)
      mac_rram_clk_en <= 1'b1;
    else
      mac_rram_clk_en <= 1'b0;

  always@(posedge clk, negedge rst_n)
    if(!rst_n)
      mac_rram_addr <= 10'd0;
    else
      mac_rram_addr <= mac_send_cnt;

  //CRC32 
  reg st_send_dly;
  reg st_send_dly2;
  always@(posedge clk, negedge rst_n)
    if(!rst_n)
      st_send_dly <= 1'b0;
    else if(mac_cs == FCS)
      st_send_dly <= 1'b1;
    else
      st_send_dly <= 1'b0;

  always@(posedge clk, negedge rst_n)
    if(!rst_n)
      st_send_dly2 <= 1'b0;
    else
      st_send_dly2 <= st_send_dly;
 
  //reg [7:0] crc8;
  wire [31:0] crc32;
  reg 	      crc32_start;
  reg [7:0]   mac_fcs_cnt_dly;
  reg [7:0]   mac_fcs_cnt_dly2;
  
  always@(posedge clk, negedge rst_n)
    if(!rst_n)
      crc32_start <= 1'b0;
    else if(mac_cs == FCS_START)
      crc32_start <= 1'b1;
    else
      crc32_start <= 1'b0;

  always@(posedge clk, negedge rst_n)
    if(!rst_n)
      begin
	mac_fcs_cnt_dly <= 8'b0;
	mac_fcs_cnt_dly2 <= 8'b0;
      end
    else
      begin
	mac_fcs_cnt_dly <= mac_fcs_cnt;
	mac_fcs_cnt_dly2 <= mac_fcs_cnt_dly;
      end
      
  //always@(posedge clk, negedge rst_n)
  //  if(!rst_n)
  //    crc8 <= 8'b0;
  //  else if(st_send_dly2)
  //    case(mac_fcs_cnt_dly)
  // 	2'b00: crc8 <= crc32[7:0];
  // 	2'b01: crc8 <= crc32[15:8];
  // 	2'b10: crc8 <= crc32[23:16];
  // 	2'b11: crc8 <= crc32[31:24];
  //    endcase
	  
  reg tx_en_tmp;
  always@(posedge clk, negedge rst_n)
    if(!rst_n)
      begin
	tx_en_tmp <= 1'b0;
	tx_en <= 1'b0;
      end
    else
      begin
	tx_en_tmp <= mac_rram_clk_en;
	tx_en <= tx_en_tmp | st_send_dly2;
      end

  always@(posedge clk, negedge rst_n)
    if(!rst_n)
      txd <= 8'b0;
    else if(tx_en_tmp)
      txd <= mac_rram_dat;
    else if(st_send_dly2)
      begin
	case(mac_fcs_cnt_dly2)
	  2'b00: txd <= crc32[7:0];
	  2'b01: txd <= crc32[15:8];
	  2'b10: txd <= crc32[23:16];
	  2'b11: txd <= crc32[31:24];
	endcase
      end

  always@(posedge clk, negedge rst_n)
    if(!rst_n)
      tx_er <= 1'b0;

  reg tx_busy_dly1;
  reg tx_busy_dly2;
  reg tx_busy_dly3;
  always@(posedge clk, negedge rst_n)
    if(!rst_n)
      tx_busy_dly1 <= 1'b0;
    else if(mac_cs == FCS_START || mac_cs == SEND || 
	    mac_cs == FCS)
      tx_busy_dly1 <= 1'b1;
    else
      tx_busy_dly1 <= 1'b0;

  always@(posedge clk, negedge rst_n)
    if(!rst_n)
      begin
	tx_busy_dly2 <= 1'b0;
	tx_busy_dly3 <= 1'b0;
      end
    else
      begin
	tx_busy_dly2 <= tx_busy_dly1;
	tx_busy_dly3 <= tx_busy_dly2;
      end

  assign tx_busy = tx_busy_dly1 | tx_busy_dly2 | tx_busy_dly3;


  reg crc_dat_en;
  always@(posedge clk, negedge rst_n)
    if(!rst_n)
      crc_dat_en <= 1'b0;
    else if(mac_rram_clk_en && mac_rram_addr > 10'd7)
      crc_dat_en <= 1'b1;
    else
      crc_dat_en <= 1'b0;

  
  crc32 u_crc32
    (
     // Outputs
     .crc32				(crc32[31:0]),
     // Inputs
     .clk				(clk),
     .rst_n				(rst_n),
     .start				(crc32_start),
     .dat_en				(crc_dat_en),
     .dat				(mac_rram_dat[7:0])
     );
  

  
endmodule // mac_pack
