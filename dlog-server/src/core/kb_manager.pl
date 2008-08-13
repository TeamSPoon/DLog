:- module(kb_manager, [
					new_kb/1, release_kb/1, add_axioms/2, run_query/3,
					default_kb/1, clear_kb/1,
					with_read_lock/2, with_write_lock/2
					]).

:- use_module(library(lists)).

:- use_module('../dl_translator/axioms_to_clauses', [axioms_to_clauses/6]).
:- use_module('../prolog_translator/abox_signature', [abox_signature/3]).
:- use_module('../prolog_translator/abox_translator', [abox2prolog/2]).
:- use_module('../prolog_translator/tbox_translator', [tbox2prolog/3]).
:- use_module(dlogger, [info/3, detail/3]).
:- use_module(query, [query/4]).
:- use_module(config, [target/1, default_kb/1, kb_uri/2, 
				get_dlog_option/3, remove_dlog_options/1,
				abox_module_name/2, tbox_module_name/2, 
				abox_file_name/2, tbox_file_name/2]).


:- target(swi) -> 
	use_module(library(memfile)),
	use_module(core_swi_tools, [datime/1]),
	use_module(library(listing), [portray_clause/1])
	; true.
:- target(sicstus) -> 
	use_module(library(system), [datime/1]),
	use_module(core_sicstus_tools, [mutex_create/1, with_mutex/2, mutex_lock/1, mutex_unlock/1]),
	use_module(library(system), [delete_file/2]),
	use_module('../hash/dlog_hash', [])
	; true.


:- dynamic current_kb/1,
			kb_count/1.

:- volatile current_kb/1,
			kb_count/1.

:- initialization
		detail(kb_manager, initialization, 'KB manager initializing...'),
		assert(kb_count(1)), 
		default_kb(Def), 
		mutex_create(kb_count), 
		mutex_create(Def),
		assert(current_kb(Def)),
		info(kb_manager, initialization, 'KB manager initialized.').


exists_kb(URI) :-
	nonvar(URI),
	current_kb(URI) -> true
	; throw(no_such_kb).

new_kb(URI) :- 
	with_mutex(kb_count,
	(
		retract(kb_count(ID)),
		ID1 is ID+1, %{<sorszám>|<UUID>}?
		assert(kb_count(ID1))
	)),
	kb_uri(ID, URI),
	mutex_create(URI),
	assert(current_kb(URI)),
	info(kb_manager, new_kb(URI), 'New KB created.').

release_kb(URI) :-
	with_write_lock(URI,
	(
		clear_kb(URI),
		remove_dlog_options(URI), %remove KB-specific options
		retract(current_kb(URI))
	)),
	%,mutex_destroy(URI) %TODO
	info(kb_manager, release_kb(URI), 'KB released.').

clear_kb(URI) :- 
	with_write_lock(URI,
	(
		tbox_module_name(URI, TB),
		abox_module_name(URI, AB),
		abolish_module(AB),
		abolish_module(TB)
		%, remove_dlog_options(URI) %TODO: remove options? -> only for default kb?
	)),
	info(kb_manager, clear_kb(URI), 'KB cleared.').

abolish_module(Module) :-
	current_predicate(Module:P),
	%\+ predicate_property(AB:AP, built_in),
	%\+ predicate_property(AB:AP, imported_from(_Module)),
	%\+ predicate_property(AB:AP, transparent),
	%what can't be removed, stayes there
	catch(abolish(Module:P), error(permission_error(_,_,_),_), fail),
	fail.
abolish_module(_Module).

add_axioms(URI, axioms(ImpliesCL, ImpliesRL, TransL, ABox)) :- %TODO: eltárolni, hozzáadni
	info(kb_manager, add_axioms(URI, ...), 'Adding axioms to KB.'),
	detail(kb_manager, add_axioms(URI, axioms(ImpliesCL, ImpliesRL, TransL, ABox)), 'Axioms:'),
	exists_kb(URI),
	axioms_to_clauses(URI, [ImpliesCL, ImpliesRL, TransL],
			  TBox_Clauses, IBox, HBox, _), %TODO
	detail(kb_manager, add_axioms(URI, ...), 'Clauses ready.'),
	abox_signature(ABox, ABoxStr, Signature),
	detail(kb_manager, add_axioms(URI, ...), 'ABox signature ready.'),
	get_dlog_option(abox_target, URI, ATarget),
	get_dlog_option(tbox_target, URI, TTarget),
	with_write_lock(URI, 
	(	
		add_abox(ATarget, URI, abox(ABoxStr)),
		detail(kb_manager, add_axioms(URI, ...), 'ABox done.'),
		add_tbox(TTarget, URI, tbox(TBox_Clauses, IBox, HBox), abox(Signature))
	)),
	info(kb_manager, add_axioms(URI, ...), 'Axioms added to KB.').


add_abox(assert, URI, ABox) :- !,
	abox2prolog(URI, ABox). %TODO: finalize dynamic? (SWI)
add_abox(Target, URI, ABox) :-
	(	Target == tempfile,
		target(swi)
	->	new_memory_file(File),
		open_memory_file(File, write, Stream)
	;	abox_file_name(URI, File),
		open(File, write, Stream)
	),	
	current_output(Out),
	call_cleanup(
	(
		set_output(Stream),
		call_cleanup(
			abox2prolog(URI, ABox), %TODO 
			(set_output(Out), close(Stream))
		),
		(	Target == tempfile,
			target(swi)
		->	open_memory_file(File, read, Stream2),
			abox_module_name(URI, AB),
			call_cleanup(
				load_files(AB, [stream(Stream2)]), %TODO
				close(Stream2)
			)
		;	load_files(File, []) %TODO
		)
	),
	(
		(	Target == tempfile
		->	(	target(swi)
			->	free_memory_file(File)
			;	delete_file(File, [])
			)
		;	true
		)
	)).


add_tbox(assert, URI, TBox, ABox) :- !,
	%throw(not_implemented), %TODO
	tbox2prolog(URI, TBox, ABox). %TODO: finalize dynamic? (SWI)
add_tbox(allinonefile, URI, TBox, ABox) :-
	current_output(Out),
	setup_and_call_cleanup( %todo: 2 call_cleanup
		(	tbox_file_name(URI, FileName),
			open(FileName, write, Stream),
			set_output(Stream)
		),
		(
			write_tbox_header(URI),
			tbox2prolog(URI, TBox, ABox)
		), 
		(set_output(Out), close(Stream))
	),
	load_files(FileName, []).
%%add_tbox(Target, URI, TBox, ABox) :-
add_tbox(tempfile, URI, TBox, ABox) :-
	setup_and_call_cleanup(
		( %setup file
			tbox_file_name(URI, FileName),
			(	%%Target == tempfile,
				target(swi)
			->	new_memory_file(MemFile)
			;	true
			)
		),
		( %call (main body)
			current_output(Out),
			setup_and_call_cleanup(
				( %setup output stream
					(	%%Target == tempfile,
						target(swi)
					->	open_memory_file(MemFile, write, Stream)
					;	open(FileName, write, Stream)
					)
				),
				setup_and_call_cleanup( % write TBox
					set_output(Stream),
					(
						write_tbox_header(URI),
						tbox2prolog(URI, TBox, ABox)
					),
					set_output(Out)
				), 
				close(Stream)
			),
			(	%load TBox
				%%Target == tempfile,
				target(swi)
			->	%tbox_module_name(URI, TB),
				setup_and_call_cleanup(
					open_memory_file(MemFile, read, Stream2),
					load_files(FileName, [stream(Stream2)]), %TODO
					close(Stream2)
				)
			;	load_files(FileName, []) %TODO
			)
		),
		( %cleanup temp file
			%%(	Target == tempfile
			%%->	
				(	target(swi)
				->	free_memory_file(MemFile)
				;	delete_file(FileName, [])
				)
			%%;	true
			%%)
		)
	).


run_query(URI, Query, Answer) :- 
	info(kb_manager, run_query(URI, ...), 'Querying KB.'),
	detail(kb_manager, run_query(URI, Query, ...), 'Query:'),
	with_read_lock(URI,
	(
		tbox_module_name(URI, TBox),
		abox_module_name(URI, ABox),
		query(Query, TBox, ABox, Answer)
	)),
	detail(kb_manager, run_query(URI, Query, Answer), 'Query results:').


write_tbox_header(URI) :-
	datime(datime(Year, Month, Day, Hour, Min, Sec)),
	write('\% Automatically generated by the DLog system.\n'),
	write('\% Budapest University of Technology and Economic (BME), 2007-2008.\n'),
	format('\% User defined options: ~p ~n',[todo]), %TODO
	format('\% Timestamp: ~d.~d.~d, ~d:~d:~d sec ~n~n',[Year, Month, Day, Hour, Min, Sec]),
	tbox_module_name(URI, MName),
	format(':- module(\'~w\',[]).\n',[MName]),

	write('\n% ************************\n'),
	write(  '% Header\n'),
	write(  '% ************************\n\n'),
	portray_clause((
		sicstus_init :-
			use_module(library(lists), [member/2]),
			use_module(dlog_hash, dlog_hash, [init_state/1,new_state/3,new_anc/3,new_loop/3,check_anc/2,check_loop/2])
			)),
	nl,
	portray_clause((
		swi_init :-
			open_resource(dlog_hash, module, H)
			->
			call_cleanup(
				load_files(dlog_hash, [stream(H)]),
				close(H)
			),
			import(lists:member/2)
			;
			use_module(dlog_hash),
			use_module(library(lists), [member/2])
		)),
	nl,
	portray_clause((
		:- current_predicate(config:target/1)
			->
			(config:target(sicstus) -> sicstus_init ; true),
			(config:target(swi) -> swi_init ; true)
			;
			(current_prolog_flag(dialect, swi) -> swi_init
			; %current_prolog_flag(language, sicstus) %sicstus/iso
			sicstus_init)
		)),
	nl.


get_read_lock(URI) :-
	exists_kb(URI), %don't create mutex if not exists
	mutex_lock(URI),
	exists_kb(URI). %check if still existing
get_write_lock(URI) :-
	exists_kb(URI), 
	mutex_lock(URI),
	exists_kb(URI).
release_read_lock(URI) :-
	mutex_unlock(URI).
release_write_lock(URI) :-
	mutex_unlock(URI).
with_read_lock(URI, Goal) :-
	exists_kb(URI), 
	with_mutex(URI, (exists_kb(URI),Goal)).
with_write_lock(URI, Goal) :-
	exists_kb(URI), 
	with_mutex(URI, (exists_kb(URI),Goal)).
