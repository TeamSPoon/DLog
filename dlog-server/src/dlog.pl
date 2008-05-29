:- module(dlog, [
		execute_dig_file/2, %reexported from module dig_iface.
		start_server/0, stop_server/0, %start/stop the server.
		get_dlog_option/2, get_dlog_option/3, %reexported from module config.
		set_dlog_option/2, set_dlog_option/3, %reexported from module config.
		load_config_file/0, load_config_file/1, %reexported from module config.
		create_binary/0 %create the stand-alone binary version of DLog.
	]).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                      STARTUP
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% IMPORTANT: first load the config module, then load the config file, 
%  finally load the rest!
:- use_module('core/config', [target/1,
					get_dlog_option/2, get_dlog_option/3, 
					set_dlog_option/2, set_dlog_option/3,
					load_config_file/0, load_config_file/1]).

%load config at startup
:- initialization load_config_file.

:- use_module('core/kb_manager', [new_kb/1, release_kb/1%, add_axioms/2
			]).
:- use_module('core/console', [console/0]).
:- use_module('interfaces/dig_iface', [execute_dig_file/2]).
:- use_module('core/dlogger', [error/3, warning/3, info/3, detail/3]).

:- target(swi) -> 
	use_module('core/core_swi_tools', [abs_file_name/3]),
	use_module(library('http/thread_httpd')),
	use_module(library('http/http_error.pl')),	%debug modul -> 500 stacktrace-el
	use_module(library('http/http_dispatch')) %hiba kezel�s, t�bb szolg�ltat�s ugyanazon a porton (OWL?)
	; true.

:- target(sicstus) -> 
	use_module('core/core_sicstus_tools', [abs_file_name/3])
	; true.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

:- multifile user:file_search_path/2. 
user:file_search_path(foreign, LP) :- %TODO: include-hoz dlog(...)?
	get_dlog_option(base_path, B),
	get_dlog_option(lib_path, L),
	abs_file_name(L, [relative_to(B)], LP).

:- multifile user:resource/3. %TODO Sicstus
user:resource(dlog_hash, module, 'hash/hash.pl').
user:resource(hash_swi, module, 'hash/hash_swi.pl').


%create the stand-alone binary version of DLog.
create_binary :- 
	get_dlog_option(base_path, B),
	get_dlog_option(binary_name, RN),
	abs_file_name(RN, [relative_to(B)], N),
	qsave_program(N, [
		stand_alone(true), 
		goal(start_dlog), 
		init_file(none),
		toplevel(halt(1))
		% toplevel(prolog) %debug
		% local %stack sizes
		% global
		% trail
		% argument
	]).


%startup goal
start_dlog :-
	info(dlog, start_dlog, 'Starting DLog server...'),
	start_server,
	console.

%start the server.
start_server :-
	get_dlog_option(server_port, Port),
	http_server(http_dispatch, [port(Port), timeout(30)]),
		%TODO: timeout(+SecondsOrInfinite): a k�r�sre mennyit v�rjon, 
		%workers(+N): h�ny sz�l (2)
		%after(:Goal) -> v�lasz ut�n feldolgoz�s/statisztika
		%... (stack m�ret, ssl)
	format(atom(M), 'Server started on port ~d.', Port),
	info(dlog, start_server, M).

%stop the server.
stop_server :- 
	get_dlog_option(server_port, Port), %TODO: mi van, ha v�ltoztattak rajta?
	http_stop_server(Port, _Options), %TODO: exception
	format(atom(M), 'Server stopped on port ~d.~n', Port),
	info(dlog, stop_server, M).
	


