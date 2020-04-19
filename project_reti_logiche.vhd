----------------------------------------------------------------------------------
-- Company: Polimi
-- Designer: Alessandro Lisi
-- 
-- Create Date: 26.02.2020 12:22:12
-- Last Edit: 4.04.2020
-- Design Name: Progetto di Reti Logiche 2020 Workzone Encoder
-- Module Name: proj_RL_01 - Behavioral
-- Project Name: Workzone Encoder

----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity project_reti_logiche is

    Port ( i_clk : in STD_LOGIC;
           i_start : in STD_LOGIC;
           i_rst : in STD_LOGIC;
           i_data : in STD_LOGIC_VECTOR (7 downto 0);
           o_address : out STD_LOGIC_VECTOR (15 downto 0);
           o_done : out STD_LOGIC;
           o_en : out STD_LOGIC;
           o_we : out STD_LOGIC;
           o_data : out STD_LOGIC_VECTOR (7 downto 0));
           
end project_reti_logiche;

architecture Behavioral of project_reti_logiche is

    type State is (S_IDLE, S_FETCH, S_FETCH2, S_RAM_WAIT, S_COMPARE, S_OFFSET, S_COMPARE2, S_SEND_ENC, S_SEND, 
                  -- S_COMPLETE--, 
                   S_DONE, S_DONE2);
                   
    signal current_state : State;
    
    signal ram_wait_ret_state : State;
    

    signal address : std_logic_vector (7 downto 0);
    signal counter_3 : std_logic_vector (3 downto 0) := (others => '0');
    
    signal hp0, hp1, hp2, hp3 : std_logic_vector (7 downto 0) := (others => '0');
    signal cmp_wz_found : std_logic;
    signal cmp_wz_num : std_logic_vector (2 downto 0);
    signal cmp_wz_offset_one_hot : std_logic_vector(3 downto 0);

    


    
begin


algo: process (i_clk) is

       variable WZ_NUM : integer := -1;
       variable WZ_OST : integer := -1;

      begin
      
       if i_rst = '1' then
            current_state <= S_IDLE; --mi metto nello stato di IDLE
            o_done <= '0'; -- resetto i segnali di uscita
            o_en <= '0';
            o_we <= '0';
            counter_3 <= "0000";  --inizializzo contatore WZ
            cmp_wz_found <= '0';  
            --TODO altre inizializzazioni


       elsif i_clk'event and rising_edge(i_clk) then
          

       --macchina a stati
         case current_state is
         --in attesa del segnale di start
            when S_IDLE =>
               if i_start = '1' then
                  current_state <= S_FETCH;
               end if;
          --aspetta 1ck per ottenere il dato letto dalla ram  
            when S_RAM_WAIT => 
                current_state <= ram_wait_ret_state;
          --legge l'indirizzo della ram
            when S_FETCH => 
               --voglio leggere dalla memoria
               o_en <= '1';
               counter_3 <= "0000";  --inizializzo contatore WZ e i vari segnali ausiliari
               cmp_wz_found <= '0';

               --leggo l'indirizzo da codificare
               o_address <= std_logic_vector(to_unsigned( 8 , 16)); 

               ram_wait_ret_state <= S_FETCH2;
               current_state <= S_RAM_WAIT;
            when S_FETCH2 =>

               address <= i_data;
               ram_wait_ret_state <= S_COMPARE;
               current_state <= S_RAM_WAIT;

            when S_COMPARE =>
               --cicla le 7 working zone
               if counter_3 = "0000" then  --inizio
                     ram_wait_ret_state <= S_OFFSET;
                     current_state <= S_RAM_WAIT;
                     counter_3 <= counter_3 + 1;           
  --se non appartiene a nessuna WZ il contatore arriva ad 8:                           
               elsif counter_3 = "1000" then  
                    counter_3 <= "0000";
                    current_state <= S_SEND;
                    
               else --da 1 a 6, in pieno conteggio
                  counter_3 <= counter_3 + 1;
                  ram_wait_ret_state <= S_OFFSET;
                  current_state <= S_RAM_WAIT;

               end if;
             
             -------------------------------------------------------------------
             --chiedo di leggere l'indirizzo di counter
             -------------------------------------------------------------------
             o_address <= std_logic_vector(resize(unsigned(counter_3), 16)); 
             --impongo che found e i vari sotto campi siano a 0.
             cmp_wz_found <= '0';
             cmp_wz_num <= "000";
             cmp_wz_offset_one_hot <= "0000";
             
             when S_OFFSET =>   

                  
                  --calcola i 4 possibili indirizzi
                  hp0 <= i_data;
                  hp1 <= i_data + 1;
                  hp2 <= i_data + 2;
                  hp3 <= i_data + 3;
                  current_state <= S_COMPARE2;
                  --if hp0 xnor 
               
            when S_COMPARE2 =>
                                  
            --esegui i controlli: guarda se l'indirizzo matcha con WZ + 0,1,2,3
            if (hp0 = address) then
              cmp_wz_found <= '1';
              cmp_wz_num <= counter_3(2 downto 0) -1 ;
              cmp_wz_offset_one_hot <= "0001";
              current_state <= S_SEND_ENC;
            elsif (hp1 = address) then
                cmp_wz_found <= '1';
                cmp_wz_num <= counter_3(2 downto 0) -1;
                cmp_wz_offset_one_hot <= "0010";
                current_state <= S_SEND_ENC;           
            elsif (hp2 = address) then
                 cmp_wz_found <= '1';
                 cmp_wz_num <= counter_3(2 downto 0) -1;
                 cmp_wz_offset_one_hot <= "0100";
                 current_state <= S_SEND_ENC;             
            elsif (hp3 = address) then
                cmp_wz_found <= '1';
                cmp_wz_num <= counter_3(2 downto 0) -1;
                cmp_wz_offset_one_hot <= "1000";
                current_state <= S_SEND_ENC;             
            else 
                current_state <= S_COMPARE;
                cmp_wz_found <= '0'; --non ho trovato un'appartenenza ad una wz
            end if;
            
            

            --INVIO: 
            when s_send =>
                o_en <= '1'; -- voglio accedere alla ram e scriverci
                o_we <= '1';
                o_data <= address;  --indirizzo dry non modificato
                o_address <= std_logic_vector(to_unsigned( 9 , 16));
                ram_wait_ret_state <= S_DONE;
                current_state <= S_RAM_WAIT;
                
            when s_send_enc =>
                
                 o_data <= '1' & cmp_wz_num & cmp_wz_offset_one_hot;
                 o_address <= std_logic_vector(to_unsigned( 9 , 16));
                 o_we <= '1';
                 ram_wait_ret_state <= S_DONE;
                 current_state <= S_RAM_WAIT;
            --lo tolgo?     
--            when S_COMPLETE =>
--                o_en <= '1';
--                o_we <= '1';
--             ram_wait_ret_state <= S_DONE;
--             current_state <= S_RAM_WAIT;
                
          --metto done a 1 e aspetto start a 0.
            when S_DONE =>
                o_en <= '0';  --chiudo scrittura dalla ram
                o_we <= '0';
                o_done <= '1';
                if i_start = '0' then
                    current_state <= S_DONE2;
                end if;

             when S_DONE2 =>
                o_done <= '0';
               if i_start = '1' then
                 current_state <= S_FETCH;
                end if; 
            end case;

      end if;

      end process;
end Behavioral;


