-module(espresso_sink_kafka).
-behaviour(espresso_sink).

-export([run/2]).
-export([write/3]).

-include("espresso.hrl").
-include_lib("eunit/include/eunit.hrl").

-spec run(map(), espresso_processor()) -> ok.
run(_, _) ->
    ok.

-spec write(espresso_element(), map(), pid()) -> ok.
write(_, _, _) ->
    ok.
