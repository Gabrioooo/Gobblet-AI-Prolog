# Gobblet Gobblers AI - Prolog & Python

Progetto di Intelligenza Artificiale basato sul gioco da tavolo "Gobblet Gobblers".
Il sistema utilizza un'interfaccia grafica in **Python (Tkinter)** e un motore logico in **Prolog** che implementa l'algoritmo **Minimax con Alpha-Beta Pruning**.

## Requisiti

* **SWI-Prolog** (installato e accessibile da terminale)
* **Python 3.x**
* Libreria **pyswip**

## Installazione su macOS (Apple Silicon)

1.  Installare SWI-Prolog tramite Homebrew:
    ```bash
    brew install swi-prolog
    ```
2.  Creare l'ambiente virtuale e installare le dipendenze:
    ```bash
    python3 -m venv venv
    source venv/bin/activate
    pip install pyswip
    ```

## Avvio del Gioco

Assicurarsi di essere nell'ambiente virtuale ed eseguire:

```bash
python gobblet_gui.py