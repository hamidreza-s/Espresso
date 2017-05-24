-module(espresso_source_kafka).
-behaviour(espresso_source).

-export([run/2]).

-include("espresso.hrl").
-include_lib("eunit/include/eunit.hrl").
-include_lib("brod/include/brod.hrl").

-define(CLIENT_NAME, ?MODULE).

-spec run(map(), espresso_processor()) -> ok.
run(Opts, Processor) ->
    Topic = maps:get(topic, Opts),
    Partitions = maps:get(partitions, Opts, 0),
    Brokers = maps:get(brokers, Opts, [{"localhost", 9092}]),
    Config = maps:get(config, Opts, [{begin_offset, earliest}]),
    CommittedOffsets = maps:get(committed_offsets, Opts, []),
    Timeout = maps:get(timeout, Opts, 1000),

    InitCallbackState = self(),
    Client = ?CLIENT_NAME,

    ok = brod:start_client(Brokers, Client),

    SubscriberCallbackFun = fun(_Partition, Msg, SourcePid = CallbackState) ->
				    SourcePid ! Msg,
				    {ok, ack, CallbackState}
			    end,

    brod_topic_subscriber:start_link(Client, Topic, Partitions, Config, CommittedOffsets,
				     SubscriberCallbackFun, InitCallbackState),



    do_run(Timeout, Processor).

do_run(Timeout, Processor) ->
    receive
	Message ->
	    Element = Message#kafka_message.value,
	    {ok, Processor} = espresso_processor:process(Element, Processor),
	    do_run(Timeout, Processor)
    after
	Timeout -> ok
    end.
