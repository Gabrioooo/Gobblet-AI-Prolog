import ctypes
import os
import sys
import subprocess
import re




try:
    output = subprocess.check_output(["swipl", "--dump-runtime-variables"]).decode("utf-8")
    config = {}
    for line in output.splitlines():
        match = re.match(r'(\w+)="([^"]+)";', line)
        if match:
            config[match.group(1)] = match.group(2)
except Exception as e:
    print("ERRORE: Impossibile eseguire 'swipl'. Assicurati che sia installato.")
    sys.exit(1)

plbase = config.get("PLBASE") 
plarch = config.get("PLARCH") 

print(f"PLBASE rilevata: {plbase}")


parent_dir = os.path.dirname(plbase) 
frameworks_missing = os.path.join(parent_dir, "Frameworks")

print(f"Controllo esistenza cartella critica: {frameworks_missing}")

if not os.path.exists(frameworks_missing):
    print(">>> FIX: La cartella manca. La creo ora.")
    try:
        os.makedirs(frameworks_missing, exist_ok=True)
        print(">>> Cartella creata con successo!")
    except Exception as e:
        print(f"ERRORE CREAZIONE CARTELLA: {e}")
        print("Prova a farlo a mano col comando:")
        print(f"mkdir -p {frameworks_missing}")
        sys.exit(1)
else:
    print("La cartella esiste già.")

lib_path = os.path.join(plbase, "lib", plarch, "libswipl.dylib")
if not os.path.exists(lib_path):
    import glob
    found = glob.glob("/opt/homebrew/**/libswipl.dylib", recursive=True)
    if found:
        lib_path = sorted(found)[-1]

print(f"Libreria dinamica: {lib_path}")

os.environ["SWI_HOME_DIR"] = plbase
os.environ["PLBASE"] = plbase

try:
    ctypes.CDLL(lib_path)
    from pyswip import Prolog
    prolog = Prolog()
    
    print("\n>>> PROLOG CONNESSO! <<<")
    
    prolog.consult("gobblet.pl")
    board = "[ [], [], [], [], [], [], [], [], [] ]"
    hand_w = "[p(w,3)]" 
    hand_b = "[p(b,3)]"
    query = f"cerca_mossa_migliore(stato({board}, {hand_w}, {hand_b}, w), 1, M, V)"
    
    print("Test query...")
    res = list(prolog.query(query))
    if res:
        print(f"RISPOSTA AI: {res[0]['M']}")
        print("\n--- Ora ti passo il codice grafico completo ---")

except Exception as e:
    print(f"\nERRORE FINALE: {e}")