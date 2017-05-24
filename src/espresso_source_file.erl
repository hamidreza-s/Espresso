-module(espresso_source_file).
-behaviour(espresso_source).

-export([run/2]).

-include("espresso.hrl").
-include_lib("eunit/include/eunit.hrl").

-spec run(map(), espresso_processor()) -> ok.
run(Opts, Processor) ->
    Path = maps:get(path, Opts),
    ok = wait_for(Path),
    {ok, File} = file:open(Path, [read, binary]),
    do_run(File, Processor).

do_run(File, Processor) ->
    case file:read_line(File) of
	{ok, RawElement} ->
	    Element = binary:replace(RawElement, <<"\n">>, <<>>),
	    {ok, Processor} = espresso_processor:process(Element, Processor),
	    do_run(File, Processor);
	eof ->
	    {ok, Processor} = espresso_processor:done(Processor),
	    file:close(File),
	    ok
    end.

-spec wait_for(string()) -> ok.
wait_for(Path) ->
    case file:read_file_info(Path) of
	{error, enoent} ->
	    timer:sleep(100),
	    wait_for(Path);
	_ ->
	    ok
    end.
