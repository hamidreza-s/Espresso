-module(common_SUITE).

-compile(export_all).

-include_lib("common_test/include/ct.hrl").

-define(LOG(Format, Args), ct:print(default, ?STD_IMPORTANCE, Format, Args)).

suite() ->
    [{timetrap,{seconds,30}}].

init_per_suite(Config) ->

    {ok, _} = application:ensure_all_started(brod),

    Config.

end_per_suite(_Config) ->
    ok.

init_per_group(_GroupName, Config) ->
    Config.

end_per_group(_GroupName, _Config) ->
    ok.

init_per_testcase(_TestCase, Config) ->
    Config.

end_per_testcase(_TestCase, _Config) ->
    ok.

groups() ->
    [].

all() ->
    [
     test_producer,
     test_consumer
    ].

test_producer(_Config) ->

    Client = test_producer_client,
    Endpoints = broker_list(),
    Topic = topic_name(),
    Partition = 0,
    ProducerConfig = [],

    ok = brod:start_client(Endpoints, Client),
    ok = brod:start_producer(Client, Topic, ProducerConfig),

    lists:foreach(fun(_) ->
			  ok = brod:produce_sync(Client, Topic, Partition, <<"key">>, integer_to_binary(erlang:system_time()))
		  end,
		  lists:seq(1, 2)),

    ok.

test_consumer(_Config) ->

    Client = test_consumer_client,
    Endpoints = broker_list(),
    Topic = topic_name(),
    Partition = 0,
    Partitions = [Partition],
    ConsumerConfig = [{begin_offset, earliest}],
    CommittedOffsets = [],
    InitCallbackState = self(),

    ok = brod:start_client(Endpoints, Client),

    SubscriberCallbackFun = fun(_Partition, Msg, ShellPid = CallbackState) ->
				    ShellPid ! Msg,
				    {ok, ack, CallbackState}
			    end,

    brod_topic_subscriber:start_link(Client, Topic, Partitions, ConsumerConfig, CommittedOffsets,
				     SubscriberCallbackFun, InitCallbackState),


    do_test_consumer().
do_test_consumer() ->
    receive
	Msg ->
	    ?LOG("--- new msg: ~p", [Msg]),
	    do_test_consumer()
    after
	5000 -> ok
    end.

broker_list() ->
    [{"kafka00.tc3", 80}, {"kafka01.tc3", 80}, {"kafka02", 80}].

topic_name() ->
    <<"my-replicated-topic">>.
