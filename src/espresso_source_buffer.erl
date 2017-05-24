-module(espresso_source_buffer).
-behaviour(espresso_source).

-export([run/2]).

-include("espresso.hrl").
-include_lib("eunit/include/eunit.hrl").

-spec run(map(), espresso_processor()) -> ok.
run(Opts, Processor) ->
    TableID = maps:get(table, Opts),
    ets:foldl(fun({Element}, _) ->
		      {ok, Processor} = espresso_processor:process(Element, Processor)
	      end,
	      undefined,
	      TableID),
    {ok, Processor} = espresso_processor:done(Processor),
    ok.
