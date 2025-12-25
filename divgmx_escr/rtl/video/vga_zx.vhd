--modified by izzx
--Когда идёт запись/чтение данных из vram со стороны компьютера, расширенный экран читает память по тем же адресам, поэтому будет "снег" на экране
--Для чтения из SDRAM уходит 6T	= 71,42857142857143 ns
--Один такт HDMI 1/25.2Мгц = 39,6825396825397 ns
--Для чтения из внутренней памяти VRAM адрес нужно выставлять на такт раньше (?), успевает читать за 1Т


-------------------------------------------------------------------[21.11.2016]
-- VGA ZX-Spectum screen
-------------------------------------------------------------------------------
-- Engineer: MVV <mvvproject@gmail.com>

library IEEE; 
use IEEE.std_logic_1164.all; 
use IEEE.numeric_std.ALL;
use IEEE.std_logic_unsigned.all;

entity vga_zx is port (
	I_CLK		: in std_logic; --синхросигнал clk_vga
	I_CLKEN		: in std_logic;
	I_DATA		: in std_logic_vector(7 downto 0);--данные из памяти vram для отображения
	I_DATA_SDRAM_ESCR		: in std_logic_vector(7 downto 0);--данные из памяти sdram для отображения
	I_DATA_ESCR_OK	: in std_logic;--флаг что данные из памяти sdram для отображения готовы
	I_ESCR_PORT_00	: in std_logic_vector(7 downto 0); --значение порт
	
	I_ESCR_PORT_03	: in std_logic_vector(7 downto 0); --значение порт
	I_ESCR_PORT_04	: in std_logic_vector(7 downto 0); --значение порт
	I_ESCR_PORT_05	: in std_logic_vector(7 downto 0); --значение порт
	
	I_ESCR_PORT_10	: in std_logic_vector(7 downto 0); --значение порт
	I_ESCR_PORT_11	: in std_logic_vector(7 downto 0); --значение порт
	I_ESCR_PORT_12	: in std_logic_vector(7 downto 0); --значение порт
	I_ESCR_PORT_13	: in std_logic_vector(7 downto 0); --значение порт
	I_ESCR_PORT_14	: in std_logic_vector(7 downto 0); --значение порт
	I_ESCR_PORT_15	: in std_logic_vector(7 downto 0); --значение порт
	I_ESCR_PORT_16	: in std_logic_vector(7 downto 0); --значение порт
	I_ESCR_PORT_17	: in std_logic_vector(7 downto 0); --значение порт
	I_ESCR_PORT_18	: in std_logic_vector(7 downto 0); --значение порт
	I_ESCR_PORT_19	: in std_logic_vector(7 downto 0); --значение порт
	I_ESCR_PORT_1a	: in std_logic_vector(7 downto 0); --значение порт
	I_ESCR_PORT_1b	: in std_logic_vector(7 downto 0); --значение порт
	I_ESCR_PORT_1c	: in std_logic_vector(7 downto 0); --значение порт
	I_ESCR_PORT_1d	: in std_logic_vector(7 downto 0); --значение порт
	I_ESCR_PORT_1e	: in std_logic_vector(7 downto 0); --значение порт
	I_ESCR_PORT_1f	: in std_logic_vector(7 downto 0); --значение порт
	I_ESCR_SDRAM_SCR	: in std_logic; --флаг чтения/записи в память sdram
--	O_ADDR_VRAM_ESCR_WR	: out std_logic_vector(14 downto 0); --адрес для записи память vram_escr
	O_ADDR_VRAM_ESCR_RD	: out std_logic_vector(14 downto 0); --адрес для чтения память vram_escr
--	O_VRAM_WR_ESCR 	: out std_logic; --разрешение записи в память vram_escr
	I_DATA_VRAM_ESCR 		: in std_logic_vector(7 downto 0); --данные из памяти vram_escr
	I_CLK_SDR	: in std_logic; --синхросигнал памяти sdram
	I_BORDER	: in std_logic_vector(2 downto 0);	-- Биты D0..D2 порта xxFE определяют цвет бордюра
	I_HCNT		: in std_logic_vector(9 downto 0);
	I_VCNT		: in std_logic_vector(9 downto 0);
	I_BLANK		: in std_logic;
	I_FLASH		: in std_logic;				-- скорость мерцания курсора 1.875Гц
	O_ADDR		: out std_logic_vector(12 downto 0);--адрес чтения из памяти vram
	O_ADDR_SDRAM_ESCR		: out std_logic_vector(24 downto 0);--адрес чтения из памяти sdram
	O_SDR_RD 	: out std_logic; --разрешение чтения sdram
	O_PAPER		: out std_logic;
	O_RED		: out std_logic_vector(2 downto 0);	-- Red
	O_GREEN		: out std_logic_vector(2 downto 0);	-- Green
	O_BLUE		: out std_logic_vector(2 downto 0));	-- Blue
end entity;

architecture rtl of vga_zx is

-- ZX-Spectum screen
	constant spec_border_left	: natural :=  30;
	constant spec_screen_h		: natural := 256;
	constant spec_border_right	: natural :=  32;

	constant spec_border_top	: natural :=  24;
	constant spec_screen_v		: natural := 192;
	constant spec_border_bot	: natural :=  24;
	constant h_sync_on		: integer := 655;	-- h_visible_area + h_front_porch - 1 = 655

---------------------------------------------------------------------------------------	
	signal spec_h_count_reg		: std_logic_vector(9 downto 0);--счётчик горизонтальный
	signal spec_h_count_reg2	: std_logic_vector(9 downto 0);--счётчик горизонтальный
	signal spec_v_count_reg		: std_logic_vector(9 downto 0);--счётчик вертикальный
	signal spec_v_count_reg2		: std_logic_vector(9 downto 0);--счётчик вертикальный
	signal spec_h_count_reg_escr		: std_logic_vector(9 downto 0);--счётчик горизонтальный
	signal spec_v_count_reg_escr		: std_logic_vector(9 downto 0);--счётчик вертикальный

	signal paper			: std_logic;--флаг что сейчас рисуем бумагу
	signal pixel			: std_logic;--текущий пиксель
	signal paper1			: std_logic;
	signal vid_reg			: std_logic_vector(7 downto 0);--временный регистр данных пикселей
	signal escr_vid_reg			: std_logic_vector(7 downto 0);--временный регистр данных изо
	signal escr_vid_reg0			: std_logic_vector(7 downto 0);--временный регистр данных изо
	signal escr_vid_reg1			: std_logic_vector(7 downto 0);--временный регистр данных изо
	signal escr_vid_reg2			: std_logic_vector(7 downto 0);--временный регистр данных изо
	signal escr_vid_reg3			: std_logic_vector(7 downto 0);--временный регистр данных изо
--	signal escr_vid_reg4			: std_logic_vector(7 downto 0);--временный регистр данных изо
--	signal escr_vid_reg5			: std_logic_vector(7 downto 0);--временный регистр данных изо
--	signal escr_vid_reg6			: std_logic_vector(7 downto 0);--временный регистр данных изо
--	signal escr_vid_reg7			: std_logic_vector(7 downto 0);--временный регистр данных изо
	signal pixel_reg		: std_logic_vector(7 downto 0);--временный регистр данных пикселей
	signal attr_reg			: std_logic_vector(7 downto 0);--временный регистр данных атрибутов
	signal vga_rgb			: std_logic_vector(8 downto 0);--временный регистр текущих цветов пикселя общий
	signal vga_rgb_zx			: std_logic_vector(8 downto 0);--временный регистр текущих цветов пикселя zx
	signal addr_reg			: std_logic_vector(12 downto 0);
	signal escr_addr_reg			: std_logic_vector(24 downto 0);--временный регистр адреса в памяти
	signal sdr_rd_reg : std_logic; --разрешение чтения sdram временный регистр
	signal addr_vram_escr_wr_reg : std_logic_vector(14 downto 0);
	signal addr_vram_escr_rd_reg : std_logic_vector(14 downto 0);
	signal vram_wr_escr_reg : std_logic;
--	signal escr_pal_index : std_logic_vector(127 downto 0); --все палитры вместе 16*8 бит
--	signal escr_vid_reg1_tmp	: natural :=0;
	
begin

process (I_CLK, I_CLKEN, I_HCNT, I_VCNT)
begin
	if (I_CLK'event and I_CLK = '1' and I_CLKEN = '1') then
		if (I_HCNT = spec_border_left * 2) then
			spec_h_count_reg <= (others => '0'); --начинаем горизонтальный отсчёт слева после бордюра
		else
			spec_h_count_reg <= spec_h_count_reg + 1; --шагнуть вправо
		end if;

		if (I_HCNT = h_sync_on) then
			if (I_VCNT = spec_border_top * 2) then
				spec_v_count_reg <= (others => '0'); --начинаем вертикальный отсчёт сверху после бордюра
			else
				spec_v_count_reg <= spec_v_count_reg + 1; --шагнуть вниз
			end if;
		end if;
		
		--счётчик для второго экрана
		if (I_HCNT = (spec_border_left * 2) - 16) then --подгонка под позицию первого пикселя, + вправо
			spec_h_count_reg2 <= ("0" & I_ESCR_PORT_03 & "0") - 16; --начинаем горизонтальный отсчёт с учётом скрола, и заранее до 0 пикселя
		else
			spec_h_count_reg2 <= spec_h_count_reg2 + 1; --шагнуть вправо
		end if;
		
		--счётчик для второго экрана
		if (I_HCNT = h_sync_on) then
			if (I_VCNT = spec_border_top * 2) then
				spec_v_count_reg2 <= "0" & I_ESCR_PORT_04 & "0"; --начинаем вертикальный отсчёт сверху с учётом скрола
			else
				if spec_v_count_reg2 >= (spec_screen_v * 2) then
						spec_v_count_reg2 <= (others => '0'); 
					else
						spec_v_count_reg2 <= spec_v_count_reg2 + 1; --шагнуть вниз
				end if;
			end if;
		end if;

		case spec_h_count_reg(3 downto 1) is --на 1 пиксель два такта. отбрасываем нулевой бит
			when "000" => --0
				pixel <= pixel_reg(6); --берём 6й бит. Почему он первый?
					
					escr_vid_reg3 <= I_DATA_VRAM_ESCR; --взять байт из памяти vram_escr

					if (I_ESCR_PORT_03(0) = '1') then --зависит от порта прокрутки какую половинку байта брать
						case escr_vid_reg0(7 downto 4) is
							when X"0" =>
								escr_vid_reg <= I_ESCR_PORT_10;
							when X"1" =>
								escr_vid_reg <= I_ESCR_PORT_11;
							when X"2" =>
								escr_vid_reg <= I_ESCR_PORT_12;
							when X"3" =>
								escr_vid_reg <= I_ESCR_PORT_13;
							when X"4" =>
								escr_vid_reg <= I_ESCR_PORT_14;
							when X"5" =>
								escr_vid_reg <= I_ESCR_PORT_15;
							when X"6" =>
								escr_vid_reg <= I_ESCR_PORT_16;
							when X"7" =>
								escr_vid_reg <= I_ESCR_PORT_17;
							when X"8" =>
								escr_vid_reg <= I_ESCR_PORT_18;
							when X"9" =>
								escr_vid_reg <= I_ESCR_PORT_19;
							when X"a" =>
								escr_vid_reg <= I_ESCR_PORT_1a;
							when X"b" =>
								escr_vid_reg <= I_ESCR_PORT_1b;
							when X"c" =>
								escr_vid_reg <= I_ESCR_PORT_1c;
							when X"d" =>
								escr_vid_reg <= I_ESCR_PORT_1d;
							when X"e" =>
								escr_vid_reg <= I_ESCR_PORT_1e;
							when X"f" =>
								escr_vid_reg <= I_ESCR_PORT_1f;
						end case;
					else
						case escr_vid_reg0(3 downto 0) is
							when X"0" =>
								escr_vid_reg <= I_ESCR_PORT_10;
							when X"1" =>
								escr_vid_reg <= I_ESCR_PORT_11;
							when X"2" =>
								escr_vid_reg <= I_ESCR_PORT_12;
							when X"3" =>
								escr_vid_reg <= I_ESCR_PORT_13;
							when X"4" =>
								escr_vid_reg <= I_ESCR_PORT_14;
							when X"5" =>
								escr_vid_reg <= I_ESCR_PORT_15;
							when X"6" =>
								escr_vid_reg <= I_ESCR_PORT_16;
							when X"7" =>
								escr_vid_reg <= I_ESCR_PORT_17;
							when X"8" =>
								escr_vid_reg <= I_ESCR_PORT_18;
							when X"9" =>
								escr_vid_reg <= I_ESCR_PORT_19;
							when X"a" =>
								escr_vid_reg <= I_ESCR_PORT_1a;
							when X"b" =>
								escr_vid_reg <= I_ESCR_PORT_1b;
							when X"c" =>
								escr_vid_reg <= I_ESCR_PORT_1c;
							when X"d" =>
								escr_vid_reg <= I_ESCR_PORT_1d;
							when X"e" =>
								escr_vid_reg <= I_ESCR_PORT_1e;
							when X"f" =>
								escr_vid_reg <= I_ESCR_PORT_1f;
						end case;					
					end if;
			
				
			when "001" => --1
				pixel <= pixel_reg(5);
				
					addr_vram_escr_rd_reg <= spec_v_count_reg2 (8 downto 1) & spec_h_count_reg2(8 downto 2); --вычислить адрес байта escr
--					escr_vid_reg7 <= I_DATA_VRAM_ESCR; --взять байт из памяти vram_escr

					if (I_ESCR_PORT_03(0) = '1') then --зависит от порта прокрутки какую половинку байта брать
						case escr_vid_reg0(3 downto 0) is --левый пиксель
							when X"0" =>
								escr_vid_reg <= I_ESCR_PORT_10;
							when X"1" =>
								escr_vid_reg <= I_ESCR_PORT_11;
							when X"2" =>
								escr_vid_reg <= I_ESCR_PORT_12;
							when X"3" =>
								escr_vid_reg <= I_ESCR_PORT_13;
							when X"4" =>
								escr_vid_reg <= I_ESCR_PORT_14;
							when X"5" =>
								escr_vid_reg <= I_ESCR_PORT_15;
							when X"6" =>
								escr_vid_reg <= I_ESCR_PORT_16;
							when X"7" =>
								escr_vid_reg <= I_ESCR_PORT_17;
							when X"8" =>
								escr_vid_reg <= I_ESCR_PORT_18;
							when X"9" =>
								escr_vid_reg <= I_ESCR_PORT_19;
							when X"a" =>
								escr_vid_reg <= I_ESCR_PORT_1a;
							when X"b" =>
								escr_vid_reg <= I_ESCR_PORT_1b;
							when X"c" =>
								escr_vid_reg <= I_ESCR_PORT_1c;
							when X"d" =>
								escr_vid_reg <= I_ESCR_PORT_1d;
							when X"e" =>
								escr_vid_reg <= I_ESCR_PORT_1e;
							when X"f" =>
								escr_vid_reg <= I_ESCR_PORT_1f;
						end case;
					else
						case escr_vid_reg1(7 downto 4) is --левый пиксель
							when X"0" =>
								escr_vid_reg <= I_ESCR_PORT_10;
							when X"1" =>
								escr_vid_reg <= I_ESCR_PORT_11;
							when X"2" =>
								escr_vid_reg <= I_ESCR_PORT_12;
							when X"3" =>
								escr_vid_reg <= I_ESCR_PORT_13;
							when X"4" =>
								escr_vid_reg <= I_ESCR_PORT_14;
							when X"5" =>
								escr_vid_reg <= I_ESCR_PORT_15;
							when X"6" =>
								escr_vid_reg <= I_ESCR_PORT_16;
							when X"7" =>
								escr_vid_reg <= I_ESCR_PORT_17;
							when X"8" =>
								escr_vid_reg <= I_ESCR_PORT_18;
							when X"9" =>
								escr_vid_reg <= I_ESCR_PORT_19;
							when X"a" =>
								escr_vid_reg <= I_ESCR_PORT_1a;
							when X"b" =>
								escr_vid_reg <= I_ESCR_PORT_1b;
							when X"c" =>
								escr_vid_reg <= I_ESCR_PORT_1c;
							when X"d" =>
								escr_vid_reg <= I_ESCR_PORT_1d;
							when X"e" =>
								escr_vid_reg <= I_ESCR_PORT_1e;
							when X"f" =>
								escr_vid_reg <= I_ESCR_PORT_1f;
						end case;
					end if;

			
			when "010" => --2
				pixel <= pixel_reg(4);
	
					escr_vid_reg0 <= I_DATA_VRAM_ESCR; --взять байт из памяти vram_escr
					
					if (I_ESCR_PORT_03(0) = '1') then --зависит от порта прокрутки какую половинку байта брать
						case escr_vid_reg1(7 downto 4) is --правый пиксель
							when X"0" =>
								escr_vid_reg <= I_ESCR_PORT_10;
							when X"1" =>
								escr_vid_reg <= I_ESCR_PORT_11;
							when X"2" =>
								escr_vid_reg <= I_ESCR_PORT_12;
							when X"3" =>
								escr_vid_reg <= I_ESCR_PORT_13;
							when X"4" =>
								escr_vid_reg <= I_ESCR_PORT_14;
							when X"5" =>
								escr_vid_reg <= I_ESCR_PORT_15;
							when X"6" =>
								escr_vid_reg <= I_ESCR_PORT_16;
							when X"7" =>
								escr_vid_reg <= I_ESCR_PORT_17;
							when X"8" =>
								escr_vid_reg <= I_ESCR_PORT_18;
							when X"9" =>
								escr_vid_reg <= I_ESCR_PORT_19;
							when X"a" =>
								escr_vid_reg <= I_ESCR_PORT_1a;
							when X"b" =>
								escr_vid_reg <= I_ESCR_PORT_1b;
							when X"c" =>
								escr_vid_reg <= I_ESCR_PORT_1c;
							when X"d" =>
								escr_vid_reg <= I_ESCR_PORT_1d;
							when X"e" =>
								escr_vid_reg <= I_ESCR_PORT_1e;
							when X"f" =>
								escr_vid_reg <= I_ESCR_PORT_1f;
						end case;
					else
							case escr_vid_reg1(3 downto 0) is --правый пиксель
							when X"0" =>
								escr_vid_reg <= I_ESCR_PORT_10;
							when X"1" =>
								escr_vid_reg <= I_ESCR_PORT_11;
							when X"2" =>
								escr_vid_reg <= I_ESCR_PORT_12;
							when X"3" =>
								escr_vid_reg <= I_ESCR_PORT_13;
							when X"4" =>
								escr_vid_reg <= I_ESCR_PORT_14;
							when X"5" =>
								escr_vid_reg <= I_ESCR_PORT_15;
							when X"6" =>
								escr_vid_reg <= I_ESCR_PORT_16;
							when X"7" =>
								escr_vid_reg <= I_ESCR_PORT_17;
							when X"8" =>
								escr_vid_reg <= I_ESCR_PORT_18;
							when X"9" =>
								escr_vid_reg <= I_ESCR_PORT_19;
							when X"a" =>
								escr_vid_reg <= I_ESCR_PORT_1a;
							when X"b" =>
								escr_vid_reg <= I_ESCR_PORT_1b;
							when X"c" =>
								escr_vid_reg <= I_ESCR_PORT_1c;
							when X"d" =>
								escr_vid_reg <= I_ESCR_PORT_1d;
							when X"e" =>
								escr_vid_reg <= I_ESCR_PORT_1e;
							when X"f" =>
								escr_vid_reg <= I_ESCR_PORT_1f;
						end case;
					end if;
				
				
			
			when "011" => --3
				pixel <= pixel_reg(3);
				
				
				addr_vram_escr_rd_reg <= spec_v_count_reg2 (8 downto 1) & spec_h_count_reg2(8 downto 2); --вычислить адрес байта escr

					if (I_ESCR_PORT_03(0) = '1') then --зависит от порта прокрутки какую половинку байта брать
						case escr_vid_reg1(3 downto 0) is
							when X"0" =>
								escr_vid_reg <= I_ESCR_PORT_10;
							when X"1" =>
								escr_vid_reg <= I_ESCR_PORT_11;
							when X"2" =>
								escr_vid_reg <= I_ESCR_PORT_12;
							when X"3" =>
								escr_vid_reg <= I_ESCR_PORT_13;
							when X"4" =>
								escr_vid_reg <= I_ESCR_PORT_14;
							when X"5" =>
								escr_vid_reg <= I_ESCR_PORT_15;
							when X"6" =>
								escr_vid_reg <= I_ESCR_PORT_16;
							when X"7" =>
								escr_vid_reg <= I_ESCR_PORT_17;
							when X"8" =>
								escr_vid_reg <= I_ESCR_PORT_18;
							when X"9" =>
								escr_vid_reg <= I_ESCR_PORT_19;
							when X"a" =>
								escr_vid_reg <= I_ESCR_PORT_1a;
							when X"b" =>
								escr_vid_reg <= I_ESCR_PORT_1b;
							when X"c" =>
								escr_vid_reg <= I_ESCR_PORT_1c;
							when X"d" =>
								escr_vid_reg <= I_ESCR_PORT_1d;
							when X"e" =>
								escr_vid_reg <= I_ESCR_PORT_1e;
							when X"f" =>
								escr_vid_reg <= I_ESCR_PORT_1f;
						end case;
					else
						case escr_vid_reg2(7 downto 4) is
							when X"0" =>
								escr_vid_reg <= I_ESCR_PORT_10;
							when X"1" =>
								escr_vid_reg <= I_ESCR_PORT_11;
							when X"2" =>
								escr_vid_reg <= I_ESCR_PORT_12;
							when X"3" =>
								escr_vid_reg <= I_ESCR_PORT_13;
							when X"4" =>
								escr_vid_reg <= I_ESCR_PORT_14;
							when X"5" =>
								escr_vid_reg <= I_ESCR_PORT_15;
							when X"6" =>
								escr_vid_reg <= I_ESCR_PORT_16;
							when X"7" =>
								escr_vid_reg <= I_ESCR_PORT_17;
							when X"8" =>
								escr_vid_reg <= I_ESCR_PORT_18;
							when X"9" =>
								escr_vid_reg <= I_ESCR_PORT_19;
							when X"a" =>
								escr_vid_reg <= I_ESCR_PORT_1a;
							when X"b" =>
								escr_vid_reg <= I_ESCR_PORT_1b;
							when X"c" =>
								escr_vid_reg <= I_ESCR_PORT_1c;
							when X"d" =>
								escr_vid_reg <= I_ESCR_PORT_1d;
							when X"e" =>
								escr_vid_reg <= I_ESCR_PORT_1e;
							when X"f" =>
								escr_vid_reg <= I_ESCR_PORT_1f;
						end case;
					end if;
					

			
			when "100" => --4
				pixel <= pixel_reg(2);
				addr_reg <= spec_v_count_reg(8 downto 7) & spec_v_count_reg(3 downto 1) & spec_v_count_reg(6 downto 4) & spec_h_count_reg(8 downto 4); --готовим адрес пикселя
				
					
					escr_vid_reg1 <= I_DATA_VRAM_ESCR; --взять байт из памяти vram_escr
					
					if (I_ESCR_PORT_03(0) = '1') then --зависит от порта прокрутки какую половинку байта брать
						case escr_vid_reg2(7 downto 4) is
							when X"0" =>
								escr_vid_reg <= I_ESCR_PORT_10;
							when X"1" =>
								escr_vid_reg <= I_ESCR_PORT_11;
							when X"2" =>
								escr_vid_reg <= I_ESCR_PORT_12;
							when X"3" =>
								escr_vid_reg <= I_ESCR_PORT_13;
							when X"4" =>
								escr_vid_reg <= I_ESCR_PORT_14;
							when X"5" =>
								escr_vid_reg <= I_ESCR_PORT_15;
							when X"6" =>
								escr_vid_reg <= I_ESCR_PORT_16;
							when X"7" =>
								escr_vid_reg <= I_ESCR_PORT_17;
							when X"8" =>
								escr_vid_reg <= I_ESCR_PORT_18;
							when X"9" =>
								escr_vid_reg <= I_ESCR_PORT_19;
							when X"a" =>
								escr_vid_reg <= I_ESCR_PORT_1a;
							when X"b" =>
								escr_vid_reg <= I_ESCR_PORT_1b;
							when X"c" =>
								escr_vid_reg <= I_ESCR_PORT_1c;
							when X"d" =>
								escr_vid_reg <= I_ESCR_PORT_1d;
							when X"e" =>
								escr_vid_reg <= I_ESCR_PORT_1e;
							when X"f" =>
								escr_vid_reg <= I_ESCR_PORT_1f;
						end case;
					else
						case escr_vid_reg2(3 downto 0) is
							when X"0" =>
								escr_vid_reg <= I_ESCR_PORT_10;
							when X"1" =>
								escr_vid_reg <= I_ESCR_PORT_11;
							when X"2" =>
								escr_vid_reg <= I_ESCR_PORT_12;
							when X"3" =>
								escr_vid_reg <= I_ESCR_PORT_13;
							when X"4" =>
								escr_vid_reg <= I_ESCR_PORT_14;
							when X"5" =>
								escr_vid_reg <= I_ESCR_PORT_15;
							when X"6" =>
								escr_vid_reg <= I_ESCR_PORT_16;
							when X"7" =>
								escr_vid_reg <= I_ESCR_PORT_17;
							when X"8" =>
								escr_vid_reg <= I_ESCR_PORT_18;
							when X"9" =>
								escr_vid_reg <= I_ESCR_PORT_19;
							when X"a" =>
								escr_vid_reg <= I_ESCR_PORT_1a;
							when X"b" =>
								escr_vid_reg <= I_ESCR_PORT_1b;
							when X"c" =>
								escr_vid_reg <= I_ESCR_PORT_1c;
							when X"d" =>
								escr_vid_reg <= I_ESCR_PORT_1d;
							when X"e" =>
								escr_vid_reg <= I_ESCR_PORT_1e;
							when X"f" =>
								escr_vid_reg <= I_ESCR_PORT_1f;
						end case;
					end if;
					
					
			
			when "101" => --5
				pixel <= pixel_reg(1); 
				vid_reg <= I_DATA; --берём байт пикселей zx из памяти vram
				
					
					addr_vram_escr_rd_reg <= spec_v_count_reg2 (8 downto 1) & spec_h_count_reg2(8 downto 2); --вычислить адрес байта escr

					if (I_ESCR_PORT_03(0) = '1') then --зависит от порта прокрутки какую половинку байта брать					
						case escr_vid_reg2(3 downto 0) is
							when X"0" =>
								escr_vid_reg <= I_ESCR_PORT_10;
							when X"1" =>
								escr_vid_reg <= I_ESCR_PORT_11;
							when X"2" =>
								escr_vid_reg <= I_ESCR_PORT_12;
							when X"3" =>
								escr_vid_reg <= I_ESCR_PORT_13;
							when X"4" =>
								escr_vid_reg <= I_ESCR_PORT_14;
							when X"5" =>
								escr_vid_reg <= I_ESCR_PORT_15;
							when X"6" =>
								escr_vid_reg <= I_ESCR_PORT_16;
							when X"7" =>
								escr_vid_reg <= I_ESCR_PORT_17;
							when X"8" =>
								escr_vid_reg <= I_ESCR_PORT_18;
							when X"9" =>
								escr_vid_reg <= I_ESCR_PORT_19;
							when X"a" =>
								escr_vid_reg <= I_ESCR_PORT_1a;
							when X"b" =>
								escr_vid_reg <= I_ESCR_PORT_1b;
							when X"c" =>
								escr_vid_reg <= I_ESCR_PORT_1c;
							when X"d" =>
								escr_vid_reg <= I_ESCR_PORT_1d;
							when X"e" =>
								escr_vid_reg <= I_ESCR_PORT_1e;
							when X"f" =>
								escr_vid_reg <= I_ESCR_PORT_1f;
						end case;
					else
						case escr_vid_reg3(7 downto 4) is
							when X"0" =>
								escr_vid_reg <= I_ESCR_PORT_10;
							when X"1" =>
								escr_vid_reg <= I_ESCR_PORT_11;
							when X"2" =>
								escr_vid_reg <= I_ESCR_PORT_12;
							when X"3" =>
								escr_vid_reg <= I_ESCR_PORT_13;
							when X"4" =>
								escr_vid_reg <= I_ESCR_PORT_14;
							when X"5" =>
								escr_vid_reg <= I_ESCR_PORT_15;
							when X"6" =>
								escr_vid_reg <= I_ESCR_PORT_16;
							when X"7" =>
								escr_vid_reg <= I_ESCR_PORT_17;
							when X"8" =>
								escr_vid_reg <= I_ESCR_PORT_18;
							when X"9" =>
								escr_vid_reg <= I_ESCR_PORT_19;
							when X"a" =>
								escr_vid_reg <= I_ESCR_PORT_1a;
							when X"b" =>
								escr_vid_reg <= I_ESCR_PORT_1b;
							when X"c" =>
								escr_vid_reg <= I_ESCR_PORT_1c;
							when X"d" =>
								escr_vid_reg <= I_ESCR_PORT_1d;
							when X"e" =>
								escr_vid_reg <= I_ESCR_PORT_1e;
							when X"f" =>
								escr_vid_reg <= I_ESCR_PORT_1f;
						end case;
					end if;

						
			
			when "110" => --6
				pixel <= pixel_reg(0); --правый пиксель знакоместа zx
				addr_reg <= "110" & spec_v_count_reg(8 downto 4) & spec_h_count_reg(8 downto 4); --готовим адрес атрибута?

				
					escr_vid_reg2 <= I_DATA_VRAM_ESCR; --взять байт из памяти vram_escr

					if (I_ESCR_PORT_03(0) = '1') then --зависит от порта прокрутки какую половинку байта брать
						case escr_vid_reg3(7 downto 4) is
							when X"0" =>
								escr_vid_reg <= I_ESCR_PORT_10;
							when X"1" =>
								escr_vid_reg <= I_ESCR_PORT_11;
							when X"2" =>
								escr_vid_reg <= I_ESCR_PORT_12;
							when X"3" =>
								escr_vid_reg <= I_ESCR_PORT_13;
							when X"4" =>
								escr_vid_reg <= I_ESCR_PORT_14;
							when X"5" =>
								escr_vid_reg <= I_ESCR_PORT_15;
							when X"6" =>
								escr_vid_reg <= I_ESCR_PORT_16;
							when X"7" =>
								escr_vid_reg <= I_ESCR_PORT_17;
							when X"8" =>
								escr_vid_reg <= I_ESCR_PORT_18;
							when X"9" =>
								escr_vid_reg <= I_ESCR_PORT_19;
							when X"a" =>
								escr_vid_reg <= I_ESCR_PORT_1a;
							when X"b" =>
								escr_vid_reg <= I_ESCR_PORT_1b;
							when X"c" =>
								escr_vid_reg <= I_ESCR_PORT_1c;
							when X"d" =>
								escr_vid_reg <= I_ESCR_PORT_1d;
							when X"e" =>
								escr_vid_reg <= I_ESCR_PORT_1e;
							when X"f" =>
								escr_vid_reg <= I_ESCR_PORT_1f;
						end case;
					else
						case escr_vid_reg3(3 downto 0) is
							when X"0" =>
								escr_vid_reg <= I_ESCR_PORT_10;
							when X"1" =>
								escr_vid_reg <= I_ESCR_PORT_11;
							when X"2" =>
								escr_vid_reg <= I_ESCR_PORT_12;
							when X"3" =>
								escr_vid_reg <= I_ESCR_PORT_13;
							when X"4" =>
								escr_vid_reg <= I_ESCR_PORT_14;
							when X"5" =>
								escr_vid_reg <= I_ESCR_PORT_15;
							when X"6" =>
								escr_vid_reg <= I_ESCR_PORT_16;
							when X"7" =>
								escr_vid_reg <= I_ESCR_PORT_17;
							when X"8" =>
								escr_vid_reg <= I_ESCR_PORT_18;
							when X"9" =>
								escr_vid_reg <= I_ESCR_PORT_19;
							when X"a" =>
								escr_vid_reg <= I_ESCR_PORT_1a;
							when X"b" =>
								escr_vid_reg <= I_ESCR_PORT_1b;
							when X"c" =>
								escr_vid_reg <= I_ESCR_PORT_1c;
							when X"d" =>
								escr_vid_reg <= I_ESCR_PORT_1d;
							when X"e" =>
								escr_vid_reg <= I_ESCR_PORT_1e;
							when X"f" =>
								escr_vid_reg <= I_ESCR_PORT_1f;
						end case;
					end if;
			

			
			when "111" => --7
				pixel <= vid_reg(7); --левый пиксель, тут начало
				pixel_reg <= vid_reg; --сохранить байт пикселей
				attr_reg <= I_DATA; --берём байт атрибута zx
		
				paper1 <= paper;
				
				
					addr_vram_escr_rd_reg <= spec_v_count_reg2 (8 downto 1) & spec_h_count_reg2(8 downto 2); --вычислить адрес байта escr

					if (I_ESCR_PORT_03(0) = '1') then --зависит от порта прокрутки какую половинку байта брать
						case escr_vid_reg3(3 downto 0) is
							when X"0" =>
								escr_vid_reg <= I_ESCR_PORT_10;
							when X"1" =>
								escr_vid_reg <= I_ESCR_PORT_11;
							when X"2" =>
								escr_vid_reg <= I_ESCR_PORT_12;
							when X"3" =>
								escr_vid_reg <= I_ESCR_PORT_13;
							when X"4" =>
								escr_vid_reg <= I_ESCR_PORT_14;
							when X"5" =>
								escr_vid_reg <= I_ESCR_PORT_15;
							when X"6" =>
								escr_vid_reg <= I_ESCR_PORT_16;
							when X"7" =>
								escr_vid_reg <= I_ESCR_PORT_17;
							when X"8" =>
								escr_vid_reg <= I_ESCR_PORT_18;
							when X"9" =>
								escr_vid_reg <= I_ESCR_PORT_19;
							when X"a" =>
								escr_vid_reg <= I_ESCR_PORT_1a;
							when X"b" =>
								escr_vid_reg <= I_ESCR_PORT_1b;
							when X"c" =>
								escr_vid_reg <= I_ESCR_PORT_1c;
							when X"d" =>
								escr_vid_reg <= I_ESCR_PORT_1d;
							when X"e" =>
								escr_vid_reg <= I_ESCR_PORT_1e;
							when X"f" =>
								escr_vid_reg <= I_ESCR_PORT_1f;
						end case;
					else
						case escr_vid_reg0(7 downto 4) is
							when X"0" =>
								escr_vid_reg <= I_ESCR_PORT_10;
							when X"1" =>
								escr_vid_reg <= I_ESCR_PORT_11;
							when X"2" =>
								escr_vid_reg <= I_ESCR_PORT_12;
							when X"3" =>
								escr_vid_reg <= I_ESCR_PORT_13;
							when X"4" =>
								escr_vid_reg <= I_ESCR_PORT_14;
							when X"5" =>
								escr_vid_reg <= I_ESCR_PORT_15;
							when X"6" =>
								escr_vid_reg <= I_ESCR_PORT_16;
							when X"7" =>
								escr_vid_reg <= I_ESCR_PORT_17;
							when X"8" =>
								escr_vid_reg <= I_ESCR_PORT_18;
							when X"9" =>
								escr_vid_reg <= I_ESCR_PORT_19;
							when X"a" =>
								escr_vid_reg <= I_ESCR_PORT_1a;
							when X"b" =>
								escr_vid_reg <= I_ESCR_PORT_1b;
							when X"c" =>
								escr_vid_reg <= I_ESCR_PORT_1c;
							when X"d" =>
								escr_vid_reg <= I_ESCR_PORT_1d;
							when X"e" =>
								escr_vid_reg <= I_ESCR_PORT_1e;
							when X"f" =>
								escr_vid_reg <= I_ESCR_PORT_1f;
						end case;
					end if;
					

			when others => null; --O_SDR_RD <= '0'
		end case;
	end if;
end process;

--ограничение бумаги справа и снизу. дальше бордюр
paper <= '1' when (spec_h_count_reg(9 downto 1) < spec_screen_h and spec_v_count_reg(9 downto 1) < spec_screen_v) else '0';





--цвета zx GRB биты G(2),R(1),B(0), и для бумаги G(5),R(4),B(3)
--цвет на выходе два-три бита на цвет: бит цвета + (яркость (6) and бит цвета)
vga_rgb_zx <= 	(others => '0') when (I_BLANK = '1') else
		attr_reg(4) & (attr_reg(4) and attr_reg(6)) & attr_reg(4) & attr_reg(5) & (attr_reg(5) and attr_reg(6)) & attr_reg(5) & attr_reg(3) & (attr_reg(3) and attr_reg(6)) & attr_reg(3) when paper1 = '1' and (pixel xor (I_FLASH and attr_reg(7))) = '0' else --цвет paper
		attr_reg(1) & (attr_reg(1) and attr_reg(6)) & attr_reg(1) & attr_reg(2) & (attr_reg(2) and attr_reg(6)) & attr_reg(2) & attr_reg(0) & (attr_reg(0) and attr_reg(6)) & attr_reg(0) when paper1 = '1' and (pixel xor (I_FLASH and attr_reg(7))) = '1' else --цвет ink
		I_BORDER(1) & I_BORDER(1) & I_BORDER(1) & I_BORDER(2) & I_BORDER(2) & I_BORDER(2) & I_BORDER(0) & I_BORDER(0) & I_BORDER(0); --иначе бордюр



		
--		
----кэширование строки графики из sdram во внутреннюю память vram_escr	
----начинается на бордюре слева, должно успеть до вывода на экран
--process (I_CLK, I_CLKEN, I_HCNT, I_VCNT, I_ESCR_PORT_00, I_ESCR_SDRAM_SCR,spec_h_count_reg_escr, spec_v_count_reg, escr_addr_reg)
--begin
--	if (I_CLK'event and I_CLK = '1' and I_CLKEN = '1') then --не выходим за пределы 256
--		if (I_HCNT = spec_border_left * 2) then --строка только началась (в конце предыдущей)
--			spec_h_count_reg_escr <= (others => '0'); --начинаем горизонтальный отсчёт слева в начале строки
--		else
----			spec_h_count_reg_escr <= spec_h_count_reg_escr + 1; --шагнуть вправо
--		end if;
--
--		if (I_HCNT = h_sync_on) then
--			if (I_VCNT = spec_border_top * 2) then --перед первой строкой
--				spec_v_count_reg_escr <= (others => '0'); --начинаем вертикальный отсчёт сверху после бордюра
--			else
--				spec_v_count_reg_escr <= spec_v_count_reg_escr + 1; --шагнуть вниз
--			end if;
--			
--		end if;
--		
----		if (I_HCNT = (spec_border_left * 2) + (spec_screen_h * 2)) then --строка только началась (в конце предыдущей)
----				sdr_rd_reg <= '0';--
----				vram_wr_escr_reg <= '0';
----		end if;
--
--	
--			if (I_DATA_ESCR_OK = '0' and spec_h_count_reg(0) = '0') then -- если включен доп. экран и не идёт чтение из sdram
--				escr_addr_reg <= "001000000" & spec_v_count_reg(8 downto 1) & spec_h_count_reg(8 downto 1); --вычислить адрес байта escr в sdram
--				sdr_rd_reg <= '1'; --сигнал чтение sdram
--				vram_wr_escr_reg <= '0'; --сигнал записи в vram
--			else
--				sdr_rd_reg <= '0';--
--			end if;
--	
--	
--			if (I_DATA_ESCR_OK = '1' and spec_h_count_reg(0) = '0') then --если байт готов сохраним его
--				addr_vram_escr_wr_reg <= "0000000" & spec_h_count_reg(8 downto 1);--адрес для записи в vram_escr
--				vram_wr_escr_reg <= '1'; --сигнало записи в vram_escr
--				--данные из sdram должны попасть в vram через переменную sdr_do
--						
--				spec_h_count_reg_escr <= spec_h_count_reg_escr + 1; --шагнуть вправо
----				spec_v_count_reg_escr <= spec_v_count_reg_escr + 1; --шагнуть вниз
--				sdr_rd_reg <= '0';----сигнал чтение sdram
--			else
--				vram_wr_escr_reg <= '0'; 
--			end if;
--
--	end if;
--
--end process;
--		




--наложение сверху расширенного экрана. цвет из палитры RRRGGGBB&(B1 or B0). прозрачный цвет 0
vga_rgb <= vga_rgb_zx when (escr_vid_reg = I_ESCR_PORT_05 or paper1 = '0' or I_ESCR_PORT_00(0) = '0') else 
	(escr_vid_reg(7) & escr_vid_reg(6) & escr_vid_reg(5) & escr_vid_reg(4) & escr_vid_reg(3) & escr_vid_reg(2) & escr_vid_reg(1) & escr_vid_reg(0) & (escr_vid_reg(1) or escr_vid_reg(0)));
--vga_rgb <= vga_rgb_zx when (escr_vid_reg = X"00" or paper1 = '0' or I_ESCR_PORT_00(0) = '0') else 
--	("0" & escr_vid_reg(1) & "0" & escr_vid_reg(2) & "0" & escr_vid_reg(0)) when spec_h_count_reg2 (1) = '0' else 
--	("0" & escr_vid_reg(5) & "0" & escr_vid_reg(6) & "0" & escr_vid_reg(4)) when spec_h_count_reg2 (1) = '1';

--выходные сигналы
O_ADDR_VRAM_ESCR_RD <= addr_vram_escr_rd_reg;
--O_ADDR_VRAM_ESCR_WR <= addr_vram_escr_wr_reg;
--O_VRAM_WR_ESCR <= vram_wr_escr_reg;
O_ADDR_SDRAM_ESCR	<= escr_addr_reg; --на выход адрес откуда читать байт пикселя escr	
O_SDR_RD <= sdr_rd_reg;
O_ADDR	<= addr_reg;
O_PAPER	<= paper1;
O_RED	<= vga_rgb(8 downto 6);
O_GREEN	<= vga_rgb(5 downto 3);
O_BLUE	<= vga_rgb(2 downto 0);

end architecture;