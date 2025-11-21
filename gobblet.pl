% ==============================================================================
% 1. CONFIGURAZIONE E FATTI INIZIALI
% ==============================================================================

valore_dimensione(grande, 3).
valore_dimensione(medio, 2).
valore_dimensione(piccolo, 1).

% ECCOLO QUI: Assicurati che questo pezzo ci sia!
scacchiera_iniziale([
    [], [], [],
    [], [], [],
    [], [], []
]).

% Mano Iniziale
mano_iniziale_w([p(w,3), p(w,3), p(w,2), p(w,2), p(w,1), p(w,1)]).
mano_iniziale_b([p(b,3), p(b,3), p(b,2), p(b,2), p(b,1), p(b,1)]).

avversario(w, b).
avversario(b, w).

% ==============================================================================
% 2. GESTIONE SCACCHIERA
% ==============================================================================

get_cella(Board, Index, Stack) :- nth1(Index, Board, Stack).

get_top_piece([], vuoto).
get_top_piece([Testa|_], Testa).

puo_mangiare(_, vuoto).
puo_mangiare(p(_, Dim1), p(_, Dim2)) :- Dim1 > Dim2.

metti_pezzo(Board, Index, Pezzo, NewBoard) :-
    nth1(Index, Board, OldStack, Resto),
    NewStack = [Pezzo | OldStack],
    nth1(Index, NewBoard, NewStack, Resto).

rimuovi_pezzo_da_mano(Mano, Pezzo, NuovaMano) :- select(Pezzo, Mano, NuovaMano).

% ==============================================================================
% 3. VISUALIZZAZIONE
% ==============================================================================

show_board(Board) :-
    nl, write('   SCACCHIERA   '), nl,
    write('-----------------'), nl,
    print_row(Board, 1, 3),
    write('-----------------'), nl,
    print_row(Board, 4, 6),
    write('-----------------'), nl,
    print_row(Board, 7, 9),
    write('-----------------'), nl, nl.

print_row(Board, Start, End) :-
    findall(Symbol, (
        between(Start, End, I),
        get_cella(Board, I, Stack),
        get_top_piece(Stack, Top),
        symbol(Top, Symbol)
    ), Symbols),
    format('| ~w | ~w | ~w |', Symbols), nl.

symbol(vuoto, '  ').
symbol(p(w, Dim), S) :- format(atom(S), 'W~d', [Dim]).
symbol(p(b, Dim), S) :- format(atom(S), 'B~d', [Dim]).

% ==============================================================================
% 4. LOGICA DI GIOCO (Generazione Mosse)
% ==============================================================================

cambia_turno(w, b).
cambia_turno(b, w).

get_mano_corrente(stato(_, MW, _, w), MW).
get_mano_corrente(stato(_, _, MB, b), MB).

mossa(stato(Board, MW, MB, Turno), gioca_da_mano(Pezzo, Index), NuovoStato) :-
    (Turno = w -> Mano = MW ; Mano = MB),
    select(Pezzo, Mano, NuovaMano),
    between(1, 9, Index),
    get_cella(Board, Index, Stack),
    get_top_piece(Stack, Top),
    puo_mangiare(Pezzo, Top),
    metti_pezzo(Board, Index, Pezzo, NewBoard),
    cambia_turno(Turno, NextTurno),
    (Turno = w 
        -> NuovoStato = stato(NewBoard, NuovaMano, MB, NextTurno)
        ;  NuovoStato = stato(NewBoard, MW, NuovaMano, NextTurno)
    ).

mossa(stato(Board, MW, MB, Turno), sposta(Da, A), NuovoStato) :-
    between(1, 9, Da),
    get_cella(Board, Da, StackPartenza),
    get_top_piece(StackPartenza, p(Turno, Dim)),
    between(1, 9, A),
    Da \= A,
    get_cella(Board, A, StackArrivo),
    get_top_piece(StackArrivo, TopArrivo),
    puo_mangiare(p(Turno, Dim), TopArrivo),
    rimuovi_top(Board, Da, PezzoMosso, BoardSenzaPezzo),
    metti_pezzo(BoardSenzaPezzo, A, PezzoMosso, NewBoard),
    cambia_turno(Turno, NextTurno),
    NuovoStato = stato(NewBoard, MW, MB, NextTurno).

rimuovi_top(Board, Index, Top, NewBoard) :-
    nth1(Index, Board, [Top|Resto], Rimanenza),
    nth1(Index, NewBoard, Resto, Rimanenza).
% ==============================================================================
% 5. CONDIZIONI DI VITTORIA
% ==============================================================================

% Definiamo le terne di indici che formano una linea vincente
linea(1, 2, 3). % Riga 1
linea(4, 5, 6). % Riga 2
linea(7, 8, 9). % Riga 3
linea(1, 4, 7). % Col 1
linea(2, 5, 8). % Col 2
linea(3, 6, 9). % Col 3
linea(1, 5, 9). % Diag \
linea(3, 5, 7). % Diag /

% controlla_vittoria(+Board, ?Vincitore)
% Restituisce 'w' o 'b' se c'è un vincitore.
controlla_vittoria(Board, Vincitore) :-
    linea(I1, I2, I3),             % Prendi una linea qualsiasi
    colore_cella(Board, I1, Vincitore), % Controlla il colore della prima cella
    colore_cella(Board, I2, Vincitore), % Deve essere uguale
    colore_cella(Board, I3, Vincitore), % Deve essere uguale
    Vincitore \= vuoto.            % Non deve essere vuoto

% Helper: estrae il colore del pezzo in cima a una cella
colore_cella(Board, Index, Colore) :-
    get_cella(Board, Index, Stack),
    get_top_piece(Stack, Top),
    estrai_colore(Top, Colore).

estrai_colore(vuoto, vuoto).
estrai_colore(p(Colore, _), Colore).
% ==============================================================================
% 6. FUNZIONE EURISTICA (Valutazione)
% ==============================================================================

% valuta_stato(+Stato, +GiocatoreMassimizzante, -Valore)
% Assegna un punteggio numerico allo stato dal punto di vista di MaxPlayer.

valuta_stato(stato(Board, _, _, _), MaxPlayer, Valore) :-
    avversario(MaxPlayer, MinPlayer),
    
    % 1. Caso Base: Partita Finita?
    (controlla_vittoria(Board, MaxPlayer) -> 
        Valore = 1000 % Ho vinto!
    ; controlla_vittoria(Board, MinPlayer) -> 
        Valore = -1000 % Ho perso!
    ; 
        % 2. Caso Ricorsivo: Partita in corso, valuta posizionale
        valuta_posizionale(Board, MaxPlayer, MinPlayer, Valore)
    ).

% valuta_posizionale(+Board, +Max, +Min, -Score)
% Calcola score basato su quante linee stiamo controllando
valuta_posizionale(Board, Max, Min, Score) :-
    findall(1, linea_favorevole(Board, Max, Min), LeMieLinee),
    length(LeMieLinee, NumMie),
    
    findall(1, linea_favorevole(Board, Min, Max), LeSueLinee),
    length(LeSueLinee, NumSue),
    
    % La formula: (Mie Linee * 10) - (Sue Linee * 10)
    % + Bonus per il centro (cella 5)
    bonus_centro(Board, Max, Bonus),
    Score is (NumMie * 10) - (NumSue * 10) + Bonus.

% Una linea è favorevole a 'Player' se contiene suoi pezzi e NESSUN nemico
linea_favorevole(Board, Player, Nemico) :-
    linea(I1, I2, I3),
    \+ cella_contiene(Board, I1, Nemico), % La cella NON contiene il nemico
    \+ cella_contiene(Board, I2, Nemico),
    \+ cella_contiene(Board, I3, Nemico),
    % E deve contenere almeno un pezzo mio (altrimenti è una linea vuota inutile)
    (cella_contiene(Board, I1, Player) ; 
     cella_contiene(Board, I2, Player) ; 
     cella_contiene(Board, I3, Player)).

% Verifica se una cella è controllata da un certo giocatore
cella_contiene(Board, Index, Player) :-
    get_cella(Board, Index, Stack),
    get_top_piece(Stack, p(Player, _)).

% Dare un piccolo bonus se si controlla il centro (Cella 5)
bonus_centro(Board, Player, 5) :- 
    cella_contiene(Board, 5, Player), !.
bonus_centro(_, _, 0).
% ==============================================================================
% 7. MOTORE AI: MINIMAX CON ALPHA-BETA PRUNING (OTTIMIZZATO)
% ==============================================================================

% cerca_mossa_migliore(+Stato, +Depth, -Mossa, -Valore)
cerca_mossa_migliore(Stato, Depth, BestMove, Valore) :-
    Stato = stato(_, _, _, ChiSonoIo),
    write('Inizio analisi mosse...'), nl,
    alphabeta(Stato, Depth, -10000, 10000, ChiSonoIo, BestMove, Valore),
    write('Analisi completata.'), nl,
    !.

% ------------------------------------------------------------------------------
% CASI BASE
% ------------------------------------------------------------------------------

% 1. Profondità 0 o Partita Finita
alphabeta(Stato, 0, _, _, MaxPlayer, no_move, Valore) :-
    valuta_stato(Stato, MaxPlayer, Valore), !.

alphabeta(stato(Board, MW, MB, Turno), _, _, _, MaxPlayer, no_move, Valore) :-
    (controlla_vittoria(Board, _) -> 
        valuta_stato(stato(Board, MW, MB, Turno), MaxPlayer, Valore)
    ), !.

% ------------------------------------------------------------------------------
% PASSO RICORSIVO
% ------------------------------------------------------------------------------

alphabeta(Stato, Depth, Alpha, Beta, MaxPlayer, BestMove, BestVal) :-
    Stato = stato(_, _, _, TurnoCorrente),
    
    % 1. Genera mosse GREZZE (con duplicati)
    findall(M, mossa(Stato, M, _), MosseGrezze),
    
    % 2. RIMUOVI DUPLICATI (Fondamentale per la velocità!)
    sort(MosseGrezze, Mosse),
    
    (Mosse = [] -> 
        % Nessuna mossa possibile (Stallo?)
        valuta_stato(Stato, MaxPlayer, BestVal), BestMove = no_move
    ;
        D1 is Depth - 1,
        (TurnoCorrente = MaxPlayer ->
            % MAX
            process_max(Mosse, Stato, D1, Alpha, Beta, MaxPlayer, no_move, -10000, BestMove, BestVal)
        ;
            % MIN
            process_min(Mosse, Stato, D1, Alpha, Beta, MaxPlayer, no_move, 10000, BestMove, BestVal)
        )
    ).

% ------------------------------------------------------------------------------
% HELPERS (MAX e MIN)
% ------------------------------------------------------------------------------

% --- PROCESS MAX ---
% Se la lista è finita, restituiamo il miglior valore trovato finora (Alpha corrente)
process_max([], _, _, Alpha, _, _, BestMove, _, BestMove, Alpha).

process_max([M|Resto], Stato, Depth, Alpha, Beta, MaxPlayer, CurrentBestMove, _, FinalBestMove, FinalVal) :-
    mossa(Stato, M, NuovoStato),
    alphabeta(NuovoStato, Depth, Alpha, Beta, MaxPlayer, _, Val),
    
    (Val > Alpha ->
        NewAlpha = Val,
        NewBestMove = M
    ;
        NewAlpha = Alpha,
        NewBestMove = CurrentBestMove
    ),
    
    (NewAlpha >= Beta ->
        % PRUNING (Taglio)
        FinalBestMove = NewBestMove,
        FinalVal = Beta
    ;
        process_max(Resto, Stato, Depth, NewAlpha, Beta, MaxPlayer, NewBestMove, _, FinalBestMove, FinalVal)
    ).

% --- PROCESS MIN ---
process_min([], _, _, _, Beta, _, BestMove, _, BestMove, Beta).

process_min([M|Resto], Stato, Depth, Alpha, Beta, MaxPlayer, CurrentBestMove, _, FinalBestMove, FinalVal) :-
    mossa(Stato, M, NuovoStato),
    alphabeta(NuovoStato, Depth, Alpha, Beta, MaxPlayer, _, Val),
    
    (Val < Beta ->
        NewBeta = Val,
        NewBestMove = M
    ;
        NewBeta = Beta,
        NewBestMove = CurrentBestMove
    ),
    
    (Alpha >= NewBeta ->
        % PRUNING (Taglio)
        FinalBestMove = NewBestMove,
        FinalVal = Alpha
    ;
        process_min(Resto, Stato, Depth, Alpha, NewBeta, MaxPlayer, NewBestMove, _, FinalBestMove, FinalVal)
    ).
% ==============================================================================
% 8. INTERFACCIA UTENTE (GAME LOOP)
% ==============================================================================

% play: Comando per iniziare la partita
play :-
    write('========================================'), nl,
    write('      GOBBLET GOBBLERS - PROLOG AI      '), nl,
    write('========================================'), nl,
    write('Tu sei il BIANCO (W). L\'AI e\' il NERO (B).'), nl,
    write('IMPORTANTE: Scrivi sempre il punto "." dopo ogni numero!'), nl,
    
    scacchiera_iniziale(Board),
    mano_iniziale_w(MW),
    mano_iniziale_b(MB),
    StatoIniziale = stato(Board, MW, MB, w),
    
    game_loop(StatoIniziale).

% Ciclo principale del gioco
game_loop(Stato) :-
    Stato = stato(Board, _, _, Turno),
    show_board(Board),
    
    % 1. Controllo Vittoria
    (controlla_vittoria(Board, Vincitore) ->
        nl, write('*** PARTITA FINITA! ***'), nl,
        write('Il vincitore e\': '), write(Vincitore), nl
    ;
        % 2. Gestione Turno
        (Turno = w ->
            % Turno Umano
            gestisci_turno_umano(Stato, NuovoStato)
        ;
            % Turno AI
            gestisci_turno_ai(Stato, NuovoStato)
        ),
        % Ricorsione
        game_loop(NuovoStato)
    ).

% --- Logica Turno Umano ---
gestisci_turno_umano(Stato, NuovoStato) :-
    write('--- TOCCA A TE (White) ---'), nl,
    write('Scegli azione:'), nl,
    write('1. Gioca pezzo dalla mano'), nl,
    write('2. Sposta pezzo sulla scacchiera'), nl,
    read(Scelta), % L'utente deve mettere il punto!
    
    (Scelta = 1 ->
        scegli_mossa_mano(Stato, Mossa)
    ; Scelta = 2 ->
        scegli_mossa_scacchiera(Stato, Mossa)
    ; 
        write('Scelta non valida. Riprova.'), nl,
        gestisci_turno_umano(Stato, NuovoStato)
    ),
    
    % Applica la mossa scelta
    (mossa(Stato, Mossa, TempStato) ->
        NuovoStato = TempStato
    ;
        write('!!! MOSSA ILLEGALE O IMPOSSIBILE !!!'), nl,
        write('Hai provato a mangiare un pezzo piu grande? O la cella non e\' tua?'), nl,
        gestisci_turno_umano(Stato, NuovoStato)
    ).

scegli_mossa_mano(_, gioca_da_mano(p(w, Dim), Indice)) :-
    write('Dimensione pezzo (1=Piccolo, 2=Medio, 3=Grande): '), read(Dim),
    write('Posizione (1-9): '), read(Indice).

scegli_mossa_scacchiera(_, sposta(Da, A)) :-
    write('Sposta dalla cella (1-9): '), read(Da),
    write('Alla cella (1-9): '), read(A).

% --- Logica Turno AI ---
gestisci_turno_ai(Stato, NuovoStato) :-
    nl, write('--- TOCCA ALL\' AI (Black) ---'), nl,
    write('L\'AI sta pensando...'), nl,
    
    % QUI SETTIAMO LA DIFFICOLTA' (Depth)
    % Metti 2 per veloce, 3 per intelligente, 4 per molto lento
    cerca_mossa_migliore(Stato, 3, MossaAI, _), 
    
    write('L\'AI ha scelto: '), write(MossaAI), nl,
    mossa(Stato, MossaAI, NuovoStato).