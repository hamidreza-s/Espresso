-module(espresso_sink_kafka).
-behaviour(espresso_sink).

-export([run/2]).
-export([write/3]).

-include("espresso.hrl").
-include_lib("eunit/include/eunit.hrl").

-define(CLIENT_NAME, ?MODULE).

-spec run(map(), espresso_processor()) -> ok.
run(Opts, Processor) ->
    Topic = maps:get(topic, Opts),
    Partition = maps:get(partition, Opts, 0),
    Brokers = maps:get(brokers, Opts, [{"localhost", 9092}]),
    Config = maps:get(config, Opts, []),

    Client = ?CLIENT_NAME,

    ok = brod:start_client(Brokers, Client),
    ok = brod:start_producer(Client, Topic, Config),

    do_run(Client, Topic, Partition, Processor).

do_run(Client, Topic, Partition, Processor) ->
    receive
	{write, Element} ->
	    ElementBin = espresso_utils:to_binary(Element),
	    ok = brod:produce_sync(Client, Topic, Partition, <<>>, ElementBin),
	    do_run(Client, Topic, Partition, Processor);
	_ ->
	    do_run(Client, Topic, Partition, Processor)
    end.

-spec write(espresso_element(), map(), pid()) -> ok.
write(Element, _Opts, SinkPID) ->
    SinkPID ! {write, Element},
    ok.
