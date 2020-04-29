----------------------------------------------------------------------------------
-- Company: Polimi
-- Designer: Alessandro Lisi
-- 
-- Create Date: 26.02.2020 12:22:12
-- Last Edit: 29.04.2020 23:41
-- Design Name: Progetto di Reti Logiche 2020 Workzone Encoder
-- Module Name: proj_RL_01 - Behavioral
-- Project Name: Workzone Encoder

----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

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
                   S_DONE, S_DONE2);
                   
    signal current_state : State; --lo stato corrente nel quale si trova la macchina 
    
    signal ram_wait_ret_state : State; --utilizzato quando si passa in RAM_WAIT per sapere in che stato tornare nel ciclo 
                                         --di clock successivo
    

    signal address : std_logic_vector (7 downto 0); --indirizzo letto
    signal counter_3 : std_logic_vector (3 downto 0) := (others => '0'); --contatore usato per iterare le working zones
    
    signal hp0, hp1, hp2, hp3 : std_logic_vector (7 downto 0) := (others => '0'); --calcolo degli indirizzi interni alla wz
    signal cmp_wz_found : std_logic; --bit che viene messo a 1 quando ho un match (address coincide con un indirizzo di una wz)
    signal cmp_wz_num : std_logic_vector (2 downto 0);
    signal cmp_wz_offset_one_hot : std_logic_vector(3 downto 0);

 
begin


algo: process (i_clk, i_rst) is --singolo processo sensibile al clock e al reset


      begin
      
       if i_rst = '1' then
       
            current_state <= S_IDLE; --mi metto nello stato di IDLE
            o_done <= '0'; -- resetto i segnali di uscita
            o_en <= '0'; --non voglio ne leggere ne scrivere
            o_we <= '0';
            counter_3 <= "0000";  --inizializzo contatore WZ
            cmp_wz_found <= '0';   --inizializzo bit wz trovata


       elsif i_clk'event and rising_edge(i_clk) then
          

       --macchina a stati
         case current_state is
         --in attesa del segnale di start
            when S_IDLE =>
               if i_start = '1' then
                  current_state <= S_FETCH;
               end if;
          --aspetta 1ck per ottenere il dato letto dalla ram, successivamente torna nello stato indicato in ram wait return state
            when S_RAM_WAIT => 
                current_state <= ram_wait_ret_state;
          --legge l'indirizzo della ram
            when S_FETCH => 
               --voglio leggere dalla memoria
               o_en <= '1';
               counter_3 <= "0000";  --inizializzo contatore WZ e i vari segnali ausiliari
               cmp_wz_found <= '0';
               
               --leggo l'indirizzo da codificare, si trova nella 8va posizione
               o_address <= std_logic_vector(to_unsigned( 8 , 16)); 
                --ed eimino l'8 bit mettendolo a 0 dato che tratto indirizzi da 7 bit
               ram_wait_ret_state <= S_FETCH2;
               current_state <= S_RAM_WAIT;
               
            when S_FETCH2 =>

               address <= i_data;  --salvo l'indirizzo letto nel segnale address
               --ram_wait_ret_state <= S_COMPARE; 
               --current_state <= S_RAM_WAIT;
               current_state <= S_COMPARE;

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
             --inizializzo found e i vari sotto campi  a 0.
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
               
            when S_COMPARE2 => --data una wz controlla se c'è un match tra address e i 4 possibili indirizzi hp0,1,2,3
                                  
            --esegui i controlli: guarda se l'indirizzo matcha con WZ + 0,1,2,3, se c'è un match riempi i campi dell'indirizzo codificato
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
                cmp_wz_found <= '0'; --non ho trovato un'appartenenza ad una wz, ritorno a compare 
            end if;
            
            

            --INVIO: 
            when s_send =>  --quando non ho nessun match e lo invio cosi come è
                o_en <= '1'; -- voglio accedere alla ram e scriverci
                o_we <= '1';
                o_data <= address;  --indirizzo dry non modificato
                o_address <= std_logic_vector(to_unsigned( 9 , 16));
                ram_wait_ret_state <= S_DONE;
                current_state <= S_RAM_WAIT;
                
            when s_send_enc => --ho trovato un match in una delle wz, combino i campi compilati in precedenza per ottenere l'indirizzo codificato
                
                 o_data <= '1' & cmp_wz_num & cmp_wz_offset_one_hot; --l'indirizzo codificato come concatenazione dei sotto campi
                 o_address <= std_logic_vector(to_unsigned( 9 , 16));                o_we <= '1';
                 ram_wait_ret_state <= S_DONE;
                 current_state <= S_RAM_WAIT;

          --metto done a 1 e aspetto start a 0.
            when S_DONE =>
            
                o_en <= '0';  --chiudo scrittura/lettura dalla ram
                o_we <= '0';
                o_done <= '1';
                if i_start = '0' then
                    current_state <= S_DONE2;
                end if;

             when S_DONE2 => --quando start è stato posto a 0
                o_done <= '0'; --metto done a 1
               if i_start = '1' then --se start torna a 1 in questo punto posso ri partire
                 current_state <= S_FETCH;
                end if; 
            end case;

      end if;

      end process;
end Behavioral;


