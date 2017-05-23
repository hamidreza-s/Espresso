-module(espresso_source_file).
-behaviour(espresso_source).

-export([run/2]).

-include("espresso.hrl").

-spec run(map(), espresso_processor()) -> ok.
run(Opts, Processor) ->
    Path = maps:get(path, Opts),
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
	    ok
    end.
