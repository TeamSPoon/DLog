:- module(dlog_test, [execute_tests/2, execute_test_files/2, read_test_file/4]).

:- use_module('../core/config', [target/1, set_dlog_options/2]).
:- use_module('../core/kb_manager', [new_kb/1, release_kb/1, add_axioms/2, run_query/3]).
:- use_module('../core/dlogger', [warning/3, info/3, detail/3]).
:- use_module(dlog_test_outputs).
%TODO: dlogtest, test modules

:- target(swi) -> 
	use_module(dlog_test_swi_tools, [time_limit/2, time_limit/3, call_with_time_limit/2])
	; true.
:- target(sicstus) -> use_module(dlog_test_sicstus_tools, 
		[time_limit/2, time_limit/3, expand_file_name/2, setup_and_call_cleanup/3, call/2]) ; true.

%execute_test_files(+Files, ?Output),
%execute_test_files(+Files, +Output): 
%  Files is either a list of files or an atom. 
%  The atom is passed to expand_file_name/2 in SWI, 
%  while in Sicstus it must be a directory name, and all files ending 
%  in '.tst' in that directory are used.
%  If Output is unifiable with the results (a list), it is unified with the results.
%  Other output modes are
%    text: Results are pretty printed on current output.
%    text(Out): Results are pretty printed using Out as output. Out can be a file name or stream(Stream).
%    If Output is call(Goal), Goal is called with Results appended as last argument.
execute_test_files(Files, Output) :-
	(	atom(Files) 
	->	expand_file_name(Files, List)
	;	List = Files
	),
	execute_test_file(List, Results),
	output_results(Output, Results).

execute_test_file([], []).
execute_test_file([File|Files], [Result|Results]) :-
	execute_tests(File, Result),
	execute_test_file(Files, Results).

%output_results(Output, Results): Output defines the way to portray Results.
%  If Output is unifiable with Results, it is unified with Results. 
%  Defined output modes:
%    text: Results are pretty printed on current output.
%    text(Out): Results are pretty printed using Out as output. Out can be a file name or stream(Stream).
%    If Output is call(Goal), Goal is called with Results appended as last argument.
output_results(Output, Result) :- Output = Result, !. %unify and cut if successful
output_results(call(Goal), Results) :-
	call(Goal, Results).
output_results(text, Results) :-
	pretty_print(Results).
output_results(text(Out), Results) :-
	pretty_print(Results, Out).
output_results(html, Results) :-
	html_print(Results).
output_results(html(Out), Results) :-
	html_print(Results, Out).
output_results(xml, Results) :-
	xml_print(Results).
output_results(xml(Out), Results) :-
	xml_print(Results, Out).
output_results(latex, Results) :-
	latex_print(Results).
output_results(latex(Out), Results) :-
	latex_print(Results, Out).


% :- type results == list(results1).
% :- type results1 ---> results(fileName, readTime, result, fTotalTime).
% :- type result ---> 
%        success(list(result1)) | 
%        fail | exception(univ) | time_out. % read failure/error
% :- type result1 ---> result(options, compileTime, query, totalTime).
% :- type query ---> 
%        success(list(query1)) | 
%        fail | exception(univ) | time_out. % compile failure/error
% :- type query1 ---> query(queryType, queryTime, queryResult, checkTime).
% :- type queryType ---> 
%        instances(conceptTerm) | instance(iName, conceptTerm) | 
%        roleFillers(iName, roleTerm) | 
%        relatedIndividuals(roleTerm). 
%       %| allConceptNames | allRoleNames | allIndividuals.
% :- type queryResult ---> 
%        pass | 
%        fail(answer, desired) | % wrong answer
%        fail | exception(univ) | time_out. % query failure/error
% :- type answer ---> 
%        true | false | 
%        individualSet(list(atom)) |
%        individualPairSet(list(pair(atom, atom))). 
%      %| conceptSet(list(list(atom))) | roleSet(list(list(atom))).
% :- type desired.
% %		---> 
% %       true | false | 
% %       list(atom) | 
% %       list(pair(atom, atom)).
% %      %| list(list(atom)) | list(list(atom)).
% :- type fileName == atom.
% :- type readTime == integer. %milliseconds
% :- type fTotalTime == integer. %milliseconds
% :- type compileTime == integer. %milliseconds
% :- type iName == atom.
% :- type conceptTerm.
% :- type roleTerm.
% :- type queryTime == integer. %milliseconds
% :- type checkTime == integer. %milliseconds
% :- type totalTime == integer. %milliseconds
% :- type options == list(option).
% :- type option. %name(value)

execute_tests(File, results(File, ReadTime, Result, FTotal)) :-
	info(dlog_test, execute_tests(File, ...), 'Processing file:'),
	statistics(runtime, [StartTime, _]),
	try(read_test_file(File, Axioms, Queries, Options), 'reading file.', RResult),
	statistics(runtime, [MidTime, _]), 
	ReadTime is MidTime - StartTime,
	(	RResult == success 
	->	detail(dlog_test, execute_tests(File, ...), 'File loaded.'),
		Result = success(Result1),
		(	Options == []
		->	execute_test([[]], Axioms, Queries, Result1) %use default options only
		;	execute_test(Options, Axioms, Queries, Result1) % use user-specified option sets
		)
	;	Result = RResult
	),
	statistics(runtime, [EndTime, _]),
	info(dlog_test, execute_tests(File, ...), 'File complete.'),
	FTotal is EndTime - StartTime.

execute_test([], _Axioms, _Queries, []).
execute_test([Opt|Options], Axioms, Queries, [result(Opt, CompileTime, QRes, Total) | Results]) :-
	info(dlog_test, execute_test([Opt|...], ...), 'Using options: '),
	statistics(runtime, [StartTime, _]),
	
	new_kb(URI),
	set_dlog_options(Opt, URI),
	try(add_axioms(URI, Axioms), URI, 'adding axioms.', CResult),
	
	statistics(runtime, [MidTime, _]),
	CompileTime is MidTime - StartTime,
	
	(	CResult == success 
	->	QRes = success(QRes1),
		run_queries(Queries, URI, QRes1)
	;	QRes = CResult
	),
	release_kb(URI),
	
	statistics(runtime, [EndTime, _]),
	Total is EndTime - StartTime,
	execute_test(Options, Axioms, Queries, Results).


run_queries([], _URI, []).
run_queries([query(Query, Desired)|Queries], URI, [query(Query, QueryTime, Result, CheckTime)| Results]) :-
	info(dlog_test, run_queries([query(Query, ...)|...], ...), 'Running query: '), 
	statistics(runtime, [StartTime, _]), 
	try(run_query(URI, Query, Answer), URI, 'running query.', QResult), 
	statistics(runtime, [MidTime, _]), 
	QueryTime is MidTime - StartTime, 
	(	QResult == success
	->	(	correct_results(Answer, Desired)
		->	Result = pass
		;	Result = fail(Answer, Desired),
			warning(dlog_test, run_queries(Query, URI, _), 'Wrong answer.')
		)
	;	Result = QResult
	),
	statistics(runtime, [EndTime, _]),
	CheckTime is EndTime - MidTime,
	run_queries(Queries, URI, Results).

correct_results(true, true).
correct_results(false, false).
correct_results(individualSet(Answer), Response) :-
	sort(Answer, Sorted), 
	length(Response, L),
	length(Sorted, L),
	sort(Response, Sorted).
correct_results(individualPairSet(Answer), Response) :-
	sort(Answer, Sorted),
	length(Response, L),
	length(Sorted, L),
	sort(Response, Sorted).
%TODO
% conceptSet(_Answer)
% roleSet(_Answer)


% try(:Goal, +Description, -Result): robust execution of Goal. 
%   Prints warnings if not successful.
%   Result --> succes | time_out | fail | exception(term)
try(Goal, Description, Result) :-
	(	catch(
			time_limit(Goal, Result),
			E, 
			(
				E == '$aborted'
			->	throw(E)
			;	atom_concat('Exception while ', Description, Msg), 
				warning(dlog_test, (try(Goal) -> E), Msg), 
				Result = exception(E)
			)
		) 
	->	(	Result == time_out
		->	atom_concat('Time limit exceeded while ', Description, Msg), 
			warning(dlog_test, try(Goal), Msg)
		;	true
		)
	;	atom_concat('Failed while ', Description, Msg), 
		warning(dlog_test, try(Goal), Msg), 
		Result = fail
	).

try(Goal, URI, Description, Result) :-
	(	catch(
			time_limit(Goal, URI, Result),
			E, 
			(
				E == '$aborted'
			->	throw(E)
			;	atom_concat('Exception while ', Description, Msg), 
				warning(dlog_test, (try(Goal, URI) -> E), Msg), 
				Result = exception(E)
			)
		) 
	->	(	Result == time_out
		->	atom_concat('Time limit exceeded while ', Description, Msg), 
			warning(dlog_test, try(Goal, URI), Msg)
		;	true
		)
	;	atom_concat('Failed while ', Description, Msg), 
		warning(dlog_test, try(Goal, URI), Msg), 
		Result = fail
	).



%%%%%%%%%%%%%%%%%%%    Call file    %%%%%%%%%%%%%%%%%%%%%%%%

%call_test_file(+File, -Axioms, -Queries, -Options)
call_test_file(A, Axioms, Queries, Options) :-
		call_store(A, test(axioms([], [], [], [], [], [], [], []), [], []), test(Axioms, Queries, Options)).

call_store(A,In,Out):- store_0(A,In,Out),!.
call_store(Unknown, 
          test(axioms(ImpliesCL, ImpliesRL, TransL, ABox, Concepts, Roles, DBConnections, DBPredicates), Queries, Options), 
	  test(axioms(ImpliesCL, ImpliesRL, TransL, ABox, Concepts, Roles, DBConnections, DBPredicates), Queries, Options)) 
		:- !,format('%% ERROR: ~q. ~n',unknown_store_element(Unknown)).



%%%%%%%%%%%%%%%%%%%    Read file    %%%%%%%%%%%%%%%%%%%%%%%%

%read_test_file(+File, -Axioms, -Queries, -Options)
read_test_file(File, Axioms, Queries, Options) :-
	setup_and_call_cleanup(
		open(File, read, Str),
		read_test(Str, 
			test(axioms([], [], [], [], [], [], [], []), [], []),
			test(Axioms, Queries, Options)),
		close(Str)
	).

read_test(Str) -->
	{read(Str, A)},
	(	{A == end_of_file}
	->	[]
	;	store(A),
		read_test(Str)
	).


%TODO: better (detailed) syntax check?
store(A,In,Out):- store_0(A,In,Out).
store(Unknown, _, _) :- throw(unknown_element(Unknown)).


store_0(concept(C), 
		test(axioms(ImpliesCL, ImpliesRL, TransL, ABox, Concepts, Roles, DBConnections, DBPredicates), Queries, Options), 
		test(axioms(ImpliesCL, ImpliesRL, TransL, ABox, [C|Concepts], Roles, DBConnections, DBPredicates), Queries, Options)) 
		:- !.
store_0(concepts(CL), 
		test(axioms(ImpliesCL, ImpliesRL, TransL, ABox, Concepts, Roles, DBConnections, DBPredicates), Queries, Options), 
		test(axioms(ImpliesCL, ImpliesRL, TransL, ABox, Concepts1, Roles, DBConnections, DBPredicates), Queries, Options)) 
		:- append(Concepts, CL, Concepts1), !.
store_0(role(R), 
		test(axioms(ImpliesCL, ImpliesRL, TransL, ABox, Concepts, Roles, DBConnections, DBPredicates), Queries, Options), 
		test(axioms(ImpliesCL, ImpliesRL, TransL, ABox, Concepts, [R|Roles], DBConnections, DBPredicates), Queries, Options))
		:- !.
store_0(roles(RL), 
		test(axioms(ImpliesCL, ImpliesRL, TransL, ABox, Concepts, Roles, DBConnections, DBPredicates), Queries, Options), 
		test(axioms(ImpliesCL, ImpliesRL, TransL, ABox, Concepts, Roles1, DBConnections, DBPredicates), Queries, Options))
		:- append(Roles, RL, Roles1), !.
store_0(implies(C1, C2), 
		test(axioms(ImpliesCL, ImpliesRL, TransL, ABox, Concepts, Roles, DBConnections, DBPredicates), Queries, Options), 
		test(axioms([implies(C1, C2)| ImpliesCL], ImpliesRL, TransL, ABox, Concepts, Roles, DBConnections, DBPredicates), Queries, Options)) 
		:- !.
store_0(equiv(C1, C2), 
		test(axioms(ImpliesCL, ImpliesRL, TransL, ABox, Concepts, Roles, DBConnections, DBPredicates), Queries, Options), 
		test(axioms([implies(C1, C2), implies(C2, C1)| ImpliesCL], ImpliesRL, TransL, ABox, Concepts, Roles, DBConnections, DBPredicates), 
				Queries, Options)) :- !.
store_0(subrole(R, S), 
		test(axioms(ImpliesCL, ImpliesRL, TransL, ABox, Concepts, Roles, DBConnections, DBPredicates), Queries, Options), 
		test(axioms(ImpliesCL, [subrole(R, S)|ImpliesRL], TransL, ABox, Concepts, Roles, DBConnections, DBPredicates), Queries, Options))
		:- !.
store_0(transitive(R), 
		test(axioms(ImpliesCL, ImpliesRL, TransL, ABox, Concepts, Roles, DBConnections, DBPredicates), Queries, Options), 
		test(axioms(ImpliesCL, ImpliesRL, [R|TransL], ABox, Concepts, Roles, DBConnections, DBPredicates), Queries, Options)) 
		:- !.
store_0(assertion(R, I1, I2), 
		test(axioms(ImpliesCL, ImpliesRL, TransL, ABox, Concepts, Roles, DBConnections, DBPredicates), Queries, Options), 
		test(axioms(ImpliesCL, ImpliesRL, TransL, [rassertion(R, I1, I2)|ABox], Concepts, Roles, DBConnections, DBPredicates), Queries, Options))
		 :- !.
store_0(rassertion(R, I1, I2), 
		test(axioms(ImpliesCL, ImpliesRL, TransL, ABox, Concepts, Roles, DBConnections, DBPredicates), Queries, Options), 
		test(axioms(ImpliesCL, ImpliesRL, TransL, [rassertion(R, I1, I2)|ABox], Concepts, Roles, DBConnections, DBPredicates), Queries, Options)) 
		:- !. 
store_0(assertion(C, I), 
		test(axioms(ImpliesCL, ImpliesRL, TransL, ABox, Concepts, Roles, DBConnections, DBPredicates), Queries, Options), 
		test(axioms(ImpliesCL, ImpliesRL, TransL, [cassertion(C, I)|ABox], Concepts, Roles, DBConnections, DBPredicates), Queries, Options)) 
		:- !.
store_0(cassertion(C, I), 
		test(axioms(ImpliesCL, ImpliesRL, TransL, ABox, Concepts, Roles, DBConnections, DBPredicates), Queries, Options), 
		test(axioms(ImpliesCL, ImpliesRL, TransL, [cassertion(C, I)|ABox], Concepts, Roles, DBConnections, DBPredicates), Queries, Options)) 
		:- !.
store_0(dbConnection(Connection, DSN, User, Pass), 
		test(axioms(ImpliesCL, ImpliesRL, TransL, ABox, Concepts, Roles, DBConnections, DBPredicates), Queries, Options), 
		test(axioms(ImpliesCL, ImpliesRL, TransL, ABox, Concepts, Roles, [connection(Connection, DSN, User, Pass)|DBConnections], DBPredicates), 
			Queries, Options)) :- !.
store_0(dbConnection(Connection, DSN), 
		test(axioms(ImpliesCL, ImpliesRL, TransL, ABox, Concepts, Roles, DBConnections, DBPredicates), Queries, Options), 
		test(axioms(ImpliesCL, ImpliesRL, TransL, ABox, Concepts, Roles, [connection(Connection, DSN, _User, _Pass)|DBConnections], DBPredicates), 
			Queries, Options)) :- !. 
store_0(dbAccess(Functor, Connection, Access), 
		test(axioms(ImpliesCL, ImpliesRL, TransL, ABox, Concepts, Roles, DBConnections, DBPredicates), Queries, Options), 
		test(axioms(ImpliesCL, ImpliesRL, TransL, ABox, Concepts, Roles, DBConnections, [access(Functor, Connection, Access)|DBPredicates]), 
			Queries, Options)) :- !.
store_0(query(Q, Response), 
		test(Axioms, Queries, Options), 
		test(Axioms, [query(Q, Response)|Queries], Options)) :- !.
store_0(query(Q), %Q=instance(Indiv,Concept)
		test(Axioms, Queries, Options), 
		test(Axioms, [query(Q, true)|Queries], Options)) :- !.
store_0(options(O), 
		test(Axioms, Queries, Options), 
		test(Axioms, Queries, [O|Options])) :- !.

