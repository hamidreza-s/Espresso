-module(espresso_sink_file).
-behaviour(espresso_sink).

-export([run/2]).
-export([write/3]).

-include("espresso.hrl").
-include_lib("eunit/include/eunit.hrl").

-spec run(map(), espresso_processor()) -> ok.
run(Opts, Processor) ->
    Path = maps:get(path, Opts),
    {ok, File} = file:open(Path, [write, binary]),
    do_run(File, Processor).

do_run(File, Processor) ->
    receive
	{write, Element} ->
	    ElementBin = espresso_utils:to_binary(Element),
	    ElementLine = <<ElementBin/binary, "\n">>,
	    ok = file:write(File, ElementLine),
	    do_run(File, Processor);
	_ ->
	    do_run(File, Processor)
    end.

-spec write(espresso_element(), map(), pid()) -> ok.
write(Element, _Opts, SinkPID) ->
    SinkPID ! {write, Element},
    ok.
