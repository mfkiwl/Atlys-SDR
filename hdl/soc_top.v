`default_nettype none
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Joel Williams
// 
// Create Date:    11:23:07 02/18/2011 
// Design Name: 
// Module Name:    ethernet_test_top 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Simple test framework for the Atlys' 88E1111 chip
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module soc_top(
	input wire clk_100_pin,
	
	// Ethernet
	output wire PhyResetOut_pin,
	input wire MII_TX_CLK_pin, // 25 MHz clock for 100 Mbps - not used here
	output reg [7:0] GMII_TXD_pin, 
	output reg GMII_TX_EN_pin,
	output reg GMII_TX_ER_pin,
	output wire GMII_TX_CLK_pin,
	input wire [7:0] GMII_RXD_pin, 
	input wire GMII_RX_DV_pin,
	input wire GMII_RX_ER_pin,
	input wire GMII_RX_CLK_pin,
	output wire MDC_pin,
	inout wire MDIO_pin,
	
	input wire [1:0] adc_cha_p,
	input wire [1:0] adc_cha_n,

	input wire [1:0] adc_chb_p,
	input wire [1:0] adc_chb_n,
		
	input wire adc_bit_clk_p,
	input wire adc_bit_clk_n,
		
	input wire adc_frame_sync_p,
	input wire adc_frame_sync_n,
	
	output wire [7:0] leds,
	input wire [7:0] sw,
	input wire [5:0] btn,
	
	// MUX Interface (VHDCI)
	output wire VHDCI_MUX_OUT_P,
	output wire VHDCI_MUX_OUT_N,

	output wire VHDCI_MUX_CLK_P,
	output wire VHDCI_MUX_CLK_N,

	input wire VHDCI_MUX_IN_P,
	input wire VHDCI_MUX_IN_N,
	
	// DDR2
	output wire [12:0] ddr2_a,
	output wire [2:0] ddr2_ba,
	output wire	ddr2_ras_n,
	output wire	ddr2_cas_n,
	output wire	ddr2_we_n,
	output wire	ddr2_rzq,
	output wire	ddr2_zio,
	output wire	ddr2_odt,
	output wire	ddr2_cke,
	output wire	ddr2_dm,
	output wire	ddr2_udm,
	inout wire [15:0] ddr2_dq,
	inout	wire ddr2_dqs,
	inout	wire ddr2_dqs_n,
	inout	wire ddr2_udqs,
	inout	wire ddr2_udqs_n,
	output wire	ddr2_ck,
	output wire	ddr2_ck_n,

	// Serial (USB)
	output rs232_tx,
	input wire rs232_rx,
	
	// JTAG
	output wire	tdo_pad_o,
	input wire	tms_pad_i,
	input wire	tck_pad_i,
	input wire	tdi_pad_i,
	
	// Flash
	output wire flash_spi_csn,
	output wire flash_spi_sck,
	inout wire [3:0] flash_spi_io
   );

	wire wb_rst, wb_clk;
`include "wb_intercon.vh"

   localparam ADC_PACKET_SIZE	= 10'd128;

	////////////////////////////////////////////////////////////////////////
	//
	// Clock and reset generation module
	//
	////////////////////////////////////////////////////////////////////////
	wire	async_rst;
	wire	dbg_tck;
	wire	dvi_clk;
	wire	ddr2_if_clk;
	wire	ddr2_if_rst;
	wire	clk100;
	wire  phy_rst;
	
	clkgen clkgen0 (
		.sys_clk_pad_i (clk_100_pin),
		.rst_n_pad_i (phy_rst),
		.async_rst_o (async_rst),
		.wb_clk_o (wb_clk),
		.wb_rst_o (wb_rst),
		.tck_pad_i (tck_pad_i),
		.dbg_tck_o (dbg_tck),
		.ddr2_if_clk_o (ddr2_if_clk),
		.ddr2_if_rst_o (ddr2_if_rst),
		.clk100_o (clk100)
		);
	// System clock
	//wire clk_100;
	//IBUFG ibufg_100 (
	//	.I(clk_100_pin),
	//	.O(clk_100));
	// 125 MHz for PHY. 90 degree shifted clock drives PHY's GMII_TX_CLK.
	wire clk_8, clk_50, clk_125, clk_fwd, clk_125_GTX_CLK, pll_locked;
	//wire pll_rst;
	//clk_gen clk_125_tx(
	//	.CLK_IN1(clk_100_pin),
	//	.CLK_OUT1(clk_125), // 0 deg
	//	.CLK_OUT2(clk_125_GTX_CLK),// 90 deg
	//	.CLK_OUT3(clk_50),
	//	.CLK_OUT4(clk_8),
	//	.CLK_OUT5(clk_fwd),
		//.RESET(pll_rst),
	//	.LOCKED(pll_locked));
	
	wire clk_mux, clk_mux_out, clk_250_int, clk_mux_div, clk_mux_div_int, mux_pll_locked, clkfbout, clkfbout_buf;
   PLL_BASE
   #(.BANDWIDTH             ("OPTIMIZED"),
     .CLK_FEEDBACK          ("CLKFBOUT"),
     .COMPENSATION          ("SYSTEM_SYNCHRONOUS"),
     .DIVCLK_DIVIDE         (1),
     .CLKFBOUT_MULT         (10),
     .CLKFBOUT_PHASE        (0.000),
     .CLKOUT0_DIVIDE        (2),
     .CLKOUT0_PHASE         (0.000),
     .CLKOUT0_DUTY_CYCLE    (0.500),
	  .CLKOUT1_DIVIDE        (4),
	  .CLKOUT1_PHASE         (90.000),
	  .CLKOUT1_DUTY_CYCLE    (0.500),
     .CLKOUT2_DIVIDE        (16),
     .CLKOUT2_PHASE         (0.000),
     .CLKOUT2_DUTY_CYCLE    (0.500),
     .CLKIN_PERIOD          (10.0),
     .REF_JITTER            (0.010))
   pll_base_inst
     // Output clocks
    (
	  .CLKFBOUT              (clkfbout),
     .CLKOUT0               (clk_mux),
     .CLKOUT1               (clk_250_int),
     .CLKOUT2               (clk_mux_div_int),
     .CLKOUT3               (),
     .CLKOUT4               (),
     .CLKOUT5               (),
     // Status and control signals
     .LOCKED                (mux_pll_locked),
     .RST                   (1'b0),
      // Input clock control
     .CLKFBIN               (clkfbout_buf),
     .CLKIN                 (clk_fwd));

	BUFG clkf_buf
    (.O (clk_mux_div),
     .I (clk_mux_div_int));
	  
	BUFG clkout_buf
	 (.O (clk_mux_out),
	  .I (clk_250_int));
	  
	BUFG clkfb_buf
    (.O (clkfbout_buf),
     .I (clkfbout));
	
	wire fpga_mux_clk;
	ODDR2 ODDR_FPGA_MUX (
		.Q(fpga_mux_clk),      // Data output (connect directly to top-level port)
      .C0(clk_mux_out),    // 0 degree clock input
      .C1(~clk_mux_out),    // 180 degree clock input
      .CE(1'b1),    // Clock enable input
      .D0(1'b0),    // Posedge data input
      .D1(1'b1),    // Negedge data input
      .R(1'b0),      // Synchronous reset input
      .S(1'b0)       // Synchronous preset input
      );

	OBUFDS #(
      .IOSTANDARD("LVDS_25") // Specify the output I/O standard
   ) OBUFDS_inst (
      .O(VHDCI_MUX_CLK_P),     // Diff_p output (connect directly to top-level port) (p type differential o/p)
      .OB(VHDCI_MUX_CLK_N),   // Diff_n output (connect directly to top-level port) (n type differential o/p)
      .I(fpga_mux_clk)      // Buffer input (this is the single ended standard)
   );
	
	// PLL reset logic
	// Based on http://forums.xilinx.com/t5/Spartan-Family-FPGAs/RESET-SIGNALS/m-p/133182#M10198
	/*
	reg [25:0] pll_status_counter = 0;
	always @(posedge clk_100)
		if (pll_locked)
			pll_status_counter <= 0;
		else
			pll_status_counter <= pll_status_counter + 1'b1;
			
	assign pll_rst = (pll_status_counter > (2**26 - 26'd20)); // Reset for 20 cycles
		*/
	// The USRP2 has a 125 MHz oscillator connected to clk_to_mac. While the
	// 88E1111 generates a 125 MHz reference (125CLK), this isn't connected.
	// We generate this clock from the Atlys' 100 MHz oscillator using the DCM.
	wire clk_to_mac = clk_125;
	
	// USRP2 runs the GEMAC's FIFOs at 100 MHz, though this is buffered through a DCM.
	wire dsp_clk = clk_125;
	
	// USRP2 runs its CPU and the Wishbone bus at 50 MHz system clock, possibly due to
	// speed limitations in the Spartan-3. Let's try running it at full speed.
	//wire wb_clk = clk_125;
	
	wire clk_flash_io = clk_fwd; // 100MHz
	
	wire baud_clk = clk_8;
	
	wire adc_clk;


	// Hold the FSMs in reset until the PLL has locked
	wire dsp_rst;
	wire all_plls_locked;
	reset reset (
		.clk(dsp_clk),
		.pll_lock(pll_locked),
		.rst_1(),
		
		.clk_2(dsp_clk),
		.rst_2(dsp_rst),
	
		.ext_reset(sw_reconfig));

	//  Drive the GTX_CLK output from a DDR register
	wire GMII_GTX_CLK_int;
	
	ODDR2 ODDR_gmii (
		.Q(GMII_TX_CLK_pin),      // Data output (connect directly to top-level port)
      .C0(clk_125_GTX_CLK),    // 0 degree clock input
      .C1(~clk_125_GTX_CLK),    // 180 degree clock input
      .CE(1'b1),    // Clock enable input
      .D0(1'b0),    // Posedge data input
      .D1(1'b1),    // Negedge data input
      .R(1'b0),      // Synchronous reset input
      .S(1'b0)       // Synchronous preset input
      );
	
	// Register MAC outputs
	wire GMII_TX_EN, GMII_TX_ER;
	wire [7:0] GMII_TXD;
	
	always @(posedge GMII_GTX_CLK_int)
	begin
		GMII_TX_EN_pin <= GMII_TX_EN;
		GMII_TX_ER_pin <= GMII_TX_ER;
		GMII_TXD_pin <= GMII_TXD;
	end
	
	// LEDs for debugging
	// reg [7:0] ledreg;
	assign leds = {mux_synced, mux_in[6:0]};//{4'b1111,pll_locked, mux_pll_locked, mux_synced, scope_triggered};;
	/*
	always @(posedge dsp_clk) begin
		ledreg[5:0] <= {2'd0, gemac_debug};
	end
	
	always @(mux_synced, scope_triggered) begin
		ledreg[7:6] = {mux_synced, scope_triggered};
	end*/
	
	// Sync a pushbutton to FSM clock to initiate packet
	wire sw_send_packet, sw_reconfig;
	edge_detect edge_detect_s1 (.async_sig(btn[0]), .clk(dsp_clk), .rise(), .fall(sw_send_packet));
	edge_detect edge_detect_s2 (.async_sig(btn[1]), .clk(dsp_clk), .rise(), .fall(sw_reconfig));

	/*
	config_mux config_mux_inst (
		.clk(dsp_clk),
		.reset(~gemac_ready),

		.rx_ready(config_data_out_en),
		.rx_data(udp_data_out)

		.tx_full : in  STD_LOGIC;
		.tx_wr : out  STD_LOGIC;
		.tx_data : out  STD_LOGIC_VECTOR (31 downto 0);

		.address : out STD_LOGIC_VECTOR (15 downto 0);
		.wr : out STD_LOGIC;
		.rd : out STD_LOGIC;
		.dout : out STD_LOGIC_VECTOR (31 downto 0);
		.din : in STD_LOGIC_VECTOR (31 downto 0));
	*/
	// The top module of the USRP2 MAC core
	localparam dw = 32; // WB data bus width
	localparam aw = 8; // WB address bus width
	//wire wb_rst;
   wire rd2_dst_rdy, wr2_dst_rdy;
	wire wr2_src_rdy, rd2_src_rdy;
   wire [3:0] 	 wr2_flags;
	wire [3:0]   rd2_flags;
   wire [31:0]  rd2_data;
	wire [31:0]	 wr2_data;
   wire [dw-1:0] wb_dat_o;
	wire [dw-1:0] wb_dat_i;
	wire [aw-1:0] wb_adr;
	wire wb_ack;
	wire wb_stb, wb_cyc, wb_we;
	wire [79:0] debug_mac;
	
	simple_gemac_wrapper #(
		.RXFIFOSIZE(9), .TXFIFOSIZE(6)
		) simple_gemac_wrapper (
		
		.clk125(clk_to_mac),
		.reset(wb_rst),
	  
		// PHY pins
      .GMII_GTX_CLK(GMII_GTX_CLK_int), .GMII_TX_EN(GMII_TX_EN),
      .GMII_TX_ER(GMII_TX_ER), .GMII_TXD(GMII_TXD),
      .GMII_RX_CLK(GMII_RX_CLK_pin), .GMII_RX_DV(GMII_RX_DV_pin),  
      .GMII_RX_ER(GMII_RX_ER_pin), .GMII_RXD(GMII_RXD_pin),
		.mdio(MDIO_pin), .mdc(MDC_pin),
		
		// I/O buses
		.sys_clk(dsp_clk),
      .rx_f36_data({rd2_flags,rd2_data}), .rx_f36_src_rdy(rd2_src_rdy), .rx_f36_dst_rdy(rd2_dst_rdy),
      .tx_f36_data({wr2_flags,wr2_data}), .tx_f36_src_rdy(wr2_src_rdy), .tx_f36_dst_rdy(wr2_dst_rdy),
		
		// Wishbone signals
      .wb_clk(wb_clk), .wb_rst(wb_rst), .wb_stb(wb_stb), .wb_cyc(wb_cyc), .wb_ack(wb_ack),
      .wb_we(wb_we), .wb_adr(wb_adr), .wb_dat_i(wb_dat_o), .wb_dat_o(wb_dat_i),
      
      .debug(debug_mac));
	
	// After the PLL has locked, configure the MAC and PHY using a state machine
	wire gemac_ready;
	wire [3:0] gemac_debug;
	gemac_configure gemac_configure (
		.clk(wb_clk),
		
		// Wishbone signals
		.wb_rst(phy_rst),
		.wb_stb(wb_stb),
		.wb_cyc(wb_cyc),
		.wb_ack(wb_ack),
		.wb_we(wb_we),
		.wb_adr(wb_adr[7:0]),
		.wb_dat_i(wb_dat_i),
		.wb_dat_o(wb_dat_o),
		
		.phy_reset(PhyResetOut_pin), // Connect to PHY's reset pin
		.reset(dsp_rst),
		.debug(gemac_debug),
		.ready(gemac_ready)); // Signal to rest of the system that negotiation is complete

	wire [31:0] pri_fifo_d, adc_fifo_d;
	wire adc_data_re, adc_fifo_ae;

	wire [8:0] pri_packet_size_i, sec_packet_size_i;
	wire pri_fifo_req, pri_fifo_rd;
	assign pri_packet_size_i = 9'd128;
	assign sec_packet_size_i = 9'd128;
	// Send out Ethernet packets
	packet_sender packet_sender (
		.clk(dsp_clk),
		.reset(~gemac_ready),
		.wr_flags_o(wr2_flags),
		.wr_data_o(wr2_data),
		.wr_dst_rdy_i(wr2_dst_rdy),
		.wr_src_rdy_o(wr2_src_rdy),
		// primary interface: Configuration Data
		.pri_fifo_d,
		.pri_packet_size_i,
		.pri_fifo_req,
		.pri_fifo_rd,
		// secondary interface: ADC Data
		.sec_fifo_d(adc_fifo_d),
		.sec_packet_size_i(ADC_PACKET_SIZE),
		.sec_fifo_req(~adc_fifo_ae),
		.sec_fifo_rd(adc_data_re));
	
	wire [31:0] adc_data;
	wire adc_data_we;
	adc_sample_fifo adc_sample_fifo_inst (
	  .rst(~gemac_ready), // input rst
	  .wr_clk(adc_clk), // input wr_clk
	  .rd_clk(dsp_clk), // input rd_clk
	  .din(adc_data), // input [31 : 0] din
	  .wr_en(adc_data_we), // input wr_en
	  .rd_en(adc_data_re), // input rd_en
	  .prog_empty_thresh(ADC_PACKET_SIZE), // input [9 : 0] prog_empty_thresh
	  .dout(adc_fifo_d), // output [31 : 0] dout
	  .full(), // output full
	  .overflow(), // output overflow
	  .empty(), // output empty
	  .prog_empty(adc_fifo_ae) // output prog_empty
	);
	
	adc_rx adc_rx (
		.clk(dsp_clk),
		.reset(~gemac_ready),
		
		.adc_cha_p(adc_cha_p),
		.adc_cha_n(adc_cha_n),

		.adc_chb_p(adc_chb_p),
		.adc_chb_n(adc_chb_n),
		
		.bit_clk_p(adc_bit_clk_p),
		.bit_clk_n(adc_bit_clk_n),
		
		.frame_sync_p(adc_frame_sync_p),
		.frame_sync_n(adc_frame_sync_n),
		
		.clk_adc(adc_clk),
		.data_we(adc_data_we),
		.data(adc_data));
	
	// Receive Ethernet packets
	wire [31:0] udp_data_out;
	wire udp_data_out_en;
	
	packet_receiver packet_receiver (
		.clk(dsp_clk),
		.reset(~gemac_ready),
		
		.rd_flags_i(rd2_flags),
		.rd_data_i(rd2_data),
		
		.rd_src_rdy_i(rd2_src_rdy),
		.rd_dst_rdy_o(rd2_dst_rdy),
		
		.data_out_en(udp_data_out_en),
		.data_out(udp_data_out)
	);
	
	wire	[31:0] or1k_irq;
	wire	[31:0] or1k_dbg_dat_i;
	wire	[31:0] or1k_dbg_adr_i;
	wire	or1k_dbg_we_i;
	wire	or1k_dbg_stb_i;
	wire	or1k_dbg_ack_o;
	wire	[31:0] or1k_dbg_dat_o;
	wire	or1k_dbg_stall_i;
	wire	or1k_dbg_ewt_i;
	wire	[3:0] or1k_dbg_lss_o;
	wire	[1:0] or1k_dbg_is_o;
	wire	[10:0] or1k_dbg_wp_o;
	wire	or1k_dbg_bp_o;
	wire	or1k_dbg_rst;
	wire	sig_tick;
	wire	or1k_rst;
	assign or1k_rst = wb_rst | or1k_dbg_rst;
	
	mor1kx #(
		.FEATURE_DEBUGUNIT("ENABLED"),
		.FEATURE_CMOV("ENABLED"),
		.FEATURE_INSTRUCTIONCACHE("ENABLED"),
		.OPTION_ICACHE_BLOCK_WIDTH(5),
		.OPTION_ICACHE_SET_WIDTH(8),
		.OPTION_ICACHE_WAYS(4),
		.OPTION_ICACHE_LIMIT_WIDTH(32),
		.FEATURE_IMMU("ENABLED"),
		.OPTION_IMMU_SET_WIDTH(7),
		.FEATURE_DATACACHE("ENABLED"),
		.OPTION_DCACHE_BLOCK_WIDTH(5),
		.OPTION_DCACHE_SET_WIDTH(8),
		.OPTION_DCACHE_WAYS(4),
		.OPTION_DCACHE_LIMIT_WIDTH(31),
		.FEATURE_DMMU("ENABLED"),
		.OPTION_DMMU_SET_WIDTH(7),
		.OPTION_PIC_TRIGGER("LATCHED_LEVEL"),
		.IBUS_WB_TYPE("B3_REGISTERED_FEEDBACK"),
		.DBUS_WB_TYPE("B3_REGISTERED_FEEDBACK"),
		.OPTION_CPU0("CAPPUCCINO"),
		.OPTION_RESET_PC(32'h00000100)
	) mor1kx0 (
		.iwbm_adr_o(wb_m2s_or1k_i_adr),
		.iwbm_stb_o(wb_m2s_or1k_i_stb),
		.iwbm_cyc_o(wb_m2s_or1k_i_cyc),
		.iwbm_sel_o(wb_m2s_or1k_i_sel),
		.iwbm_we_o (wb_m2s_or1k_i_we),
		.iwbm_cti_o(wb_m2s_or1k_i_cti),
		.iwbm_bte_o(wb_m2s_or1k_i_bte),
		.iwbm_dat_o(wb_m2s_or1k_i_dat),
		.dwbm_adr_o(wb_m2s_or1k_d_adr),
		.dwbm_stb_o(wb_m2s_or1k_d_stb),
		.dwbm_cyc_o(wb_m2s_or1k_d_cyc),
		.dwbm_sel_o(wb_m2s_or1k_d_sel),
		.dwbm_we_o (wb_m2s_or1k_d_we ),
		.dwbm_cti_o(wb_m2s_or1k_d_cti),
		.dwbm_bte_o(wb_m2s_or1k_d_bte),
		.dwbm_dat_o(wb_m2s_or1k_d_dat),
		.clk(wb_clk),
		.rst(or1k_rst),
		.iwbm_err_i(wb_s2m_or1k_i_err),
		.iwbm_ack_i(wb_s2m_or1k_i_ack),
		.iwbm_dat_i(wb_s2m_or1k_i_dat),
		.iwbm_rty_i(wb_s2m_or1k_i_rty),
		.dwbm_err_i(wb_s2m_or1k_d_err),
		.dwbm_ack_i(wb_s2m_or1k_d_ack),
		.dwbm_dat_i(wb_s2m_or1k_d_dat),
		.dwbm_rty_i(wb_s2m_or1k_d_rty),
		.irq_i(or1k_irq),
		.du_addr_i(or1k_dbg_adr_i[15:0]),
		.du_stb_i(or1k_dbg_stb_i),
		.du_dat_i(or1k_dbg_dat_i),
		.du_we_i(or1k_dbg_we_i),
		.du_dat_o(or1k_dbg_dat_o),
		.du_ack_o(or1k_dbg_ack_o),
		.du_stall_i(or1k_dbg_stall_i),
		.du_stall_o(or1k_dbg_bp_o)
	);
	
	wb_flash_if #(.FLASH_ADR_WIDTH(18), .DUMMY_CYCLES(5))
		flash0 (
			.CLK(clk_flash_io),
			.RESET(wb_rst),
			.SPI_CSN(flash_spi_csn),
			.SPI_CLK(flash_spi_sck),
			.SPI_IO(flash_spi_io),
			.WB_RST_I(wb_clk),
			.WB_CLK_I(wb_rst),
			.WB_ADR_I(wb_m2s_flash0_adr),
			.WB_DAT_I(wb_m2s_flash0_dat),
			.WB_DAT_O(wb_s2m_flash0_dat),
			.WB_WE_I(wb_m2s_flash0_we),
			.WB_SEL_I(wb_m2s_flash0_sel),
			.WB_STB_I(wb_m2s_flash0_stb),
			.WB_ACK_O(wb_s2m_flash0_ack),
			.WB_CYC_I(wb_m2s_flash0_cyc),
			.WB_CTI_I(wb_m2s_flash0_cti),
			.WB_BTE_I(wb_m2s_flash0_bte),
			.WB_RTY_O(wb_s2m_flash0_rty),
			.WB_ERR_O(wb_s2m_flash0_err));
	
	wire uart0_irq;
	
	wb_uart #(.clk_div_val(27))
	uart0(
		.wb_clk_i(wb_clk),
		.wb_rst_i(wb_rst),
		
		.wb_dat_i(wb_m2s_uart0_dat),
		.wb_dat_o(wb_s2m_uart0_dat),
		
		.wb_adr_i(wb_m2s_uart0_adr),
		
		.wb_cyc_i(wb_m2s_uart0_cyc),
		.wb_stb_i(wb_m2s_uart0_stb),
		.wb_we_i(wb_m2s_uart0_we),
		.wb_cti_i(wb_m2s_uart0_cti),
		.wb_bte_i(wb_m2s_uart0_bte),
		
		.wb_ack_o(wb_s2m_uart0_ack),
		.wb_rty_o(wb_s2m_uart0_rty),
		.wb_err_o(wb_s2m_uart0_err),
		
		.uart_out(rs232_tx),
		.uart_in(rs232_rx),
		
		.uart_int(uart0_irq));
	
	
	////////////////////////////////////////////////////////////////////////
	//
	// GENERIC JTAG TAP
	//
	////////////////////////////////////////////////////////////////////////

	wire	dbg_if_select;
	wire	dbg_if_tdo;
	wire	jtag_tap_tdo;
	wire	jtag_tap_shift_dr;
	wire	jtag_tap_pause_dr;
	wire	jtag_tap_update_dr;
	wire	jtag_tap_capture_dr;
	wire  async_reset;
	
	tap_top jtag_tap0 (
		.tdo_pad_o (tdo_pad_o),
		.tms_pad_i (tms_pad_i),
		.tck_pad_i (dbg_tck),
		.trst_pad_i (async_reset),
		.tdi_pad_i (tdi_pad_i),
		.tdo_padoe_o (),
		.tdo_o (jtag_tap_tdo),
		.shift_dr_o (jtag_tap_shift_dr),
		.pause_dr_o (jtag_tap_pause_dr),
		.update_dr_o (jtag_tap_update_dr),
		.capture_dr_o (jtag_tap_capture_dr),
		.extest_select_o (),
		.sample_preload_select_o (),
		.mbist_select_o (),
		.debug_select_o (dbg_if_select),
		.bs_chain_tdi_i (1'b0),
		.mbist_tdi_i (1'b0),
		.debug_tdi_i (dbg_if_tdo)
	);

	
	////////////////////////////////////////////////////////////////////////
	//
	// Debug Interface
	//
	////////////////////////////////////////////////////////////////////////
	adbg_top dbg_if0 (
		// OR1K interface
		.cpu0_clk_i (wb_clk),
		.cpu0_rst_o (or1k_dbg_rst),
		.cpu0_addr_o (or1k_dbg_adr_i),
		.cpu0_data_o (or1k_dbg_dat_i),
		.cpu0_stb_o (or1k_dbg_stb_i),
		.cpu0_we_o (or1k_dbg_we_i),
		.cpu0_data_i (or1k_dbg_dat_o),
		.cpu0_ack_i (or1k_dbg_ack_o),
		.cpu0_stall_o (or1k_dbg_stall_i),
		.cpu0_bp_i (or1k_dbg_bp_o),
		// TAP interface
		.tck_i (dbg_tck),
		.tdi_i (jtag_tap_tdo),
		.tdo_o (dbg_if_tdo),
		.rst_i (wb_rst),
		.capture_dr_i (jtag_tap_capture_dr),
		.shift_dr_i (jtag_tap_shift_dr),
		.pause_dr_i (jtag_tap_pause_dr),
		.update_dr_i (jtag_tap_update_dr),
		.debug_select_i (dbg_if_select),
		// Wishbone debug master
		.wb_rst_i (wb_rst),
		.wb_clk_i (wb_clk),
		.wb_dat_i (wb_s2m_dbg_dat),
		.wb_ack_i (wb_s2m_dbg_ack),
		.wb_err_i (wb_s2m_dbg_err),
		.wb_adr_o (wb_m2s_dbg_adr),
		.wb_dat_o (wb_m2s_dbg_dat),
		.wb_cyc_o (wb_m2s_dbg_cyc),
		.wb_stb_o (wb_m2s_dbg_stb),
		.wb_sel_o (wb_m2s_dbg_sel),
		.wb_we_o (wb_m2s_dbg_we),
		.wb_cti_o (wb_m2s_dbg_cti),
		.wb_bte_o (wb_m2s_dbg_bte)
	);
	
	
	////////////////////////////////////////////////////////////////////////
	//
	// DDR2 SDRAM Memory Controller
	//
	////////////////////////////////////////////////////////////////////////
	xilinx_ddr2_if xilinx_ddr2_0 (
	// R/W
	.wb0_adr_i (0),
	.wb0_bte_i (0),
	.wb0_cti_i (0),
	.wb0_cyc_i (0),
	.wb0_dat_i (0),
	.wb0_sel_i (0),
	.wb0_stb_i (0),
	.wb0_we_i  (0),
	.wb0_ack_o (),
	.wb0_dat_o (),
	// R/W
	.wb1_adr_i (wb_m2s_ddr2_dbus_adr),
	.wb1_bte_i (wb_m2s_ddr2_dbus_bte),
	.wb1_cti_i (wb_m2s_ddr2_dbus_cti),
	.wb1_cyc_i (wb_m2s_ddr2_dbus_cyc),
	.wb1_dat_i (wb_m2s_ddr2_dbus_dat),
	.wb1_sel_i (wb_m2s_ddr2_dbus_sel),
	.wb1_stb_i (wb_m2s_ddr2_dbus_stb),
	.wb1_we_i (wb_m2s_ddr2_dbus_we),
	.wb1_ack_o (wb_s2m_ddr2_dbus_ack),
	.wb1_dat_o (wb_s2m_ddr2_dbus_dat),
	// RO
	.wb2_adr_i (wb_m2s_ddr2_ibus_adr),
	.wb2_bte_i (wb_m2s_ddr2_ibus_bte),
	.wb2_cti_i (wb_m2s_ddr2_ibus_cti),
	.wb2_cyc_i (wb_m2s_ddr2_ibus_cyc),
	.wb2_dat_i (wb_m2s_ddr2_ibus_dat),
	.wb2_sel_i (wb_m2s_ddr2_ibus_sel),
	.wb2_stb_i (wb_m2s_ddr2_ibus_stb),
	.wb2_we_i (wb_m2s_ddr2_ibus_we),
	.wb2_ack_o (wb_s2m_ddr2_ibus_ack),
	.wb2_dat_o (wb_s2m_ddr2_ibus_dat),
	// WO
	.wb3_adr_i (0),
	.wb3_bte_i (0),
	.wb3_cti_i (0),
	.wb3_cyc_i (0),
	.wb3_dat_i (0),
	.wb3_sel_i (0),
	.wb3_stb_i (0),
	.wb3_we_i (0),
	.wb3_ack_o (),
	.wb3_dat_o (),
	// RO
	.wb4_adr_i (0),
	.wb4_bte_i (0),
	.wb4_cti_i (0),
	.wb4_cyc_i (0),
	.wb4_dat_i (0),
	.wb4_sel_i (0),
	.wb4_stb_i (0),
	.wb4_we_i (0),
	.wb4_ack_o (),
	.wb4_dat_o (),
	.wb_clk (wb_clk),
	.wb_rst (wb_rst),
	.ddr2_a (ddr2_a[12:0]),
	.ddr2_ba (ddr2_ba),
	.ddr2_ras_n (ddr2_ras_n),
	.ddr2_cas_n (ddr2_cas_n),
	.ddr2_we_n (ddr2_we_n),
	.ddr2_rzq (ddr2_rzq),
	.ddr2_zio (ddr2_zio),
	.ddr2_odt (ddr2_odt),
	.ddr2_cke (ddr2_cke),
	.ddr2_dm (ddr2_dm),
	.ddr2_udm (ddr2_udm),
	.ddr2_ck (ddr2_ck),
	.ddr2_ck_n (ddr2_ck_n),
	.ddr2_dq (ddr2_dq),
	.ddr2_dqs (ddr2_dqs),
	.ddr2_dqs_n (ddr2_dqs_n),
	.ddr2_udqs (ddr2_udqs),
	.ddr2_udqs_n (ddr2_udqs_n),
	.ddr2_if_clk (ddr2_if_clk),
	.ddr2_if_rst (ddr2_if_rst),
	.ddr2_trace_data0_o(),
	.ddr2_trace_data1_o(),
	.ddr2_trace_data2_o(),
	.ddr2_trace_data3_o(),
	.ddr2_trace_data4_o(),
	.ddr2_trace_data5_o()
	);
	
	assign wb_s2m_ddr2_ibus_err = 0;
	assign wb_s2m_ddr2_ibus_rty = 0;
	
	assign wb_s2m_ddr2_dbus_err = 0;
	assign wb_s2m_ddr2_dbus_rty = 0;
	
	////////////////////////////////////////////////////////////////////////
	//
	// SPI0 controller
	//
	////////////////////////////////////////////////////////////////////////

	//
	// Wires
	//
	wire 			spi0_irq;
	wire [2:0]	spi0_ss;
	wire 			spi0_mosi;
	wire 			spi0_miso;
	wire 			spi0_sck;
	//
	// Assigns
	//
	assign  wb_s2m_spi0_err = 0;
	assign  wb_s2m_spi0_rty = 0;
//	assign  spi0_hold_n_o = 1;
//	assign  spi0_w_n_o = 1;

	simple_spi #(.SS_WIDTH(3))
	spi0(
		// Wishbone slave interface
		.clk_i	(wb_clk),
		.rst_i	(wb_rst),
		.adr_i	(wb_m2s_spi0_adr[2:0]),
		.dat_i	(wb_m2s_spi0_dat),
		.we_i	(wb_m2s_spi0_we),
		.stb_i	(wb_m2s_spi0_stb),
		.cyc_i	(wb_m2s_spi0_cyc),
		.dat_o	(wb_s2m_spi0_dat),
		.ack_o	(wb_s2m_spi0_ack),

		// Outputs
		.inta_o		(spi0_irq),
		.sck_o		(spi0_sck),
		.ss_o		(spi0_ss),
		.mosi_o		(spi0_mosi),

		// Inputs
		.miso_i		(spi0_miso)
	);

	wire scope_armed, scope_triggered;
	
	uart_scope uart_scope (
		.reset(dsp_rst),
		.rxd(1'b1),
		.txd(),
		.baud_clk(baud_clk),
		
		.probes(debug_mac),
		.probe_clk(dsp_clk),
		.armed(scope_armed),
		.triggered(scope_triggered)
	);
	
	reg vhdci_mux_bitslip;
	wire [7:0] mux_in, mux_out;
	
	wire [7:0] mux_out_reg;
	reg mux_synced;
	reg [7:0] sync_pattern;
	reg sync_mon_expect, sync_mon_valid, sync_mon_out;
	reg bitslip_sync;
	
	assign mux_out = (mux_synced) ? mux_out_reg : sync_pattern;
	assign mux_out_reg[7] = sync_mon_out;
	assign mux_out_reg[6:0] = sw[6:0];
	
	always @(posedge clk_mux_div) begin
		if (dsp_rst) begin
			sync_mon_out <= 0;
			mux_synced <= 0;
			vhdci_mux_bitslip <= 0;
			sync_mon_valid <= 0;
			sync_mon_expect <= 0;
			bitslip_sync <= 0;
		end else begin
			sync_mon_out <= !sync_mon_out; // output sync bit to detect loss of link on other side
			vhdci_mux_bitslip <= 0;
			if (mux_synced == 1) begin
				if (sync_mon_valid == 1) begin
					if (sync_mon_expect == mux_in[7]) begin
						sync_mon_expect <= !mux_in[7];
					end else begin
						sync_mon_valid <= 0;
						mux_synced <= 0;
					end
				end else if (mux_in != 8'h81) begin
					sync_mon_expect <= !mux_in[7];
					sync_mon_valid <= 1;
				end
			end else	if (mux_in != 8'h01 && mux_in != 8'h81) begin
					sync_pattern <= 8'h01;
					sync_mon_valid <= 0;
					if (vhdci_mux_bitslip == 0 && bitslip_sync == 0)
						vhdci_mux_bitslip <= 1;
				end else begin
					if (mux_in == 8'h81 && sync_pattern == 8'h81)
						mux_synced <= 1;
					sync_pattern <= 8'h81;
				end
			end
			bitslip_sync <= vhdci_mux_bitslip;
		end
	
	
	FPGA_MUX vhdci_mux
   (
     // From the system into the device
     .DATA_IN_FROM_PINS_P     ({VHDCI_MUX_IN_P}),
     .DATA_IN_FROM_PINS_N     ({VHDCI_MUX_IN_N}),
     .DATA_IN_TO_DEVICE       (mux_in),
     // From the drive out to the system
     .DATA_OUT_FROM_DEVICE    (mux_out),
     .DATA_OUT_TO_PINS_P      ({VHDCI_MUX_OUT_P}),
     .DATA_OUT_TO_PINS_N      ({VHDCI_MUX_OUT_N}),
     .BITSLIP                 (vhdci_mux_bitslip),
     .CLK_IN                  (clk_mux),
     .CLK_DIV_IN              (clk_mux_div),
	  .LOCKED_IN               (mux_pll_locked),
	  .LOCKED_OUT              (),
     .IO_RESET                (dsp_rst));

	////////////////////////////////////////////////////////////////////////
	//
	// Interrupt assignment
	//
	////////////////////////////////////////////////////////////////////////
	assign or1k_irq[0] = 0; // Non-maskable inside OR1K
	assign or1k_irq[1] = 0; // Non-maskable inside OR1K
	assign or1k_irq[2] = uart0_irq;
	assign or1k_irq[3] = 0;
	assign or1k_irq[4] = 0;
	assign or1k_irq[5] = 0;
	assign or1k_irq[6] = spi0_irq;
	assign or1k_irq[7] = 0;
	assign or1k_irq[8] = 0;
	assign or1k_irq[9] = 0;
	assign or1k_irq[10] = 0;
	assign or1k_irq[11] = 0;
	assign or1k_irq[12] = 0;
	assign or1k_irq[13] = 0;
	assign or1k_irq[14] = 0;
	assign or1k_irq[15] = 0;
	assign or1k_irq[16] = 0;
	assign or1k_irq[17] = 0;
	assign or1k_irq[18] = 0;
	assign or1k_irq[19] = 0;
	assign or1k_irq[20] = 0;
	assign or1k_irq[21] = 0;
	assign or1k_irq[22] = 0;
	assign or1k_irq[23] = 0;
	assign or1k_irq[24] = 0;
	assign or1k_irq[25] = 0;
	assign or1k_irq[26] = 0;
	assign or1k_irq[27] = 0;
	assign or1k_irq[28] = 0;
	assign or1k_irq[29] = 0;
	assign or1k_irq[30] = 0;
	assign or1k_irq[31] = 0;

endmodule