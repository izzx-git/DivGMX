--modified by izzx, 2025

--See documentation



-------------------------------------------------------------------[08.05.2017]
-- FPGA SoftCore - Basic build 20170508
-- DEVBOARD DivGMX Rev.A
-------------------------------------------------------------------------------
-- Engineer: MVV <mvvproject@gmail.com>
--
-- https://github.com/mvvproject/DivGMX
--
-- All rights reserved
--
-- Redistribution and use in source and synthezised forms, with or without
-- modification, are permitted provided that the following conditions are met:
--
-- * Redistributions of source code must retain the above copyright notice,
--   this list of conditions and the following disclaimer.
--
-- * Redistributions in synthesized form must reproduce the above copyright
--   notice, this list of conditions and the following disclaimer in the
--   documentation and/or other materials provided with the distribution.
--
-- * Neither the name of the author nor the names of other contributors may
--   be used to endorse or promote products derived from this software without
--   specific prior written agreement from the author.
--
-- * License is granted for non-commercial use only.  A fee may not be charged
--   for redistributions as source code or in synthesized/hardware form without 
--   specific prior written agreement from the author.
--
-- THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
-- AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
-- THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
-- PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE
-- LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
-- CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
-- SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
-- INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
-- CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
-- ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
-- POSSIBILITY OF SUCH DAMAGE.

--build 20161127	Вывод изображения на HDMI со звуком
--			Чтение порта #7FFD
--			Kempston mouse
--			SounDrive
--build 20161225	DivMMC/Z-Controller
--build 20161225	Turbo Sound Easy (SAA1099)
--build 20161231	Kempston mouse turbo (master/slave)
--build 20170112	OSD для отладки
--build 20170429	clk_bus=112MHz

--CMOS (стандарт Mr. Gluk)
--Kempston joystick/Gamepad
--General Sound


library IEEE; 
use IEEE.std_logic_1164.all; 
use IEEE.std_logic_unsigned.all;
use IEEE.numeric_std.all; 

entity basic is
port (
	-- Clock (50MHz)
	CLK_50MHZ	: in std_logic;
	-- HDMI
	TMDS		: out std_logic_vector(7 downto 0);
	-- USB Host (VNC2-32)
	USB_IO3		: in std_logic;
	USB_TXD		: in std_logic;
--	USB_RXD		: out std_logic;
	-- SPI (W25Q64/SD)
--	DATA0		: in std_logic;
--	ASDO		: out std_logic;
--	DCLK		: out std_logic;
--	NCSO		: out std_logic;
	-- I2C (HDMI/RTC)
--	I2C_SCL		: inout std_logic;
--	I2C_SDA		: inout std_logic;
	-- SD
--	SD_NDET		: in std_logic;
--	SD_NCS		: out std_logic;
	-- SDRAM (32M8)
	DRAM_DQ		: inout std_logic_vector(7 downto 0);
	DRAM_A		: out std_logic_vector(12 downto 0);
	DRAM_BA		: out std_logic_vector(1 downto 0);
	DRAM_DQM	: out std_logic;
	DRAM_CLK	: out std_logic;
	DRAM_NWE	: out std_logic;
	DRAM_NCAS	: out std_logic;
	DRAM_NRAS	: out std_logic;
--	-- Audio
--	OUT_L		: out std_logic;
--	OUT_R		: out std_logic;
	-- ZXBUS
--	BUF_NINT	: in std_logic;
--	BUF_NNMI	: in std_logic;
	BUF_NRESET	: in std_logic;
	BUF_DIR		: out std_logic_vector(1 downto 0);
--	BUS_CLK		: inout std_logic;
	BUS_D		: inout std_logic_vector(7 downto 0);
	BUS_A		: inout std_logic_vector(15 downto 0);
	BUS_NMREQ	: inout std_logic;
	BUS_NIORQ	: inout std_logic;
--	BUS_NBUSACK	: inout std_logic;
	BUS_NRD		: inout std_logic;
	BUS_NWR		: inout std_logic;
	BUS_NM1		: inout std_logic;
	BUS_NRFSH	: inout std_logic;
	BUS_NINT	: out std_logic;
	BUS_NWAIT	: out std_logic;
	BUS_NBUSRQ	: out std_logic;
	BUS_NROMOE	: out std_logic;
	BUS_NIORQGE	: out std_logic);
end basic;

architecture rtl of basic is

--signal areset		: std_logic;
signal clk_vga		: std_logic;
signal clk_tmds		: std_logic;
signal clk_bus		: std_logic;
signal clk_sdr		: std_logic;
signal clk_saa		: std_logic;
signal clk_osd		: std_logic;

signal sync_hsync	: std_logic;
signal sync_vsync	: std_logic;
signal sync_blank	: std_logic;
signal sync_h		: std_logic_vector(9 downto 0);
signal sync_hcnt	: std_logic_vector(9 downto 0);
signal sync_vcnt	: std_logic_vector(9 downto 0);
signal sync_flash	: std_logic;

signal vga_r		: std_logic_vector(2 downto 0);--цвета спек экрана
signal vga_g		: std_logic_vector(2 downto 0);
signal vga_b		: std_logic_vector(2 downto 0);
signal vga_di		: std_logic_vector(7 downto 0);

signal osd_red		: std_logic_vector(7 downto 0);--цвета OSD
signal osd_green	: std_logic_vector(7 downto 0);
signal osd_blue		: std_logic_vector(7 downto 0);

-- Audio
signal beeper		: std_logic_vector(7 downto 0);
signal audio_l		: std_logic_vector(15 downto 0);
signal audio_r		: std_logic_vector(15 downto 0);

--ESCR
signal vram_wr		: std_logic;--сигнал запись во внутреннюю видеопамять zx
signal vram_wr_escr		: std_logic;--сигнал запись во внутреннюю видеопамять escr
signal escr_sdram_wr		: std_logic; --флаг записи в видеопамять
signal escr_sdram_rd		: std_logic; --флаг чтения из видеопамяти
signal escr_vram_wr		: std_logic; --флаг записи в видеопамять
signal escr_vram_rd		: std_logic; --флаг чтения из видеопамяти
signal escr_sdr_rd	: std_logic; --флаг чтения из видеопамяти sdram для видеоадаптера
signal vram_escr_addr_in		: std_logic_vector(7 downto 0);--адрес записи во внутреннюю видеопамять escr
signal vram_escr_addr_out	: std_logic_vector(7 downto 0);--адрес чтения из внутренней видеопамяти escr
signal vga_di_escr: std_logic_vector(7 downto 0); --данные из внутренней памяти escr

signal reg_mreq_n_i	: std_logic;
signal reg_iorq_n_i	: std_logic;
signal reg_rd_n_i	: std_logic;
signal reg_wr_n_i	: std_logic;
signal reg_a_i		: std_logic_vector(15 downto 0);
signal reg_d_i		: std_logic_vector(7 downto 0);
signal reg_reset_n_i	: std_logic;
signal reg_m1_n_i	: std_logic;
signal reg_rfsh_n_i	: std_logic;
signal mreq_n_i		: std_logic;
signal iorq_n_i		: std_logic;
signal rd_n_i		: std_logic;
signal wr_n_i		: std_logic;
signal a_i		: std_logic_vector(15 downto 0);
signal d_i		: std_logic_vector(7 downto 0);
signal reset_n_i	: std_logic;
signal m1_n_i		: std_logic;
signal rfsh_n_i		: std_logic;

signal vram_scr		: std_logic;
signal escr_sdram_scr		: std_logic; --флаг что идёт обращение к видеопамяти
signal escr_vram_scr		: std_logic; --флаг что идёт обращение к видеопамяти
signal ram_addr		: std_logic_vector(7 downto 0);
signal sdram_addr_full	: std_logic_vector(24 downto 0); --полный адрес ячейки памяти sdram
signal ram_addr_high		: std_logic_vector(3 downto 0) := "0000"; --Старшие биты адреса памяти
signal port_7ffd_reg	: std_logic_vector(7 downto 0) := "00010000";
signal mux		: std_logic_vector(3 downto 0);
signal port_xxfe_reg	: std_logic_vector(7 downto 0);
signal vga_addr		: std_logic_vector(12 downto 0);
signal escr_vga_addr		: std_logic_vector(24 downto 0); --адрес чтения sdram для escr
signal vram_escr_addr_rd		: std_logic_vector(14 downto 0); --адрес чтения vrma для escr
signal vram_escr_addr_wr		: std_logic_vector(14 downto 0); --адрес записи vram для escr
signal vram_escr_addr_rd_full		: std_logic_vector(14 downto 0); --итоговый адрес чтения vram для escr
signal rom_do		: std_logic_vector(7 downto 0);
-- DIVMMC
signal divmmc_do	: std_logic_vector(7 downto 0);
signal divmmc_amap	: std_logic;
signal divmmc_e3reg	: std_logic_vector(7 downto 0);	
signal divmmc_ncs	: std_logic;
signal divmmc_sclk	: std_logic;
signal divmmc_mosi	: std_logic;
-- SDRAM
signal sdr_do		: std_logic_vector(7 downto 0); --байт для чтения из памяти
signal sdr_do_ok	: std_logic; --флаг что данные на выходе готовы
signal sdr_wr		: std_logic;
signal sdr_rd		: std_logic;
signal sdr_rfsh		: std_logic;
signal sdr_idle		: std_logic;

signal selector		: std_logic_vector(7 downto 0);

-- Soundrive
signal covox_a		: std_logic_vector(7 downto 0);
signal covox_b		: std_logic_vector(7 downto 0);
signal covox_c		: std_logic_vector(7 downto 0);
signal covox_d		: std_logic_vector(7 downto 0);
-- TurboSound
signal ssg_sel		: std_logic;
signal ssg0_do_bus	: std_logic_vector(7 downto 0);
signal ssg0_a		: std_logic_vector(7 downto 0);
signal ssg0_b		: std_logic_vector(7 downto 0);
signal ssg0_c		: std_logic_vector(7 downto 0);
signal ssg1_do_bus	: std_logic_vector(7 downto 0);
signal ssg1_a		: std_logic_vector(7 downto 0);
signal ssg1_b		: std_logic_vector(7 downto 0);
signal ssg1_c		: std_logic_vector(7 downto 0);
-- Z-Controller
signal zc_do_bus	: std_logic_vector(7 downto 0);
signal zc_ncs		: std_logic;
signal zc_sclk		: std_logic;
signal zc_mosi		: std_logic;
signal zc_rd		: std_logic;
signal zc_wr		: std_logic;
-- Mouse
signal ms0_x		: std_logic_vector(7 downto 0);
signal ms0_y		: std_logic_vector(7 downto 0);
signal ms0_z		: std_logic_vector(7 downto 0);
signal ms0_b		: std_logic_vector(7 downto 0);
signal ms1_x		: std_logic_vector(7 downto 0);
signal ms1_y		: std_logic_vector(7 downto 0);
signal ms1_z		: std_logic_vector(7 downto 0);
signal ms1_b		: std_logic_vector(7 downto 0);
-- Keyboard
signal kb_do_bus	: std_logic_vector(4 downto 0);
signal kb_fn_bus	: std_logic_vector(12 downto 1);
signal kb_fn		: std_logic_vector(12 downto 1);
signal key		: std_logic_vector(12 downto 1) := "000000000000";

signal ena_1_75mhz	: std_logic;
signal clk_28		: std_logic;
--signal ena_0_4375mhz	: std_logic;
signal ena_cnt		: std_logic_vector(7 downto 0);
-- I2C
--signal i2c_do_bus	: std_logic_vector(7 downto 0);
--signal i2c_wr		: std_logic;
-- ESCR
constant escr_port_addr_low		: std_logic_vector(7 downto 0) := X"5B";	-- Младший байт адреса всех портов
--constant escr_port_addr_sys		: std_logic_vector(7 downto 0) := X"00";	-- Системный порт (старший байт адреса)
signal escr_do_bus	: std_logic_vector(7 downto 0) := "00000000"; --переходный регистр для обмена между модулями
signal escr_port_00	: std_logic_vector(7 downto 0) := "00000000"; --Port (sys)
signal escr_port_01	: std_logic_vector(7 downto 0) := "00000000"; --Port (page sdram)
signal escr_port_02	: std_logic_vector(7 downto 0) := "00000000"; --Port (page vram)
signal escr_port_03	: std_logic_vector(7 downto 0) := "00000000"; --Port (scroll 1)
signal escr_port_04	: std_logic_vector(7 downto 0) := "00000000"; --Port (scroll 2)
signal escr_port_05	: std_logic_vector(7 downto 0) := "00000000"; --Port (transparent color)

signal escr_port_10	: std_logic_vector(7 downto 0) := "00000000"; --Port (palette)
signal escr_port_11	: std_logic_vector(7 downto 0) := "00000000"; --Port (palette)
signal escr_port_12	: std_logic_vector(7 downto 0) := "00000000"; --Port (palette)
signal escr_port_13	: std_logic_vector(7 downto 0) := "00000000"; --Port (palette)
signal escr_port_14	: std_logic_vector(7 downto 0) := "00000000"; --Port (palette)
signal escr_port_15	: std_logic_vector(7 downto 0) := "00000000"; --Port (palette)
signal escr_port_16	: std_logic_vector(7 downto 0) := "00000000"; --Port (palette)
signal escr_port_17	: std_logic_vector(7 downto 0) := "00000000"; --Port (palette)
signal escr_port_18	: std_logic_vector(7 downto 0) := "00000000"; --Port (palette)
signal escr_port_19	: std_logic_vector(7 downto 0) := "00000000"; --Port (palette)
signal escr_port_1a	: std_logic_vector(7 downto 0) := "00000000"; --Port (palette)
signal escr_port_1b	: std_logic_vector(7 downto 0) := "00000000"; --Port (palette)
signal escr_port_1c	: std_logic_vector(7 downto 0) := "00000000"; --Port (palette)
signal escr_port_1d	: std_logic_vector(7 downto 0) := "00000000"; --Port (palette)
signal escr_port_1e	: std_logic_vector(7 downto 0) := "00000000"; --Port (palette)
signal escr_port_1f	: std_logic_vector(7 downto 0) := "00000000"; --Port (palette)

signal escr_wr		: std_logic;
signal escr_rd		: std_logic;
-- SAA1099
signal saa_wr_n		: std_logic;
signal saa_out_l	: std_logic_vector(7 downto 0);
signal saa_out_r	: std_logic_vector(7 downto 0);

signal trdos		: std_logic;
signal rom1_do		: std_logic_vector(7 downto 0);

--component saa1099
--port (
--	clk_sys		: in std_logic;
--	ce		: in std_logic;		--8 MHz
--	rst_n		: in std_logic;
--	cs_n		: in std_logic;
--	a0		: in std_logic;		--0=data, 1=address
--	wr_n		: in std_logic;
--	din		: in std_logic_vector(7 downto 0);
--	out_l		: out std_logic_vector(7 downto 0);
--	out_r		: out std_logic_vector(7 downto 0));
--end component;


begin

-- PLL
U1: entity work.altpll0
port map (
	areset		=> '0',
	locked		=> open,
	inclk0		=> CLK_50MHZ,	--  50.00 MHz
	c0		=> clk_vga,	--  25.20 MHz
	c1		=> clk_tmds,	-- 126.00 MHz
	c2		=> clk_sdr,	--  84.00 MHz
	c3		=> clk_28);	--  28.00 MHz

-- HDMI
U2: entity work.hdmi
generic map (
	FREQ		=> 25200000,	-- pixel clock frequency = 25.2MHz
	FS		=> 48000,	-- audio sample rate - should be 32000, 41000 or 48000 = 48KHz
	CTS		=> 25200,	-- CTS = Freq(pixclk) * N / (128 * Fs)
	N		=> 6144)	-- N = 128 * Fs /1000,  128 * Fs /1500 <= N <= 128 * Fs /300 (Check HDMI spec 7.2 for details)
port map (
	I_CLK_VGA	=> clk_vga,
	I_CLK_TMDS	=> clk_tmds,
	I_HSYNC		=> sync_hsync,
	I_VSYNC		=> sync_vsync,
	I_BLANK		=> sync_blank,
	I_RED		=> osd_red,
	I_GREEN		=> osd_green,
	I_BLUE		=> osd_blue,
	I_AUDIO_PCM_L 	=> audio_l,
	I_AUDIO_PCM_R	=> audio_r,
	O_TMDS		=> TMDS);

-- Sync
U3: entity work.sync
port map (
	I_CLK		=> clk_vga,
	I_EN		=> '1',
	O_H		=> sync_h,
	O_HCNT		=> sync_hcnt,
	O_VCNT		=> sync_vcnt,
	O_INT		=> open,
	O_FLASH		=> sync_flash,
	O_BLANK		=> sync_blank,
	O_HSYNC		=> sync_hsync,
	O_VSYNC		=> sync_vsync);	

-- Video
U4: entity work.vga_zx
port map (
	I_CLK		=> clk_vga,
	I_CLKEN		=> '1',
	I_DATA		=> vga_di, --данные из памяти vram для отображения
	I_DATA_SDRAM_ESCR		=> sdr_do, --данные из памяти sdram для отображения
	I_DATA_ESCR_OK		=> sdr_do_ok, --флаг что данные на выходе sdram готовы
	I_ESCR_PORT_00		=> escr_port_00, --значение порт
	
	I_ESCR_PORT_03		=> escr_port_03, --значение порт
	I_ESCR_PORT_04		=> escr_port_04, --значение порт
	I_ESCR_PORT_05		=> escr_port_05, --значение порт
	
	I_ESCR_PORT_10		=> escr_port_10, --значение порт
	I_ESCR_PORT_11		=> escr_port_11, --значение порт
	I_ESCR_PORT_12		=> escr_port_12, --значение порт
	I_ESCR_PORT_13		=> escr_port_13, --значение порт
	I_ESCR_PORT_14		=> escr_port_14, --значение порт
	I_ESCR_PORT_15		=> escr_port_15, --значение порт
	I_ESCR_PORT_16		=> escr_port_16, --значение порт
	I_ESCR_PORT_17		=> escr_port_17, --значение порт
	I_ESCR_PORT_18		=> escr_port_18, --значение порт
	I_ESCR_PORT_19		=> escr_port_19, --значение порт
	I_ESCR_PORT_1a		=> escr_port_1a, --значение порт
	I_ESCR_PORT_1b		=> escr_port_1b, --значение порт
	I_ESCR_PORT_1c		=> escr_port_1c, --значение порт
	I_ESCR_PORT_1d		=> escr_port_1d, --значение порт
	I_ESCR_PORT_1e		=> escr_port_1e, --значение порт
	I_ESCR_PORT_1f		=> escr_port_1f, --значение порт
	I_ESCR_SDRAM_SCR	=> escr_sdram_scr, --флаг чтения/записи в память sdram со стороны компьютера
--	O_ADDR_VRAM_ESCR_WR	=> vram_escr_addr_wr, --адрес для записи память vram_escr
	O_ADDR_VRAM_ESCR_RD	=> vram_escr_addr_rd, --адрес для чтения память vram_escr
--	O_VRAM_WR_ESCR 	=> vram_wr_escr, --разрешение записи в память vram_escr
	I_DATA_VRAM_ESCR 		=> vga_di_escr, --данные из памяти vram_escr
	I_CLK_SDR	=> clk_sdr, --клок sdram
	I_BORDER	=> port_xxfe_reg(2 downto 0),	-- Биты D0..D2 порта xxFE определяют цвет бордюра
	I_HCNT		=> sync_hcnt,
	I_VCNT		=> sync_vcnt,
	I_BLANK		=> sync_blank,
	I_FLASH		=> sync_flash,
	O_ADDR		=> vga_addr, --адрес чтения из памяти vram
	O_ADDR_SDRAM_ESCR		=> escr_vga_addr, --адрес чтения из памяти sdram
	O_SDR_RD 	=> escr_sdr_rd, --разрешение чтения sdram
	O_PAPER		=> open,
	O_RED		=> vga_r,
	O_GREEN		=> vga_g,
	O_BLUE		=> vga_b);	
	
-- Video RAM 16K
U5: entity work.vram --память двухпортовая внутренняя
port map (
	address_a	=> vram_scr & a_i(12 downto 0), --8к на каждый из двух экранов, всего 16к
	address_b	=> port_7ffd_reg(3) & vga_addr, --8к на каждый из двух экранов, всего 16к
	clock_a		=> clk_bus,
	clock_b		=> clk_vga,
	data_a	 	=> d_i, --данные в память
	data_b	 	=> (others => '0'),
	wren_a	 	=> vram_wr,
	wren_b	 	=> '0',
	q_a	 	=> open,
	q_b	 	=> vga_di); --данные из памяти
	
-- Video RAM ESCR
U20: entity work.vram_escr --память двухпортовая внутренняя
port map (
	address_a	=> escr_port_02(1 downto 0) & a_i(12 downto 0), --адрес для записи
	address_b	=> vram_escr_addr_rd_full, --адрес для чтения
	clock_a		=> clk_bus,
	clock_b		=> clk_vga,
	data_a	 	=> d_i, --данные в память
	data_b	 	=> (others => '0'),
	wren_a	 	=> escr_vram_wr, --разрешение записи в память
	wren_b	 	=> '0',
	q_a	 	=> open,
	q_b	 	=> vga_di_escr); --данные из памяти

--U6: entity work.rom
--port map (
--	address		=> a_i(12 downto 0),
--	clock		=> clk_bus,
--	q		=> rom_do);

-- SDRAM Controller
U7: entity work.sdram
port map (
	I_CLK		=> clk_sdr,
	-- Memory port
--	I_ADDR		=> ram_addr_high & ram_addr & a_i(12 downto 0), --тут полный адрес в памяти
	I_ADDR		=> sdram_addr_full, --тут полный адрес в памяти
	I_DATA		=> d_i,
	O_DATA		=> sdr_do,
	O_DATA_OK	=> sdr_do_ok, --флаг что данные на выходе готовы
	I_WR		=> sdr_wr,
	I_RD		=> sdr_rd,
	I_RFSH		=> sdr_rfsh,
	O_IDLE		=> sdr_idle,
	-- SDRAM Pin
	O_CLK		=> DRAM_CLK,
	O_RAS		=> DRAM_NRAS,
	O_CAS		=> DRAM_NCAS,
	O_WE		=> DRAM_NWE,
	O_DQM		=> DRAM_DQM,
	O_BA		=> DRAM_BA,
	O_MA		=> DRAM_A,
	IO_DQ		=> DRAM_DQ);

---- DIVMMC Interface
--U8: entity work.divmmc
--port map (
--	I_CLK		=> clk_bus,
--	I_SCLK		=> clk_28,
--	I_CS		=> kb_fn(6),
--	I_RESET		=> not reset_n_i,
--	I_ADDR		=> a_i,
--	I_DATA		=> d_i,
--	O_DATA		=> divmmc_do,
--	I_WR_N		=> wr_n_i,
--	I_RD_N		=> rd_n_i,
--	I_IORQ_N	=> iorq_n_i,
--	I_MREQ_N	=> mreq_n_i,
--	I_M1_N		=> m1_n_i,
--	I_RFSH_N	=> rfsh_n_i,
--	O_E3REG		=> divmmc_e3reg,
--	O_AMAP		=> divmmc_amap,
--	O_CS_N		=> divmmc_ncs,
--	O_SCLK		=> divmmc_sclk,
--	O_MOSI		=> divmmc_mosi,
--	I_MISO		=> DATA0);	

---- Soundrive
--U9: entity work.soundrive
--port map (
--	I_RESET		=> not reset_n_i,
--	I_CLK		=> clk_bus,
--	I_CS		=> '1',
--	I_WR_N		=> wr_n_i,
--	I_ADDR		=> a_i(7 downto 0),
--	I_DATA		=> d_i,
--	I_IORQ_N	=> iorq_n_i,
--	I_DOS		=> trdos,
--	O_COVOX_A	=> covox_a,
--	O_COVOX_B	=> covox_b,
--	O_COVOX_C	=> covox_c,
--	O_COVOX_D	=> covox_d);
	
---- TurboSound
--U10: entity work.turbosound
--port map (
--	I_CLK		=> clk_bus,
--	I_ENA		=> ena_1_75mhz,
--	I_ADDR		=> a_i,
--	I_DATA		=> d_i,
--	I_WR_N		=> wr_n_i,
--	I_IORQ_N	=> iorq_n_i,
--	I_M1_N		=> m1_n_i,
--	I_RESET_N	=> reset_n_i,
--	O_SEL		=> ssg_sel,
--	-- ssg0
--	O_SSG0_DA	=> ssg0_do_bus,
--	O_SSG0_AUDIO_A	=> ssg0_a,
--	O_SSG0_AUDIO_B	=> ssg0_b,
--	O_SSG0_AUDIO_C	=> ssg0_c,
--	-- ssg1
--	O_SSG1_DA	=> ssg1_do_bus,
--	O_SSG1_AUDIO_A	=> ssg1_a,
--	O_SSG1_AUDIO_B	=> ssg1_b,
--	O_SSG1_AUDIO_C	=> ssg1_c);
	
---- Z-Controller
--U11: entity work.zcontroller
--port map (
--	I_RESET		=> not reset_n_i,
--	I_CLK		=> clk_28,
--	I_ADDR		=> a_i(5),
--	I_DATA		=> d_i,
--	O_DATA		=> zc_do_bus,
--	I_RD		=> zc_rd,
--	I_WR		=> zc_wr,
--	I_SDDET		=> SD_NDET,
--	I_SDPROT	=> '0',
--	O_CS_N		=> zc_ncs,
--	O_SCLK		=> zc_sclk,
--	O_MOSI		=> zc_mosi,
--	I_MISO		=> DATA0);

---- Delta-Sigma
--U12: entity work.dac
--generic map (
--	msbi_g		=> 15)
--port map (
--	I_CLK		=> clk_bus,
--	I_RESET		=> not reset_n_i,
--	I_DATA		=> audio_l,
--	O_DAC		=> OUT_L);

--U13: entity work.dac
--generic map (
--	msbi_g		=> 15)
--port map (
--	I_CLK		=> clk_bus,
--	I_RESET		=> not reset_n_i,
--	I_DATA		=> audio_r,
--	O_DAC		=> OUT_R);	

-- USB HID
U14: entity work.deserializer
generic map (
	divisor			=> 434)		-- divisor = 50MHz / 115200 Baud = 434
port map(
	I_CLK			=> CLK_50MHZ,
	I_RESET			=> not reset_n_i,
	I_RX			=> USB_TXD,
	I_NEWFRAME		=> USB_IO3,
	I_ADDR			=> a_i(15 downto 8),
	O_MOUSE0_X		=> ms0_x,
	O_MOUSE0_Y		=> ms0_y,
	O_MOUSE0_Z		=> ms0_z,
	O_MOUSE0_BUTTONS	=> ms0_b,
	O_MOUSE1_X		=> ms1_x,
	O_MOUSE1_Y		=> ms1_y,
	O_MOUSE1_Z		=> ms1_z,
	O_MOUSE1_BUTTONS	=> ms1_b,
	O_KEY0			=> open,--kb_key0,
	O_KEY1			=> open,--kb_key1,
	O_KEY2			=> open,--kb_key2,
	O_KEY3			=> open,--kb_key3,
	O_KEY4			=> open,--kb_key4,
	O_KEY5			=> open,--kb_key5,
	O_KEY6			=> open,--kb_key6,
	O_KEYBOARD_SCAN		=> kb_do_bus,
	O_KEYBOARD_FKEYS	=> kb_fn_bus,
	O_KEYBOARD_JOYKEYS	=> open,--kb_joy_bus,
	O_KEYBOARD_CTLKEYS	=> open);--kb_soft_bus);

-- I2C Controller
--U15: entity work.i2c
--port map (
--	I_RESET		=> not reset_n_i,
--	I_CLK		=> clk_bus,
--	I_ENA		=> ena_0_4375mhz,
--	I_ADDR		=> a_i(4),
--	I_DATA		=> d_i,
--	O_DATA		=> i2c_do_bus,
--	I_WR		=> i2c_wr,
--	IO_I2C_SCL	=> I2C_SCL,
--	IO_I2C_SDA	=> I2C_SDA);

---- ESCR Controller
--U15: entity work.escr
--port map (
--	I_RESET		=> not reset_n_i,
--	I_CLK		=> clk_bus,
----	I_ENA		=> ena_0_4375mhz,
--	I_ADDR		=> a_i,
--	I_DATA		=> d_i,
--	O_DATA		=> escr_do_bus,
--	I_RD		=> escr_rd,
--	I_WR		=> escr_wr);
----	IO_I2C_SCL	=> I2C_SCL,
----	IO_I2C_SDA	=> I2C_SDA);

--U16: saa1099
--port map(
--	clk_sys		=> clk_saa,
--	ce		=> '1',			-- 8 MHz
--	rst_n		=> reset_n_i,
--	cs_n		=> '0',
--	a0		=> a_i(8),		-- 0=data, 1=address
--	wr_n		=> saa_wr_n,
--	din		=> d_i,
--	out_l		=> saa_out_l,
--	out_r		=> saa_out_r);

U17: entity work.osd
port map(
	I_RESET		=> '0',--not reset_n_i,
	I_CLK_VGA	=> clk_vga,
	I_CLK_CPU	=> clk_osd,
	
	I_P0		=> port_7ffd_reg,
	I_P1		=> port_xxfe_reg,
	I_P2		=> ms0_z(3 downto 0) & '1' & not ms0_b(2) & not ms0_b(0) & not ms0_b(1),
	I_P3		=> ms0_x,
	I_P4		=> ms0_y,
	I_P5		=> ms1_z(3 downto 0) & '1' & not ms1_b(2) & not ms1_b(0) & not ms1_b(1),
	I_P6		=> ms1_x,
	I_P7		=> ms1_y,
	I_P8		=> divmmc_e3reg,
	I_P9		=> covox_a,
	I_P10		=> covox_b,
	I_P11		=> covox_c,
	I_P12		=> covox_d,
	I_P13		=> divmmc_amap & kb_fn(6) & kb_fn(7) & kb_fn(5) & trdos & "000",
	I_P14		=> a_i(15 downto 8),
	I_P15		=> a_i(7 downto 0),
	
	I_KEY		=> not kb_fn(1),
	I_RED		=> vga_r & vga_r & vga_r(1 downto 0), --собираем 8 бит цвета. главное старшие, младшие мало значат (?)
	I_GREEN		=> vga_g & vga_g & vga_g(1 downto 0),
	I_BLUE		=> vga_b & vga_b & vga_b(1 downto 0),
	I_HCNT		=> sync_hcnt,
	I_VCNT		=> sync_vcnt,
	I_H		=> sync_h,
	O_RED		=> osd_red,
	O_GREEN		=> osd_green,
	O_BLUE		=> osd_blue);

-- PLL1
U18: entity work.altpll1
port map (
	areset		=> '0',
	locked		=> open,
	inclk0		=> CLK_50MHZ,	--  50.00 MHz
	c0		=> clk_osd,	--  40.00 MHz
	c1		=> clk_saa,	--   8.00 MHz
	c2		=> clk_bus);	-- 112.00 MHz
	
--U19: entity work.rom1
--port map (
--	address		=> a_i(13 downto 0),
--	clock		=> clk_bus,
--	q		=> rom1_do);
	
-------------------------------------------------------------------------------	
-- F6 = Z-Controller/DivMMC
-- F7 = Keyboard USB/Standart
process (clk_bus, key, kb_fn_bus, kb_fn)
begin
	if (clk_bus'event and clk_bus = '1') then
		key <= kb_fn_bus;
		if (kb_fn_bus /= key) then
			kb_fn <= kb_fn xor key;
		end if;
	end if;
end process;

-------------------------------------------------------------------------------	
-- I2C
--i2c_wr <= '1' when (a_i(7 downto 5) = "100" and a_i(3 downto 0) = "1100" and wr_n_i = '0' and iorq_n_i = '0') else '0';		-- I2C Port xx8C/xx9C[xxxxxxxx_100n1100]
-------------------------------------------------------------------------------	
-- ESCR Port
escr_wr <= '1' when (a_i(7 downto 0) = escr_port_addr_low and wr_n_i = '0' and iorq_n_i = '0') else '0';		-- ESCR Port
escr_rd <= '1' when (a_i(7 downto 0) = escr_port_addr_low and rd_n_i = '0' and iorq_n_i = '0') else '0';		-- ESCR Port

--escr_port_01 <= d_i when (a_i(15 downto 8) = X"01" and escr_wr = '1');	-- Скопировать значение порта 01
--escr_port_00 <= d_i when (a_i(15 downto 8) = X"00" and escr_wr = '1' and reset_n_i = '1');	-- Скопировать значение порта 00
--escr_port_01 <= d_i when (a_i(15 downto 8) = X"01" and escr_wr = '1' and reset_n_i = '1');	-- Скопировать значение порта 01
----escr_port_01 <= d_i when (a_i(15 downto 8) = X"01" and escr_wr = '1' and reset_n_i = '1');	-- Скопировать значение порта 01
--	if (reset_n_i = '0') then
--		escr_port_00 <= (others => '0');
--	end if;
--escr_port_00 <= X"00" when (reset_n_i = '0');
--escr_port_01 <= X"00" when (reset_n_i = '0');



-------------------------------------------------------------------------------	
---- Z-Controller	
--zc_wr 	<= '1' when (iorq_n_i = '0' and wr_n_i = '0' and a_i(7 downto 6) = "01" and a_i(4 downto 0) = "10111") else '0';
--zc_rd 	<= '1' when (iorq_n_i = '0' and rd_n_i = '0' and a_i(7 downto 6) = "01" and a_i(4 downto 0) = "10111") else '0';
	
-------------------------------------------------------------------------------
-- SDRAM
--sdr_wr <= not (mreq_n_i or wr_n_i);
--sdr_rd <= not (mreq_n_i or rd_n_i);
--sdr_rfsh <= not rfsh_n_i;

process (clk_sdr, mreq_n_i, wr_n_i, rd_n_i, rfsh_n_i, escr_sdram_wr, escr_sdram_rd, escr_sdr_rd, sdr_idle, sdr_rfsh)
variable st 	: std_logic_vector(1 downto 0);
begin
	if clk_sdr'event and clk_sdr = '1' then
		case st is
			when "00" =>
--				if mreq_n_i = '0' and wr_n_i = '0' then sdr_wr <= '1'; st := "01"; end if;
--				if mreq_n_i = '0' and rd_n_i = '0' then sdr_rd <= '1'; st := "01";  end if;
--				if escr_sdram_wr = '1' then sdr_wr <= '1'; st := "01"; end if;
--				if (escr_sdr_rd = '1' and sdr_wr = '0') then sdr_rd <= '1'; st := "01";  end if;
				if (escr_sdram_wr = '1') then sdr_wr <= '1'; st := "01"; end if; --запись в sdram только от компьютера
				if ((escr_sdram_rd = '1' or escr_sdr_rd = '1') and (sdr_wr = '0')) then sdr_rd <= '1'; st := "01";  end if;--чтение sdram только от компьютера или от видеоадаптера				
				if rfsh_n_i = '0' then sdr_rfsh <= '1'; st := "01"; end if;--тут не понятно
			when "01" =>
				if sdr_idle = '0' then sdr_wr <= '0'; sdr_rd <= '0'; sdr_rfsh <= '0'; st := "10"; end if;--когда память не свободна, нельзя читать/писать, регенерировать
			when "10" =>
				if sdr_idle = '1' and (mreq_n_i = '1' or rfsh_n_i = '1') then st := "00"; end if;--когда памяять свободна, нет чтения/записи, нет регенерации, тогда режим 00
			when others => null;
		end case;
	end if;
end process;

-------------------------------------------------------------------------------
-- Clock
process (clk_bus)
begin
	if clk_bus'event and clk_bus = '0' then
		ena_cnt <= ena_cnt + 1;
	end if;
end process;

ena_1_75mhz <= ena_cnt(5) and ena_cnt(4) and ena_cnt(3) and ena_cnt(2) and ena_cnt(1) and ena_cnt(0);
--ena_0_4375mhz <= ena_cnt(7) and ena_cnt(6) and ena_cnt(5) and ena_cnt(4) and ena_cnt(3) and ena_cnt(2) and ena_cnt(1) and ena_cnt(0);
	
--areset <= not reset_n_i;	-- глобальный сброс

-------------------------------------------------------------------------------
-- Video
vram_scr <= '1' when (ram_addr = "00001110") else '0'; --Если видео страница 7, то одна половника из 16к, иначе другая
vram_wr  <= '1' when (mreq_n_i = '0' and wr_n_i = '0' and (ram_addr = "00001010" or ram_addr = "00001110")) else '0';

-------------------------------------------------------------------------------
-- Определяем когда идёт запись в видеостраницу (адрес <#4000 и включена страница видео esqr)
-- ESCR Video
escr_sdram_wr  <= '1' when (mreq_n_i = '0' and wr_n_i = '0' and a_i(15 downto 14) = "00" and escr_port_00(4) ='1' and escr_port_00(5) ='1') else '0';
escr_sdram_rd  <= '1' when (mreq_n_i = '0' and rd_n_i = '0' and a_i(15 downto 14) = "00" and escr_port_00(4) ='1' and escr_port_00(5) ='1') else '0';
escr_sdram_scr <= '1' when (escr_sdram_wr = '1' or escr_sdram_rd ='1') else '0'; --флаг что обращение к видеостранице

escr_vram_wr  <= '1' when (mreq_n_i = '0' and wr_n_i = '0' and a_i(15 downto 14) = "00" and escr_port_00(4) ='1' and escr_port_00(5) ='0') else '0';
escr_vram_rd  <= '1' when (mreq_n_i = '0' and rd_n_i = '0' and a_i(15 downto 14) = "00" and escr_port_00(4) ='1' and escr_port_00(5) ='0') else '0';
escr_vram_scr <= '1' when (escr_vram_wr = '1' or escr_vram_rd ='1') else '0'; --флаг что обращение к видеостранице
--ram_addr_high <= ("001" & a_i(13)) when (escr_sdram_scr ='1') else "0000"; --выбираем верхнюю часть памяти для escr не оптимально, с учётом что сегменты divMMC половинками 8+8кб
--видео память escr начинается с адреса "001x xxxxxxxx xxxxxxxxxxxxx"(всего памяти 25 бит, 32 Мб)
--все остальные устройства с адреса "0000 xxxxxxxx xxxxxxxxxxxxx"
sdram_addr_full <= ("001" & escr_port_01(7 downto 0) & a_i(13 downto 0)) when (escr_sdram_scr  = '1') else escr_vga_addr; --тут полный адрес в памяти sdram
vram_escr_addr_rd_full <= (escr_port_02(1 downto 0) & a_i(12 downto 0)) when (escr_vram_scr  = '1') else vram_escr_addr_rd; --тут полный адрес в памяти vram

--sdram_addr_full <= ("001" & escr_port_01(7 downto 0) & a_i(13 downto 0)) when (escr_sdram_scr  = '1') else ("0000" & ram_addr & a_i(12 downto 0)); --тут полный адрес в памяти
-------------------------------------------------------------------------------
---- SD DIVMMC/Z-Controller/SPIFLASH
--SD_NCS	<= divmmc_ncs when kb_fn(6) = '1' else zc_ncs;
--DCLK	<= divmmc_sclk when kb_fn(6) = '1' else zc_sclk;
--ASDO	<= divmmc_mosi when kb_fn(6) = '1' else zc_mosi;
--NCSO	<= '1';

-------------------------------------------------------------------------------
-- SAA1099
saa_wr_n <= '0' when (iorq_n_i = '0' and wr_n_i = '0' and a_i(7 downto 0) = "11111111" and trdos = '0') else '1';

-------------------------------------------------------------------------------
-- Регистры
process (reset_n_i, clk_bus, a_i, port_7ffd_reg, wr_n_i, d_i, iorq_n_i, trdos, escr_wr)
begin
	if (reset_n_i = '1') then
		if (escr_wr = '1' and a_i(15 downto 8) = X"00") then escr_port_00 <= d_i; end if;	
		if (escr_wr = '1' and a_i(15 downto 8) = X"01") then escr_port_01 <= d_i; end if;
		if (escr_wr = '1' and a_i(15 downto 8) = X"02") then escr_port_02 <= d_i; end if;
		if (escr_wr = '1' and a_i(15 downto 8) = X"03") then escr_port_03 <= d_i; end if;
		if (escr_wr = '1' and a_i(15 downto 8) = X"04") then escr_port_04 <= d_i; end if;
		if (escr_wr = '1' and a_i(15 downto 8) = X"05") then escr_port_05 <= d_i; end if;

		if (escr_wr = '1' and a_i(15 downto 8) = X"10") then escr_port_10 <= d_i; end if;	
		if (escr_wr = '1' and a_i(15 downto 8) = X"11") then escr_port_11 <= d_i; end if;		
		if (escr_wr = '1' and a_i(15 downto 8) = X"12") then escr_port_12 <= d_i; end if;	
		if (escr_wr = '1' and a_i(15 downto 8) = X"13") then escr_port_13 <= d_i; end if;	
		if (escr_wr = '1' and a_i(15 downto 8) = X"14") then escr_port_14 <= d_i; end if;	
		if (escr_wr = '1' and a_i(15 downto 8) = X"15") then escr_port_15 <= d_i; end if;	
		if (escr_wr = '1' and a_i(15 downto 8) = X"16") then escr_port_16 <= d_i; end if;	
		if (escr_wr = '1' and a_i(15 downto 8) = X"17") then escr_port_17 <= d_i; end if;	
		if (escr_wr = '1' and a_i(15 downto 8) = X"18") then escr_port_18 <= d_i; end if;	
		if (escr_wr = '1' and a_i(15 downto 8) = X"19") then escr_port_19 <= d_i; end if;	
		if (escr_wr = '1' and a_i(15 downto 8) = X"1a") then escr_port_1a <= d_i; end if;	
		if (escr_wr = '1' and a_i(15 downto 8) = X"1b") then escr_port_1b <= d_i; end if;	
		if (escr_wr = '1' and a_i(15 downto 8) = X"1c") then escr_port_1c <= d_i; end if;	
		if (escr_wr = '1' and a_i(15 downto 8) = X"1d") then escr_port_1d <= d_i; end if;	
		if (escr_wr = '1' and a_i(15 downto 8) = X"1e") then escr_port_1e <= d_i; end if;	
		if (escr_wr = '1' and a_i(15 downto 8) = X"1f") then escr_port_1f <= d_i; end if;	
	
	end if;
	if (reset_n_i = '0') then
		port_7ffd_reg <= (others => '0');
		trdos <= '0';
		escr_port_00 <= X"00"; --при сбросе обнулить
		escr_port_01 <= X"00"; --при сбросе обнулить
		escr_port_02 <= X"00"; --при сбросе обнулить
		escr_port_03 <= X"00"; --при сбросе обнулить
		escr_port_04 <= X"00"; --при сбросе обнулить
		escr_port_05 <= X"00"; --при сбросе обнулить
		
		escr_port_10 <= "00000000"; --при сбросе цвет
		escr_port_11 <= "00000001"; --при сбросе цвет
		escr_port_12 <= "00000010"; --при сбросе цвет
		escr_port_13 <= "00000011"; --при сбросе цвет
		escr_port_14 <= "00000100"; --при сбросе цвет
		escr_port_15 <= "00000101"; --при сбросе цвет
		escr_port_16 <= "00000110"; --при сбросе цвет
		escr_port_17 <= "00000111"; --при сбросе цвет
		escr_port_18 <= "00001000"; --при сбросе цвет
		escr_port_19 <= "00001001"; --при сбросе цвет
		escr_port_1a <= "00001011"; --при сбросе цвет
		escr_port_1b <= "00001100"; --при сбросе цвет
		escr_port_1c <= "00001101"; --при сбросе цвет
		escr_port_1d <= "00001110"; --при сбросе цвет
		escr_port_1e <= "00001110"; --при сбросе цвет
		escr_port_1f <= "00001111"; --при сбросе цвет
		
	elsif (clk_bus'event and clk_bus = '1') then
		if (iorq_n_i = '0' and wr_n_i = '0' and a_i = X"7FFD" and port_7ffd_reg(5) = '0') then port_7ffd_reg <= d_i; end if;	-- D7-D6:не используются; D5:1=запрещение расширенной памяти (48K защёлка); D4=номер страницы ПЗУ(0-BASIC128, 1-BASIC48); D3=выбор отображаемой видеостраницы(0-страница в банке 5, 1 - в банке 7); D2-D0=номер страницы ОЗУ подключенной в верхние 16 КБ памяти (с адреса #C000)
		if (a_i(15 downto 8) = X"3D" and m1_n_i = '0' and mreq_n_i = '0') then
			trdos <= '1';
		elsif (a_i(15 downto 14) /= "00" and m1_n_i = '0' and mreq_n_i = '0') then
			trdos <= '0';

--		if (a_i(7 downto 0) = escr_port_addr_low and wr_n_i = '0' and iorq_n_i = '0' and a_i(15 downto 8) = X"00")	then escr_port_00 <= d_i; end if;
--		if (a_i(7 downto 0) = escr_port_addr_low and wr_n_i = '0' and iorq_n_i = '0' and a_i(15 downto 8) = X"01")	then escr_port_01 <= d_i; end if;
----		if (escr_rd = '1' and a_i(15 downto 8) = X"00") then BUS_D <= escr_port_00; end if;	
--		if (escr_rd = '1' and a_i(15 downto 8) = X"01") then BUS_D <= escr_port_01; end if;	
		end if;
	end if;
	
	
--	if (a_i(15 downto 8) = X"00" and escr_wr = '1' and reset_n_i = '1') then
--		escr_port_00 <= d_i; -- Скопировать значение порта 00
--	else 
--		if reset_n_i = '0' then
--			escr_port_00 <= X"00";
--		end if;
--	end if;
--
--
--	if (a_i(15 downto 8) = X"01" and escr_wr = '1' and reset_n_i = '1') then
--		escr_port_01 <= d_i;	-- Скопировать значение порта 01
--	else
--		if reset_n_i = '0' then
--			escr_port_01 <= X"00";
--		end if;
--	end if;
		
--escr_port_01 <= d_i when (a_i(15 downto 8) = X"01" and escr_wr = '1' and reset_n_i = '1');	-- Скопировать значение порта 01	
	
end process;

process (clk_bus, a_i, port_xxfe_reg, wr_n_i, d_i, iorq_n_i)
begin
	if (clk_bus'event and clk_bus = '1') then                  
		if (iorq_n_i = '0' and wr_n_i = '0' and a_i(7 downto 0) = X"FE") then port_xxfe_reg <= d_i; end if;	-- D7-D5=не используются; D4=бипер; D3=MIC; D2-D0=цвет бордюра
	end if;
end process;

------------------------------------------------------------------------------
-- Селектор
selector <=	
--		X"01" when (mreq_n_i = '0' and rd_n_i = '0' and a_i(15 downto 13) = "000" and (divmmc_amap or divmmc_e3reg(7)) /= '0' and kb_fn(6) = '1') else	-- DivMMC ESXDOS ROM #0000-#1FFF
--		X"02" when (mreq_n_i = '0' and rd_n_i = '0' and a_i(15 downto 13) = "001" and (divmmc_amap or divmmc_e3reg(7)) /= '0' and kb_fn(6) = '1') else	-- DivMMC ESXDOS RAM #2000-#3FFF
--
--		X"00" when (mreq_n_i = '0' and rd_n_i = '0' and a_i(15 downto 14) = "00" and kb_fn(5) = '1') else						-- ROM #0000-#3FFF
----		-- Ports
--		X"03" when (iorq_n_i = '0' and rd_n_i = '0' and a_i(7 downto 0) = X"FE" and kb_fn(7) = '1') else							-- Read port #xxFE Keyboard
--		X"04" when (iorq_n_i = '0' and rd_n_i = '0' and a_i(7 downto 0) = X"EB" and kb_fn(6) = '1') else							-- DivMMC ESXDOS port
--		X"05" when (iorq_n_i = '0' and rd_n_i = '0' and a_i = X"FFFD" and ssg_sel = '0') else								-- TurboSound SSG0
--		X"06" when (iorq_n_i = '0' and rd_n_i = '0' and a_i = X"FFFD" and ssg_sel = '1') else								-- TurboSound SSG1
--		X"07" when (iorq_n_i = '0' and rd_n_i = '0' and a_i(7 downto 6) = "01" and a_i(4 downto 0) = "10111" and kb_fn(6) = '0') else 			-- Z-Controller
--		X"08" when (iorq_n_i = '0' and rd_n_i = '0' and a_i = X"FADF") else										-- Mouse0 port key, z
--		X"09" when (iorq_n_i = '0' and rd_n_i = '0' and a_i = X"FBDF") else										-- Mouse0 port x
--		X"0A" when (iorq_n_i = '0' and rd_n_i = '0' and a_i = X"FFDF") else										-- Mouse0 port y
--		X"0B" when (iorq_n_i = '0' and rd_n_i = '0' and a_i(15) = '0' and a_i(10) = '0' and a_i(8) = '0' and a_i(7 downto 0) = x"DF") else		-- Mouse1 port key, z
--		X"0C" when (iorq_n_i = '0' and rd_n_i = '0' and a_i(15) = '0' and a_i(10) = '0' and a_i(8) = '1' and a_i(7 downto 0) = x"DF") else		-- Mouse1 port x
--		X"0D" when (iorq_n_i = '0' and rd_n_i = '0' and a_i(15) = '0' and a_i(10) = '1' and a_i(8) = '1' and a_i(7 downto 0) = x"DF") else		-- Mouse1 port y
--		X"0E" when (iorq_n_i = '0' and rd_n_i = '0' and a_i = X"7FFD") else										-- Read port #7FFD
--		X"0F" when (iorq_n_i = '0' and rd_n_i = '0' and a_i(7 downto 5) = "100" and a_i(3 downto 0) = "1100") else					-- Read port I2C


		X"00" when escr_vram_rd = '1' else					-- Read vram ESCR
		X"01" when escr_sdram_rd = '1' else					-- Read SDRAM ESCR
		
		X"05" when (escr_rd = '1' and a_i(15 downto 8) = X"00") else					-- Read port ESCR
		X"06" when (escr_rd = '1' and a_i(15 downto 8) = X"01") else					-- Read port ESCR
		X"07" when (escr_rd = '1' and a_i(15 downto 8) = X"02") else					-- Read port ESCR
		X"08" when (escr_rd = '1' and a_i(15 downto 8) = X"03") else					-- Read port ESCR
		X"09" when (escr_rd = '1' and a_i(15 downto 8) = X"04") else					-- Read port ESCR
		X"0a" when (escr_rd = '1' and a_i(15 downto 8) = X"05") else					-- Read port ESCR

		
		X"10" when (escr_rd = '1' and a_i(15 downto 8) = X"10") else					-- Read port ESCR		
		X"11" when (escr_rd = '1' and a_i(15 downto 8) = X"11") else					-- Read port ESCR		
		X"12" when (escr_rd = '1' and a_i(15 downto 8) = X"12") else					-- Read port ESCR		
		X"13" when (escr_rd = '1' and a_i(15 downto 8) = X"13") else					-- Read port ESCR		
		X"14" when (escr_rd = '1' and a_i(15 downto 8) = X"14") else					-- Read port ESCR		
		X"15" when (escr_rd = '1' and a_i(15 downto 8) = X"15") else					-- Read port ESCR		
		X"16" when (escr_rd = '1' and a_i(15 downto 8) = X"16") else					-- Read port ESCR		
		X"17" when (escr_rd = '1' and a_i(15 downto 8) = X"17") else					-- Read port ESCR		
		X"18" when (escr_rd = '1' and a_i(15 downto 8) = X"18") else					-- Read port ESCR		
		X"19" when (escr_rd = '1' and a_i(15 downto 8) = X"19") else					-- Read port ESCR		
		X"1a" when (escr_rd = '1' and a_i(15 downto 8) = X"1a") else					-- Read port ESCR		
		X"1b" when (escr_rd = '1' and a_i(15 downto 8) = X"1b") else					-- Read port ESCR		
		X"1c" when (escr_rd = '1' and a_i(15 downto 8) = X"1c") else					-- Read port ESCR		
		X"1d" when (escr_rd = '1' and a_i(15 downto 8) = X"1d") else					-- Read port ESCR		
		X"1e" when (escr_rd = '1' and a_i(15 downto 8) = X"1e") else					-- Read port ESCR		
		X"1f" when (escr_rd = '1' and a_i(15 downto 8) = X"1f") else					-- Read port ESCR		
		
		(others => '1');

process (selector, rom1_do, rom_do, divmmc_do, sdr_do, ssg0_do_bus, ssg1_do_bus, zc_do_bus, ms0_z, ms0_b, ms0_x, ms0_y, ms1_z, ms1_b, ms1_x, ms1_y, port_7ffd_reg, kb_do_bus, escr_do_bus, escr_port_00, escr_port_01, escr_port_02, escr_port_03, escr_port_04, escr_port_05, escr_port_10, escr_port_11, escr_port_12, escr_port_13, escr_port_14, escr_port_15, escr_port_16, escr_port_17, escr_port_18, escr_port_19, escr_port_1a, escr_port_1b, escr_port_1c, escr_port_1d, escr_port_1e, escr_port_1f, vga_di_escr)
begin
	case selector is
--		when X"00" => BUS_D <= rom1_do;			-- ROM
--		when X"01" => BUS_D <= rom_do;			-- ROM DivMMC ESXDOS
--		when X"02" => BUS_D <= sdr_do;			-- RAM DivMMC ESXDOS
----		-- Ports
--		when X"03" => BUS_D <= "111" & kb_do_bus;	-- Read port #xxFE Keyboard
--		when X"04" => BUS_D <= divmmc_do;		-- DivMMC ESXDOS port
--		when X"05" => BUS_D <= ssg0_do_bus;		-- TurboSound SSG0
--		when X"06" => BUS_D <= ssg1_do_bus;		-- TurboSound SSG1
--		when X"07" => BUS_D <= zc_do_bus;		-- Z-Controller
--		when X"08" => BUS_D <= ms0_z(3 downto 0) & '1' & not ms0_b(2) & not ms0_b(0) & not ms0_b(1);		-- Mouse0 port key, z
--		when X"09" => BUS_D <= ms0_x;			-- Mouse0 port x
--		when X"0A" => BUS_D <= not ms0_y;		-- Mouse0 port y
--		when X"0B" => BUS_D <= ms1_z(3 downto 0) & '1' & not ms1_b(2) & not ms1_b(0) & not ms1_b(1);		-- Mouse1 port key, z
--		when X"0C" => BUS_D <= ms1_x;			-- Mouse1 port x
--		when X"0D" => BUS_D <= not ms1_y;		-- Mouse1 port y
--		when X"0E" => BUS_D <= port_7ffd_reg;		-- Read port #7FFD
--		when X"0F" => BUS_D <= i2c_do_bus;		-- I2C
		when X"00" => BUS_D <= vga_di_escr; -- ESCR чтение видео памяти vram
		when X"01" => BUS_D <= sdr_do; -- ESCR чтение видео памяти sdram
		
		when X"05" => BUS_D <= escr_port_00; -- ESCR чтение порта
		when X"06" => BUS_D <= escr_port_01; -- ESCR чтение порта
		when X"07" => BUS_D <= escr_port_02; -- ESCR чтение порта
		when X"08" => BUS_D <= escr_port_03; -- ESCR чтение порта
		when X"09" => BUS_D <= escr_port_04; -- ESCR чтение порта
		when X"0a" => BUS_D <= escr_port_05; -- ESCR чтение порта

		when X"10" => BUS_D <= escr_port_10; -- ESCR чтение порта
		when X"11" => BUS_D <= escr_port_11; -- ESCR чтение порта
		when X"12" => BUS_D <= escr_port_12; -- ESCR чтение порта
		when X"13" => BUS_D <= escr_port_13; -- ESCR чтение порта
		when X"14" => BUS_D <= escr_port_14; -- ESCR чтение порта
		when X"15" => BUS_D <= escr_port_15; -- ESCR чтение порта
		when X"16" => BUS_D <= escr_port_16; -- ESCR чтение порта
		when X"17" => BUS_D <= escr_port_17; -- ESCR чтение порта
		when X"18" => BUS_D <= escr_port_18; -- ESCR чтение порта
		when X"19" => BUS_D <= escr_port_19; -- ESCR чтение порта
		when X"1a" => BUS_D <= escr_port_1a; -- ESCR чтение порта
		when X"1b" => BUS_D <= escr_port_1b; -- ESCR чтение порта
		when X"1c" => BUS_D <= escr_port_1c; -- ESCR чтение порта
		when X"1d" => BUS_D <= escr_port_1d; -- ESCR чтение порта
		when X"1e" => BUS_D <= escr_port_1e; -- ESCR чтение порта
		when X"1f" => BUS_D <= escr_port_1f; -- ESCR чтение порта

		
		when others => BUS_D <= (others => 'Z');
	end case;
end process;


BUS_NIORQGE	<= '1' when (selector(1) = '1' or selector = X"05" or selector = X"06" or selector = X"07" or selector = X"08" or selector = X"09" or selector = X"0a") else '0';	-- 1=блокируем порта в/в на шине Спектрума
BUS_NROMOE	<= '1' when (selector = X"00" or selector = X"01") else '0';			-- 1=блокируем ПЗУ Спектрума
BUF_DIR(1)	<= '1' when (selector = X"00" or selector = X"01"  or selector = X"05" or selector = X"06" or selector = X"07"  or selector = X"08"  or selector = X"09"  or selector = X"0a" or selector = X"10" or selector = X"11" or selector = X"12" or selector = X"13"  or selector = X"14" or selector = X"15" or selector = X"16" or selector = X"17" or selector = X"18" or selector = X"19" or selector = X"1a" or selector = X"1b" or selector = X"1c" or selector = X"1d" or selector = X"1e" or selector = X"1f") else '0';		-- 1=данные от FPGA, 0=данные к FPGA


-- Выбор области памяти
mux <= ((divmmc_amap or divmmc_e3reg(7)) and kb_fn(6)) & a_i(15 downto 13); -- 4 бита переменная

process (mux, port_7ffd_reg, ram_addr, divmmc_e3reg)
begin
	case mux is
		when "0000"|"0001" => ram_addr <= "10000001"; -- реальный адрес в памяти до 103FFF (до 1064959 dec), выше будет escr
		when        "1000" => ram_addr <= "10000000";					-- ESXDOS ROM 0000-1FFF
		when        "1001" => ram_addr <= "01" & divmmc_e3reg(5 downto 0);		-- ESXDOS RAM 2000-3FFF
		when "0010"|"1010" => ram_addr <= "00001010";					-- Seg1 RAM 4000-5FFF
		when "0011"|"1011" => ram_addr <= "00001011";					-- Seg1 RAM 6000-7FFF
		when "0100"|"1100" => ram_addr <= "00000100";					-- Seg2 RAM 8000-9FFF
		when "0101"|"1101" => ram_addr <= "00000101";					-- Seg2 RAM A000-BFFF
		when "0110"|"1110" => ram_addr <= "0000" & port_7ffd_reg(2 downto 0) & '0';	-- Seg3 RAM C000-DFFF
		when "0111"|"1111" => ram_addr <= "0000" & port_7ffd_reg(2 downto 0) & '1';	-- Seg3 RAM E000-FFFF
		when others => null;
	end case;
end process;

-------------------------------------------------------------------------------
-- Audio
beeper	<= (others => port_xxfe_reg(4));
audio_l	<= ("000" & beeper & "00000") + ("000" & ssg0_a & "00000") + ("000" & ssg0_b & "00000") + ("000" & ssg1_a & "00000") + ("000" & ssg1_b & "00000") + ("000" & covox_a & "00000") + ("000" & covox_b & "00000") + ("000" & saa_out_l & "00000");
audio_r	<= ("000" & beeper & "00000") + ("000" & ssg0_c & "00000") + ("000" & ssg0_b & "00000") + ("000" & ssg1_c & "00000") + ("000" & ssg1_b & "00000") + ("000" & covox_c & "00000") + ("000" & covox_d & "00000") + ("000" & saa_out_r & "00000");

-------------------------------------------------------------------------------
-- ZX-BUS
BUS_NINT	<= '1';
BUS_NWAIT	<= '1';
BUS_NBUSRQ	<= '1';
BUF_DIR(0)	<= '0';
BUS_A		<= (others => 'Z');
BUS_NMREQ	<= 'Z';
BUS_NIORQ	<= 'Z';
BUS_NRD		<= 'Z';
BUS_NWR		<= 'Z';
BUS_NM1		<= 'Z';
BUS_NRFSH	<= 'Z';

process (clk_bus) --тут каждый такт шины считываются значения шины во внутренние регистры
begin
	if clk_bus'event and clk_bus = '1' then
		reg_mreq_n_i	<= BUS_NMREQ;
		reg_iorq_n_i	<= BUS_NIORQ;
		reg_rd_n_i	<= BUS_NRD;
		reg_wr_n_i	<= BUS_NWR;
		reg_a_i		<= BUS_A;
		reg_d_i		<= BUS_D;
		reg_reset_n_i	<= BUF_NRESET;
		reg_m1_n_i	<= BUS_NM1;
		reg_rfsh_n_i	<= BUS_NRFSH;
		
		mreq_n_i	<= reg_mreq_n_i;
		iorq_n_i	<= reg_iorq_n_i;
		rd_n_i		<= reg_rd_n_i;
		wr_n_i		<= reg_wr_n_i;
		a_i		<= reg_a_i;
		d_i		<= reg_d_i;
		reset_n_i	<= reg_reset_n_i;
		m1_n_i		<= reg_m1_n_i;
		rfsh_n_i	<= reg_rfsh_n_i;
	end if;
end process;
		
end rtl;

