
valore_dimensione(grande, 3).
valore_dimensione(medio, 2).
valore_dimensione(piccolo, 1).

scacchiera_iniziale([
    [], [], [],
    [], [], [],
    [], [], []
]).

mano_iniziale_w([p(w,3), p(w,3), p(w,2), p(w,2), p(w,1), p(w,1)]).
mano_iniziale_b([p(b,3), p(b,3), p(b,2), p(b,2), p(b,1), p(b,1)]).

avversario(w, b).
avversario(b, w).

%GESTIONE SCACCHIERA 

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

%VISUALIZZAZIONE

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

%LOGICA DI GIOCO

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

%CONDIZIONI DI VITTORIA

linea(1, 2, 3).
linea(4, 5, 6).
linea(7, 8, 9).
linea(1, 4, 7).
linea(2, 5, 8).
linea(3, 6, 9).
linea(1, 5, 9).
linea(3, 5, 7).

controlla_vittoria(Board, Vincitore) :-
    linea(I1, I2, I3),
    cella_contiene(Board, I1, Vincitore),
    cella_contiene(Board, I2, Vincitore),
    cella_contiene(Board, I3, Vincitore),
    Vincitore \= vuoto.

cella_contiene(Board, Index, Colore) :-
    get_cella(Board, Index, Stack),
    get_top_piece(Stack, Top),
    estrai_colore(Top, Colore).

estrai_colore(vuoto, vuoto).
estrai_colore(p(Colore, _), Colore).

% 6. FUNZIONE EURISTICA

valore_pezzo(1, 1).
valore_pezzo(2, 3).
valore_pezzo(3, 5).

valuta_stato(stato(Board, _, _, _), MaxPlayer, Depth, Valore) :-
    avversario(MaxPlayer, MinPlayer),
    
    
    (controlla_vittoria(Board, MaxPlayer) -> 
        Valore is 500000 + Depth
    
    ; controlla_vittoria(Board, MinPlayer) -> 
        Valore is -500000 - Depth  
    ; 
        valuta_posizionale(Board, MaxPlayer, MinPlayer, BaseScore),
        Valore is BaseScore
    ).

valuta_posizionale(Board, Max, Min, Score) :-
    findall(1, linea_favorevole(Board, Max, Min), LeMieLinee),
    length(LeMieLinee, NumMie),
    findall(1, linea_favorevole(Board, Min, Max), LeSueLinee),
    length(LeSueLinee, NumSue),
    valuta_materiale(Board, Max, MatMio),
    valuta_materiale(Board, Min, MatSuo),
    bonus_centro(Board, Max, Bonus),
    
    Score is (NumMie * 1000) - (NumSue * 1000) + ((MatMio - MatSuo) * 10) + Bonus.

valuta_materiale(Board, Player, Totale) :-
    findall(Valore, (
        member(Stack, Board),
        Stack = [p(Player, Size) | _],
        valore_pezzo(Size, Valore)
    ), ListaValori),
    sum_list(ListaValori, Totale).

linea_favorevole(Board, Player, Nemico) :-
    linea(I1, I2, I3),
    \+ cella_contiene(Board, I1, Nemico),
    \+ cella_contiene(Board, I2, Nemico),
    \+ cella_contiene(Board, I3, Nemico),
    (cella_contiene(Board, I1, Player) ; 
     cella_contiene(Board, I2, Player) ; 
     cella_contiene(Board, I3, Player)).

bonus_centro(Board, Player, 50) :- cella_contiene(Board, 5, Player), !.
bonus_centro(_, _, 0).

% MINIMAX

cerca_mossa_migliore(Stato, Depth, MossaFinale, Valore) :-
    Stato = stato(_, _, _, ChiSonoIo),
    write('AI: Analisi tattica...'), nl,
    
    % KILLER MOVE: 
    (trova_mossa_vincente(Stato, MossaVincente) ->
        write('AI: SCACCO MATTO IN 1! Eseguo.'), nl,
        MossaFinale = MossaVincente,
        Valore = 999999
    ;
        % MINIMAX
       alphabeta(Stato, Depth, -1000000, 1000000, ChiSonoIo, MossaFinale, Valore)
    ),
    !.

trova_mossa_vincente(Stato, Mossa) :-
    Stato = stato(_, _, _, ChiSonoIo),
    mossa(Stato, Mossa, NuovoStato),
    NuovoStato = stato(NuovaBoard, _, _, _),
    controlla_vittoria(NuovaBoard, ChiSonoIo).

% ALPHABETA

% Caso Base: Profondità 0
alphabeta(Stato, 0, _, _, MaxPlayer, no_move, Valore) :-
    valuta_stato(Stato, MaxPlayer, 0, Valore), !.

% Caso Base: Partita Finita (Vittoria/Sconfitta trovata prima del limite)
alphabeta(stato(Board, MW, MB, Turno), Depth, _, _, MaxPlayer, no_move, Valore) :-
    (controlla_vittoria(Board, _) -> 
        valuta_stato(stato(Board, MW, MB, Turno), MaxPlayer, Depth, Valore)
    ), !.

% Passo Ricorsivo
alphabeta(Stato, Depth, Alpha, Beta, MaxPlayer, BestMove, BestVal) :-
    Stato = stato(_, _, _, TurnoCorrente),
    findall(M, mossa(Stato, M, _), MosseGrezze),
    sort(MosseGrezze, Mosse),
    
    (Mosse = [] -> 
        valuta_stato(Stato, MaxPlayer, Depth, BestVal), BestMove = no_move
    ;
        D1 is Depth - 1,
        Mosse = [M1 | _],
        (TurnoCorrente = MaxPlayer ->
            process_max(Mosse, Stato, D1, Alpha, Beta, MaxPlayer, M1, -1000000, BestMove, BestVal)
        ;
            process_min(Mosse, Stato, D1, Alpha, Beta, MaxPlayer, M1, 1000000, BestMove, BestVal)
        )
    ).

process_max([], _, _, Alpha, _, _, BestMove, _, BestMove, Alpha).
process_max([M|Resto], Stato, Depth, Alpha, Beta, MaxPlayer, CurrentBestMove, _, FinalBestMove, FinalVal) :-
    mossa(Stato, M, NuovoStato),
    alphabeta(NuovoStato, Depth, Alpha, Beta, MaxPlayer, _, Val),
    
    (Val > Alpha -> NewAlpha = Val, NewBestMove = M ; NewAlpha = Alpha, NewBestMove = CurrentBestMove),
    (NewAlpha >= Beta -> FinalBestMove = NewBestMove, FinalVal = Beta ; process_max(Resto, Stato, Depth, NewAlpha, Beta, MaxPlayer, NewBestMove, _, 
        FinalBestMove, FinalVal)).

process_min([], _, _, _, Beta, _, BestMove, _, BestMove, Beta).
process_min([M|Resto], Stato, Depth, Alpha, Beta, MaxPlayer, CurrentBestMove, _, FinalBestMove, FinalVal) :-
    mossa(Stato, M, NuovoStato),
    alphabeta(NuovoStato, Depth, Alpha, Beta, MaxPlayer, _, Val),
    
    (Val < Beta -> NewBeta = Val, NewBestMove = M ; NewBeta = Beta, NewBestMove = CurrentBestMove),
    (Alpha >= NewBeta -> FinalBestMove = NewBestMove, FinalVal = Alpha ; process_min(Resto, Stato, Depth, Alpha, NewBeta, MaxPlayer, NewBestMove, _,
         FinalBestMove, FinalVal)).

% INTERFACCIA UTENTE

play :-
    write('========================================'), nl,
    write('      GOBBLET GOBBLERS - PROLOG AI      '), nl,
    write('========================================'), nl,
    scacchiera_iniziale(Board),
    mano_iniziale_w(MW),
    mano_iniziale_b(MB),
    StatoIniziale = stato(Board, MW, MB, w),
    game_loop(StatoIniziale).

game_loop(Stato) :-
    Stato = stato(Board, _, _, Turno),
    show_board(Board),
    (controlla_vittoria(Board, Vincitore) ->
        nl, write('*** PARTITA FINITA! ***'), nl,
        write('Il vincitore e\': '), write(Vincitore), nl
    ;
        (Turno = w -> gestisci_turno_umano(Stato, NuovoStato) ; gestisci_turno_ai(Stato, NuovoStato)),
        game_loop(NuovoStato)
    ).

gestisci_turno_umano(Stato, NuovoStato) :-
    write('--- TOCCA A TE (White) ---'), nl,
    write('1. Gioca pezzo dalla mano, 2. Sposta pezzo'), nl,
    read(Scelta), 
    (Scelta = 1 -> scegli_mossa_mano(Stato, Mossa) ; Scelta = 2 -> scegli_mossa_scacchiera(Stato, Mossa) ; gestisci_turno_umano(Stato, NuovoStato)),
    (mossa(Stato, Mossa, TempStato) -> NuovoStato = TempStato ; write('MOSSA NON VALIDA!'), nl, gestisci_turno_umano(Stato, NuovoStato)).

scegli_mossa_mano(_, gioca_da_mano(p(w, Dim), Indice)) :-
    write('Dimensione (1-3): '), read(Dim), write('Pos (1-9): '), read(Indice).

scegli_mossa_scacchiera(_, sposta(Da, A)) :-
    write('Da (1-9): '), read(Da), write('A (1-9): '), read(A).

gestisci_turno_ai(Stato, NuovoStato) :-
    nl, write('--- TOCCA ALL AI (Black) ---'), nl,
    cerca_mossa_migliore(Stato, 3, MossaAI, Val), 
    format('AI sceglie: ~w (Val: ~w)', [MossaAI, Val]), nl,
    mossa(Stato, MossaAI, NuovoStato).