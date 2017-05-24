-module(espresso_sink_buffer).
-behaviour(espresso_sink).

-export([run/2]).
-export([write/3]).

-include("espresso.hrl").
-include_lib("eunit/include/eunit.hrl").

-spec run(map(), espresso_processor()) -> ok.
run(Opts, Processor) ->
    TableID = maps:get(table, Opts),
    do_run(TableID, Processor).

do_run(TableID, Processor) ->
    receive
	{write, Element} ->
	    ElementBin = espresso_utils:to_binary(Element),
	    true = ets:insert(TableID, {ElementBin}),
	    do_run(TableID, Processor);
	_ ->
	    do_run(TableID, Processor)
    end.

-spec write(espresso_element(), map(), pid()) -> ok.
write(Element, _Opts, SinkPID) ->
    SinkPID ! {write, Element},
    ok.
