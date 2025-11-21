import tkinter as tk
from tkinter import messagebox
import ctypes
import os
import sys
import subprocess
import re
import time

# =============================================================================
# 1. FASE DI AVVIO E FIX (DEVE ESSERE FATTA PRIMA DI IMPORTARE PYSWIP!)
# =============================================================================
print("--- AVVIO GUI E CONFIGURAZIONE AMBIENTE ---")

def configure_environment():
    """Configura le variabili d'ambiente e carica la libreria corretta."""
    try:
        # Chiediamo a SWI-Prolog dove sono i suoi file
        try:
            output = subprocess.check_output(["swipl", "--dump-runtime-variables"]).decode("utf-8")
        except FileNotFoundError:
            print("ERRORE: Comando 'swipl' non trovato. Assicurati di aver installato swi-prolog via Homebrew.")
            return False

        config = {}
        for line in output.splitlines():
            match = re.match(r'(\w+)="([^"]+)";', line)
            if match:
                config[match.group(1)] = match.group(2)
        
        plbase = config.get("PLBASE") # Es: /opt/homebrew/Cellar/swi-prolog/9.2.9/lib/swipl
        plarch = config.get("PLARCH") # Es: arm64-darwin
        
        if not plbase:
            print("ERRORE: Impossibile trovare PLBASE.")
            return False

        print(f"Home Prolog rilevata: {plbase}")

        # 1. FIX CARTELLA FRAMEWORKS (Il trucco che abbiamo scoperto prima)
        # Creiamo la cartella vuota che PySwip cerca erroneamente
        parent_dir = os.path.dirname(plbase) # .../lib
        fw_path = os.path.join(parent_dir, "Frameworks")
        if not os.path.exists(fw_path):
            print(f"FIX: Creo cartella mancante {fw_path}")
            try:
                os.makedirs(fw_path, exist_ok=True)
            except Exception as e:
                print(f"Warning creazione cartella: {e}")

        # 2. IMPOSTIAMO LE VARIABILI D'AMBIENTE
        os.environ["SWI_HOME_DIR"] = plbase
        os.environ["PLBASE"] = plbase
        # Questo serve per trovare libgmp e altre dipendenze
        os.environ["DYLD_LIBRARY_PATH"] = "/opt/homebrew/lib" 
        
        # 3. TROVIAMO E CARICHIAMO LA LIBRERIA
        # Percorso standard Homebrew
        lib_path = os.path.join(plbase, "lib", plarch, "libswipl.dylib")
        
        if not os.path.exists(lib_path):
            # Fallback: cerca ricorsivamente se il path è diverso
            import glob
            found = glob.glob("/opt/homebrew/**/libswipl.dylib", recursive=True)
            if found:
                lib_path = sorted(found)[-1]
            else:
                print("ERRORE CRITICO: libswipl.dylib non trovata.")
                return False

        print(f"Caricamento libreria: {lib_path}")
        # FORZIAMO IL CARICAMENTO ORA
        ctypes.CDLL(lib_path)
        return True

    except Exception as e:
        print(f"Errore durante la configurazione: {e}")
        return False

# ESEGUIAMO IL FIX ORA
if not configure_environment():
    print("Configurazione fallita. Provo comunque a importare, ma potrebbe crashare...")

# =============================================================================
# 2. ORA POSSIAMO IMPORTARE PYSWIP (E POI IL RESTO DEL CODICE)
# =============================================================================
try:
    from pyswip import Prolog
    print("PySwip importato con successo!")
except ImportError as e:
    print(f"ERRORE IMPORTAZIONE PYSWIP: {e}")
    print("Il fix non ha funzionato come previsto.")
    sys.exit(1)
except OSError as e:
    print(f"ERRORE LIBRERIA: {e}")
    print("PySwip sta ancora cercando nel posto sbagliato.")
    sys.exit(1)


class GobbletGUI:
    def __init__(self, root):
        self.root = root
        self.root.title("Gobblet Gobblers - Prolog AI")
        self.root.geometry("800x600")
        self.root.configure(bg="#f0f0f0")
        
        # Inizializza Prolog
        self.prolog = Prolog()
        try:
            print("Caricamento file gobblet.pl...")
            self.prolog.consult("gobblet.pl")
        except Exception as e:
            messagebox.showerror("Errore Prolog", f"Impossibile caricare gobblet.pl\n{e}")
            sys.exit(1)

        # STATO DEL GIOCO (Python side)
        self.board = [[] for _ in range(9)] 
        # Stringhe che rappresentano i pezzi prolog
        self.hand_w = ["p(w,3)", "p(w,3)", "p(w,2)", "p(w,2)", "p(w,1)", "p(w,1)"]
        self.hand_b = ["p(b,3)", "p(b,3)", "p(b,2)", "p(b,2)", "p(b,1)", "p(b,1)"]
        self.turn = 'w'
        self.game_over = False

        # Variabili selezione
        self.selected_source = None 
        self.selected_btn = None

        self.create_widgets()
        self.update_ui()

    def create_widgets(self):
        # Layout principale
        main_frame = tk.Frame(self.root, bg="#f0f0f0")
        main_frame.pack(expand=True, fill="both", padx=20, pady=20)
        
        # Titolo
        tk.Label(main_frame, text="Gobblet Gobblers vs AI", font=("Helvetica", 24, "bold"), bg="#f0f0f0").pack(pady=(0,10))
        self.lbl_status = tk.Label(main_frame, text="Tocca a te (Bianco)", font=("Arial", 16), fg="blue", bg="#f0f0f0")
        self.lbl_status.pack(pady=5)

        # Area Gioco (Mano W - Board - Mano B)
        game_area = tk.Frame(main_frame, bg="#f0f0f0")
        game_area.pack(pady=20)

        # --- SINISTRA: MANO GIOCATORE ---
        left_col = tk.Frame(game_area, bg="#e0e0e0", padx=10, pady=10, relief="groove", bd=2)
        left_col.grid(row=0, column=0, padx=20, sticky="n")
        tk.Label(left_col, text="Tua Riserva", font=("Arial", 12, "bold"), bg="#e0e0e0").pack(pady=5)
        
        self.hand_buttons_w = []
        for i in range(6):
            btn = tk.Button(left_col, text="W", font=("Arial", 12), width=6, 
                            command=lambda idx=i: self.on_hand_click(idx))
            btn.pack(pady=2)
            self.hand_buttons_w.append(btn)

        # --- CENTRO: SCACCHIERA ---
        center_col = tk.Frame(game_area, bg="black", bd=5)
        center_col.grid(row=0, column=1, padx=20)
        
        self.board_buttons = []
        for i in range(9):
            btn = tk.Button(center_col, text="", font=("Arial", 20, "bold"), width=5, height=2,
                            command=lambda idx=i: self.on_board_click(idx + 1))
            btn.grid(row=i//3, column=i%3, padx=2, pady=2)
            self.board_buttons.append(btn)

        # --- DESTRA: MANO AI ---
        right_col = tk.Frame(game_area, bg="#e0e0e0", padx=10, pady=10, relief="groove", bd=2)
        right_col.grid(row=0, column=2, padx=20, sticky="n")
        tk.Label(right_col, text="Riserva AI", font=("Arial", 12, "bold"), bg="#e0e0e0").pack(pady=5)
        
        self.hand_labels_b = []
        for i in range(6):
            lbl = tk.Label(right_col, text="B", font=("Arial", 12), bg="#ccc", width=6, relief="sunken", pady=4)
            lbl.pack(pady=2) # Spaziatura verticale
            self.hand_labels_b.append(lbl)

    # --- LOGICA DI GIOCO E COMUNICAZIONE CON PROLOG ---

    def format_list_prolog(self, py_list):
        if not py_list: return "[]"
        elements = []
        for item in py_list:
            if isinstance(item, list):
                elements.append(self.format_list_prolog(item))
            else:
                elements.append(str(item))
        return "[" + ", ".join(elements) + "]"

    def check_winner(self):
        # 1. FORZA L'AGGIORNAMENTO GRAFICO
        # Obbliga Tkinter a disegnare l'ultimo pezzo PRIMA di aprire il popup
        self.root.update() 
        
        # 2. PAUSA SCENICA
        # Aspetta mezzo secondo così l'occhio umano registra la mossa finale
        # (Necessario import time all'inizio del file)
        
        board_str = self.format_list_prolog(self.board)
        query = f"controlla_vittoria({board_str}, Winner)"
        
        try:
            res = list(self.prolog.query(query))
            if res:
                # Se c'è un vincitore, aspetta un attimo prima di urlarlo
                time.sleep(0.5) 
                
                winner = res[0]['Winner']
                if winner == 'w':
                    messagebox.showinfo("Vittoria!", "Complimenti! Hai battuto l'IA!")
                else:
                    messagebox.showinfo("Sconfitta", "L'IA ti ha battuto. Riprova!")
                
                self.game_over = True
                self.root.quit()
                return True
        except Exception as e: 
            pass
            
        return False

    def on_hand_click(self, index):
        if self.turn != 'w' or self.game_over: return
        if index >= len(self.hand_w): return 

        self.reset_visuals()
        
        piece_str = self.hand_w[index] # es: p(w,3)
        size = piece_str.split(',')[1][0]
        
        self.selected_source = ('hand', index, piece_str)
        self.hand_buttons_w[index].config(bg="#ffff99") # Giallo chiaro
        self.selected_btn = self.hand_buttons_w[index]
        self.lbl_status.config(text=f"Selezionato W{size}. Scegli dove metterlo!")

    def on_board_click(self, index):
        if self.turn != 'w' or self.game_over: return

        # SELEZIONE SORGENTE (Sposto un pezzo dalla scacchiera)
        if self.selected_source is None:
            stack = self.board[index-1]
            if stack and 'w' in stack[0]: 
                self.reset_visuals()
                self.selected_source = ('board', index)
                self.board_buttons[index-1].config(bg="#ffff99")
                self.selected_btn = self.board_buttons[index-1]
                self.lbl_status.config(text=f"Sposta pezzo da cella {index}...")
            return

        # ESECUZIONE MOSSA (Destinazione)
        move_prolog = ""
        if self.selected_source[0] == 'hand':
            idx_hand, piece_str = self.selected_source[1], self.selected_source[2]
            move_prolog = f"gioca_da_mano({piece_str}, {index})"
            
            if self.try_move_prolog(move_prolog):
                self.hand_w.pop(idx_hand)
                self.finish_turn()
            else:
                self.reset_selection()

        elif self.selected_source[0] == 'board':
            from_idx = self.selected_source[1]
            if from_idx == index: # Cliccato su se stesso -> Annulla
                self.reset_selection()
                return
            
            move_prolog = f"sposta({from_idx}, {index})"
            if self.try_move_prolog(move_prolog):
                self.finish_turn()
            else:
                self.reset_selection()

    def try_move_prolog(self, move_str):
        board_s = self.format_list_prolog(self.board)
        hand_w_s = self.format_list_prolog(self.hand_w)
        hand_b_s = self.format_list_prolog(self.hand_b)
        
        query = f"mossa(stato({board_s}, {hand_w_s}, {hand_b_s}, w), {move_str}, _)"
        
        try:
            res = list(self.prolog.query(query))
            if res:
                self.apply_move_logic_python(move_str)
                return True
            else:
                messagebox.showwarning("Mossa Non Valida", "Non puoi fare questa mossa!")
                return False
        except Exception as e:
            print(f"Errore query mossa: {e}")
            return False

    def apply_move_logic_python(self, move_str):
        # FIX: Usiamo Regex per estrarre il pezzo correttamente
        # Questo evita il bug che creava pezzi corrotti tipo [p,3)]
        
        if "gioca_da_mano" in move_str:
            # Cerca esattamente il pattern p(colore,numero). Es: p(w,3)
            match = re.search(r"p\([wb],\d\)", move_str)
            if match:
                piece = match.group(0) # Abbiamo catturato "p(w,3)" pulito
                
                # L'indice è l'ultimo numero dopo la virgola
                # Es: gioca_da_mano(..., 5) -> prende 5
                idx_str = move_str.split(',')[-1].replace(')', '').strip()
                idx = int(idx_str) - 1
                
                self.board[idx].insert(0, piece)
            
        elif "sposta" in move_str:
            # Estrae tutti i numeri dalla stringa sposta(1, 9)
            nums = re.findall(r"\d+", move_str)
            if len(nums) >= 2:
                src = int(nums[0]) - 1
                dst = int(nums[1]) - 1
                
                # Sposta fisicamente il pezzo nella lista Python
                if self.board[src]:
                    piece = self.board[src].pop(0)
                    self.board[dst].insert(0, piece)
    def reset_visuals(self):
        if self.selected_btn:
            if self.selected_btn in self.hand_buttons_w:
                self.selected_btn.config(bg="SystemButtonFace")
            else:
                self.update_ui() # Refresh board colors
    
    def reset_selection(self):
        self.reset_visuals()
        self.selected_source = None
        self.selected_btn = None
        self.lbl_status.config(text="Tocca a te (Bianco)")

    def finish_turn(self):
        self.reset_selection()
        self.update_ui()
        if self.check_winner(): return
        
        self.turn = 'b'
        self.lbl_status.config(text="L'AI sta pensando...", fg="red")
        self.root.after(100, self.ai_turn) 

    def ai_turn(self):
        board_s = self.format_list_prolog(self.board)
        hand_w_s = self.format_list_prolog(self.hand_w)
        hand_b_s = self.format_list_prolog(self.hand_b)
        
        print("AI Thinking...")
        # Assicurati che gobblet.pl abbia il CUT (!) alla fine di cerca_mossa_migliore
        query = f"cerca_mossa_migliore(stato({board_s}, {hand_w_s}, {hand_b_s}, b), 2, Mossa, _)"
        
        try:
            res = list(self.prolog.query(query))
            if res:
                best_move = str(res[0]['Mossa'])
                print(f"AI Move Raw: {best_move}") # Debug
                
                if "gioca_da_mano" in best_move:
                    # 1. FIX SPAZI: Prolog restituisce "p(b, 3)", noi vogliamo "p(b,3)"
                    # Regex che accetta spazi opzionali \s* dopo la virgola
                    match = re.search(r"p\([wb],\s*\d\)", best_move)
                    
                    if match:
                        # Puliamo la stringa rimuovendo gli spazi per matchare la lista Python
                        raw_piece = match.group(0)
                        piece = raw_piece.replace(" ", "") 
                        
                        # 2. Estrai indice (ultimo numero)
                        nums = re.findall(r"\d+", best_move)
                        idx_board = int(nums[-1]) - 1
                        
                        print(f"AI mette {piece} in cella {idx_board+1}") # Debug visuale
                        
                        # 3. Aggiorna Logica Python
                        if piece in self.hand_b: 
                            self.hand_b.remove(piece)
                        self.board[idx_board].insert(0, piece)
                    else:
                        print("ERRORE REGEX: Non riesco a leggere il pezzo nella mossa AI")

                elif "sposta" in best_move:
                    nums = re.findall(r"\d+", best_move)
                    if len(nums) >= 2:
                        src = int(nums[0]) - 1
                        dst = int(nums[1]) - 1
                        
                        print(f"AI sposta da {src+1} a {dst+1}")
                        
                        if self.board[src]:
                            piece = self.board[src].pop(0)
                            self.board[dst].insert(0, piece)
                    
                self.update_ui()
                if self.check_winner(): return
                self.turn = 'w'
                self.lbl_status.config(text="Tocca a te (Bianco)", fg="blue")
            else:
                # Se Prolog non risponde nulla (lista vuota)
                messagebox.showerror("Errore AI", "L'AI non ha trovato mosse valide.")
        except Exception as e:
            print(f"Errore AI: {e}")
            print(f"Stato Board al crash: {self.board}")

    def update_ui(self):
        # Aggiorna Board
        for i in range(9):
            stack = self.board[i]
            btn = self.board_buttons[i]
            
            if not stack:
                btn.config(text="", bg="white")
            else:
                top = stack[0]
                color = "blue" if 'w' in top else "red"
                bg_color = "#d0e0ff" if 'w' in top else "#ffd0d0"
                size = top.split(',')[1][0]
                btn.config(text=f"{size}", fg=color, bg=bg_color)

        # Aggiorna Mani
        for i, btn in enumerate(self.hand_buttons_w):
            if i < len(self.hand_w):
                size = self.hand_w[i].split(',')[1][0]
                btn.config(text=f"{size}", state="normal", bg="#e0e0e0")
            else:
                btn.config(text="", state="disabled", bg="#f0f0f0", relief="flat")
                
        for i, lbl in enumerate(self.hand_labels_b):
             if i < len(self.hand_b):
                size = self.hand_b[i].split(',')[1][0]
                lbl.config(text=f"{size}", bg="#ccc")
             else:
                lbl.config(text="", bg="#f0f0f0", relief="flat")

if __name__ == "__main__":
    root = tk.Tk()
    app = GobbletGUI(root)
    root.mainloop()