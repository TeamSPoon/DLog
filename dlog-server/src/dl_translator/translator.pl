:- module(translator,[translate_axioms/2]).

:- use_module(library(lists), [append/3,select/3, member/2]).
:- use_module(dl_to_fol, [axiomsToNNFConcepts/2, def_list/3]).
:- use_module(transitive, [removeTransitive/4]).
:- use_module(saturate, [saturate/3, saturate_partially/4, saturate_cross/4]).
:- use_module(toFOL, [toClause_list/2]).
:- use_module(show).
:- use_module(struct,[omit_structs/3, contains_struct/2]).

% translate_axioms([+CInclusion, +RInclusion, +Transitive],-Clauses):-
% elso argumentum egy harmas lista: [CInclusion, RInclusion, Transitive], mely egy SHIQ KB-t ir le
translate_axioms([CInclusion, RInclusion, Transitive],Clauses):-

	% belsosites es negacios normalformara hozas
	axiomsToNNFConcepts(CInclusion,NNF),
	
	removeTransitive(NNF,RInclusion,Transitive,TransNNF),
	
	% nl,print('NNF'),nl, show(NNF),nl, show(TransNNF), nl,
	
	% strukturalis transzformacio
	def_list(NNF,'n_',Defs),		
	def_list(TransNNF,'trans_',TransDefs),

	append(Defs,TransDefs,AllDefs),
	
	% nl,print('Strukturalis transzformacio utan'),nl, show(AllDefs),nl,

	% szerepeket tartalmazo klozok levalasztasa
	separate(AllDefs,Type1,Rest),

	% klozhalmaz telitese alap-szuperpozicioval
	saturate(Type1,RInclusion,Saturated1),
	
	% nl,print('Elso telites utan'),nl, show(Saturated1),nl,

	saturate(Rest,RInclusion,Saturated2),
	
	% nl,print('Masodik telites utan'),nl, show(Saturated2),nl,

	saturate_cross(Saturated1,Saturated2,RInclusion,Saturated),
	
	% nl,print('Harmadik telites utan'),nl, show(Saturated),nl,	

	omit_structs(Saturated,atleast(_,_,_,_),FunFree),

        % nl,print('Fuggvenyjelek kikuszobolesevel'),nl, show(FunFree),nl,

	toClause_list(FunFree,FOL),

	% nl,print('Elsorendu klozok kepzese'),nl,nl, show(FOL),nl,
	Clauses = FOL.


% szerepeket tartalmazo klozok levalasztasa
separate([],[],[]).
separate([L|Ls],Type1,[L|Rest]):-
	contains_struct(L,arole(_)), !,
	separate(Ls,Type1,Rest).
separate([L|Ls],[L|Type1],Rest):-
	separate(Ls,Type1,Rest).


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

collect(List):-
	collect(List,[aconcept(a),1,skolem]), nl, nl,
	collect(List,[aconcept(a),2,skolem]), nl, nl,
	collect(List,[aconcept(b),1,skolem]), nl, nl,
	collect(List,[aconcept(b),2,skolem]), nl, nl,
	collect(List,[aconcept(c),1,skolem]), nl, nl,
	collect(List,[aconcept(c),2,skolem]), nl, nl,
	collect(List,[aconcept(d),1,skolem]), nl, nl,
	collect(List,[aconcept(d),2,skolem]), nl, nl,
	collect(List,[aconcept(e),1,skolem]), nl, nl,
	collect(List,[aconcept(e),2,skolem]), nl, nl.

collect([],_).
collect([Head|Rest],Sel):-
	theSelected(Head,Sel), !,
	nl, print(Head),
	collect(Rest,Sel).
collect([_|Rest],Sel):-
	collect(Rest,Sel).

theSelected(atleast(_N,_R,_C,Sel),Sel):- !.
%	nl, print(atleast(N,R,C,Sel)).
theSelected(atleast(_N,_R,_C,[Original]),[Original,_,_]):- !.
%	nl, print(atleast(N,R,C,[Original])).
theSelected(or([X|_]),Sel):-
	theSelected(X,Sel).


filter2(L,R):-
	findall(C, (
		     member(C,L),
		     (
		       contains_struct(C,atleast(_,arole('food:hasFood'),aconcept(_),[top]))
%		     ; contains_struct(C,atleast(_,_,_,[aconcept(b)|_]))
		     )
		   ), R
	       ).

filter3(L,R):-
	findall(C, (
		     member(C,L),
		     (
		       contains_struct(C,aconcept('food:EdibleThing'))
		     )
		   ), R
	       ).
