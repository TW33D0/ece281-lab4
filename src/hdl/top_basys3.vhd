--+----------------------------------------------------------------------------
--| 
--| COPYRIGHT 2018 United States Air Force Academy All rights reserved.
--| 
--| United States Air Force Academy     __  _______ ___    _________ 
--| Dept of Electrical &               / / / / ___//   |  / ____/   |
--| Computer Engineering              / / / /\__ \/ /| | / /_  / /| |
--| 2354 Fairchild Drive Ste 2F6     / /_/ /___/ / ___ |/ __/ / ___ |
--| USAF Academy, CO 80840           \____//____/_/  |_/_/   /_/  |_|
--| 
--| ---------------------------------------------------------------------------
--|
--| FILENAME      : top_basys3.vhd
--| AUTHOR(S)     : Capt Phillip Warner, Capt Dan Johnson, C3C Ty Hubert
--| CREATED       : 3/9/2018  Modified by C3C Ty Hubert (04/05/2024)
--| DESCRIPTION   : This file implements the top level module for a BASYS 3 to 
--|					drive the Lab 4 Design Project (Advanced Elevator Controller).
--|
--|					Inputs: clk       --> 100 MHz clock from FPGA
--|							btnL      --> Rst Clk
--|							btnR      --> Rst FSM
--|							btnU      --> Rst Master
--|							btnC      --> GO (request floor)
--|							sw(15:12) --> Passenger location (floor select bits)
--| 						sw(3:0)   --> Desired location (floor select bits)
--| 						 - Minumum FUNCTIONALITY ONLY: sw(1) --> up_down, sw(0) --> stop
--|							 
--|					Outputs: led --> indicates elevator movement with sweeping pattern (additional functionality)
--|							   - led(10) --> led(15) = MOVING UP
--|							   - led(5)  --> led(0)  = MOVING DOWN
--|							   - ALL OFF		     = NOT MOVING
--|							 an(3:0)    --> seven-segment display anode active-low enable (AN3 ... AN0)
--|							 seg(6:0)	--> seven-segment display cathodes (CG ... CA.  DP unused)
--|
--| DOCUMENTATION : None
--|
--+----------------------------------------------------------------------------
--|
--| REQUIRED FILES :
--|
--|    Libraries : ieee
--|    Packages  : std_logic_1164, numeric_std
--|    Files     : MooreElevatorController.vhd, clock_divider.vhd, sevenSegDecoder.vhd
--|				   thunderbird_fsm.vhd, sevenSegDecoder, TDM4.vhd, OTHERS???
--|
--+----------------------------------------------------------------------------
--|
--| NAMING CONVENSIONS :
--|
--|    xb_<port name>           = off-chip bidirectional port ( _pads file )
--|    xi_<port name>           = off-chip input port         ( _pads file )
--|    xo_<port name>           = off-chip output port        ( _pads file )
--|    b_<port name>            = on-chip bidirectional port
--|    i_<port name>            = on-chip input port
--|    o_<port name>            = on-chip output port
--|    c_<signal name>          = combinatorial signal
--|    f_<signal name>          = synchronous signal
--|    ff_<signal name>         = pipeline stage (ff_, fff_, etc.)
--|    <signal name>_n          = active low signal
--|    w_<signal name>          = top level wiring signal
--|    g_<generic name>         = generic
--|    k_<constant name>        = constant
--|    v_<variable name>        = variable
--|    sm_<state machine type>  = state machine type definition
--|    s_<signal name>          = state name
--|
--+----------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

-- Lab 4
entity top_basys3 is
    port(
        -- inputs
        clk     :   in std_logic; -- native 100MHz FPGA clock
        sw      :   in std_logic_vector(15 downto 0);
        btnU    :   in std_logic; -- master_reset
        btnL    :   in std_logic; -- clk_reset
        btnR    :   in std_logic; -- fsm_reset
        
        -- outputs
        led :   out std_logic_vector(15 downto 0);
        -- 7-segment display segments (active-low cathodes)
        seg :   out std_logic_vector(6 downto 0);
        -- 7-segment display active-low enables (anodes)
        an  :   out std_logic_vector(3 downto 0)
    );
end top_basys3;

architecture top_basys3_arch of top_basys3 is 
  
-- Declare components
    --Declare elevator controller component
component elevator_controller_fsm is
    port( i_clk     : in  std_logic;
          i_reset   : in  std_logic;
          i_stop    : in  std_logic;
          i_up_down : in  std_logic;
          o_floor   : out std_logic_vector (3 downto 0)           
    );
end component elevator_controller_fsm;

    -- Declare clock_divider component
component clock_divider is
    generic ( constant k_DIV : natural := 2	);
	port ( 	i_clk    : in std_logic;           -- Basys3 clock
			i_reset  : in std_logic;		   -- asynchronous
			o_clk    : out std_logic		   -- divided (slow) clock
	);
end component clock_divider;

    -- Declare sevenSegDecoder component
component sevenSegDecoder is
    port ( i_D : in std_logic_vector (3 downto 0);
           o_S : out std_logic_vector (6 downto 0)
    );
end component sevenSegDecoder;

-- Declare Signals
signal w_clk : std_logic;   -- signal from clock to led and elevator controller
signal w_floor : std_logic_vector (3 downto 0); -- signal from elevator controller to sevenSegmentDecoder

begin
	-- PORT MAPS ----------------------------------------
        -- port map for elevator controller
    elevator_controller_fsm_arch: elevator_controller_fsm
    port map(
        i_clk => w_clk,
        i_reset => (btnR or btnU),
        i_up_down => sw(1),
        i_stop => sw(0),
        o_floor => w_floor
    );
    
        -- port map for clock divider
    clkdiv_inst : clock_divider    -- clock = 100 MHz / (2*k_DIV)
    generic map(k_DIV => 25000000) -- k_DIV = 50 MHz / clock
	port map(                      -- 2 Hz clock from 100 MHz
	    i_clk => clk,
        i_reset => (btnL or btnU),
	    o_clk => w_clk
    );
	    
	    -- port map for sevenSegDecoder
	sevenSegDecoder_arch: sevenSegDecoder
	port map(
	   i_D => w_floor,
	   o_S => seg
	);
	
	
	-- CONCURRENT STATEMENTS ----------------------------
	
	-- LED 15 gets the FSM slow clock signal. The rest are grounded.
	led(14 downto 0) <= (others => '0');

	-- leave unused switches UNCONNECTED. Ignore any warnings this causes.
	
	-- wire up active-low 7SD anodes (an) as required
	an(0) <= '0';
	-- Tie any unused anodes to power ('1') to keep them off
	an(1) <= '1';
	an(2) <= '1';
	an(3) <= '1';
	
end top_basys3_arch;
