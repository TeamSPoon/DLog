:- module(abox_translator,[abox2prolog/3]).

:- use_module(library(lists)).
:- use_module(library(system), [datime/1]).
:- use_module(transforming_tools, [headwrite/1]).

% Available options:
% indexing(yes) : [yes, no] whether to generate inverses for roles for efficient indexes
% generate_abox(no): [yes, no] whether to generate an ABox Prolog file
abox2prolog(PFile, abox(ABoxStr), Options) :-
	generate_abox(ABoxStr, PFile, Options).

generate_abox(ABoxStr, PFile, Options) :-
	(
	  memberchk(indexing(no), Options) ->
	  Indexing = no
	;
	  Indexing = yes
	),
	(
	  memberchk(generate_abox(yes), Options) ->
	  ABox = yes
	;
	  ABox = no
	),
	
	generate_abox0(ABoxStr, PFile, Options, Indexing, ABox).


generate_abox0(ABoxStr, PFile, Options, Indexing, ABox) :-
	ABox == yes, !, 
	atom_concat(PFile, '_abox.pl', PABoxFile),
	open(PABoxFile, write, Handle),
	current_output(COutput),
	set_output(Handle),
	abox_headers(Options),
	headwrite('Transformed ABox clauses'),
	call_cleanup(transformed_abox(ABoxStr, Indexing, ABox), (close(Handle),set_output(COutput))).
generate_abox0(ABoxStr, _, _, Indexing, ABox) :-
	transformed_abox(ABoxStr, Indexing, ABox).


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Transformations: atomic
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
transformed_abox([], _Indexing, _ABox).
transformed_abox([P-L|Ps], Indexing, ABox) :-
	(
	  L = [_-[*]|_] ->
	  transformed_abox_concept(L, P, ABox)
	;
	  Indexing == yes ->
	  inverses(L, IL),
	  atom_concat('idx_', P, IP),
	  transformed_abox_idx_role(L, P, ABox),
	  transformed_abox_idx_role(IL, IP, ABox)
	;
	  transformed_abox_noidx_role(L, P, ABox)
	),
	transformed_abox(Ps, Indexing, ABox).

transformed_abox_concept([], _, _).
transformed_abox_concept([Value-_|Vs], P, ABox) :-
	functor(Term, P, 1),
	arg(1, Term, Value),
	portray_abox_clause(ABox, Term),
	transformed_abox_concept(Vs, P, ABox).

transformed_abox_noidx_role([], _, _).
transformed_abox_noidx_role([A-Bs|Xs], P, ABox) :-
	transformed_abox_noidx_role0(Bs, A, P, ABox),
	transformed_abox_noidx_role(Xs, P, ABox).

transformed_abox_noidx_role0([], _, _, _).
transformed_abox_noidx_role0([B|Bs], A, P, ABox) :-
	functor(Term, P, 2),
	arg(1, Term, A),
	arg(2, Term, B),
	portray_abox_clause(ABox, Term),
	transformed_abox_noidx_role0(Bs, A, P, ABox).

transformed_abox_idx_role([], _, _).
transformed_abox_idx_role([X-[Y|Ys]|Xs], P, ABox) :-
	portray_index(Ys, Y, P, X, ABox),
	transformed_abox_idx_role(Xs, P, ABox).

portray_index([], B, Name, A, ABox) :-
	!, Head =.. [Name, A, B],
	portray_abox_clause(ABox, Head).
portray_index([B2|Bs], B, Name, A, ABox) :-
	atom_concat(Name, '_', AName),
	atom_concat(AName, A, IdxName),
	Head =.. [Name, A, X],
	functor(Body, IdxName, 1),
	arg(1, Body, X),
	portray_abox_clause(ABox, (Head :- Body)),
	idx_clauses([B,B2|Bs], IdxName, IdxClauses),
	(
	  ABox == yes ->
	  indented_clauses(IdxClauses, ABox)
	;
	  not_indented_clauses(IdxClauses, ABox)
	).

idx_clauses([], _IdxName, []).
idx_clauses([B|Bs], IdxName, [Fact|Clauses]) :-
	functor(Fact, IdxName, 1),
	arg(1, Fact, B),
	idx_clauses(Bs, IdxName, Clauses).

indented_clauses([], _).
indented_clauses([C|Cs], ABox) :-
	write('                                  '),
	portray_clause(C),
	indented_clauses(Cs, ABox).

not_indented_clauses([], _).
not_indented_clauses([C|Cs], ABox) :-
	portray_abox_clause(ABox, C),
	not_indented_clauses(Cs, ABox).

old_inverses(L, TL) :-
	bagof(B-As,
	      bagof(A, edge_in_graph(L, A, B), As),
	      TL).

edge_in_graph(L, A, B) :-
	member(A-Bs, L),
	member(B, Bs).

inverses(L, IL) :-
	transpose(L, [], T),
	sort(T, Ts),
	group_inverses(Ts, IL).

transpose([], Gy, Gy).
transpose([A-Bs|Xs], Gy, T) :-
	transpose0(Bs, A, Gy, NGy),
	transpose(Xs, NGy, T).

transpose0([], _, Gy, Gy).
transpose0([B|Bs], A, Gy, O) :-
	transpose0(Bs, A, [B-A|Gy], O).
	
group_inverses([A-B|As], O) :-
	group_inverses0(As, A, [B], [], O).

group_inverses0([], N, Gy1, Gy2, [N-Gy1|Gy2]).
group_inverses0([A-B|As], N, Gy1, Gy2, O) :-
	(
	  N == A ->
	  group_inverses0(As, A, [B|Gy1], Gy2, O)
	;
	  group_inverses0(As, A, [B], [N-Gy1|Gy2], O)
	).

portray_abox_clause(yes, C) :-
	portray_clause(C).
portray_abox_clause(no, C) :-
	assert(abox:C).

abox_headers(Options) :-
	headers(Options),
	write(':- module(abox,[]).\n').

headers(Env) :-
	datime(datime(Year, Month, Day, Hour, Min, Sec)),
	write('\% Automatically generated by the DLog system.\n'),
	write('\% Budapest University of Technology and Economic (BUTE), 2007.\n'),
	format('\% User defined options: ~p ~n',[Env]),
	format('\% Timestamp: ~d.~d.~d, ~d:~d:~d sec ~n~n',[Year, Month, Day, Hour, Min, Sec]).