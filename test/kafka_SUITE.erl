-module(kafka_SUITE).

-compile(export_all).

-include("espresso.hrl").
-include_lib("common_test/include/ct.hrl").

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
     map
    ].

map(_Config) ->

    SourceOpts = #{topic => source_topic(),
		   partitions => [source_partition()],
		   brokers => broker_list(),
		   config => [{begin_offset, earliest}]},

    SinkOpts = #{topic => sink_topic(),
		 partition => sink_partition(),
		 brokers => broker_list()},

    {ok, Processor} = espresso:new(),
    {ok, Processor} = espresso:add_source(espresso_source_kafka, SourceOpts, Processor),
    {ok, Processor} = espresso:add_sink(espresso_sink_kafka, SinkOpts, Processor),

    ok = espresso:execute(Processor),

    timer:sleep(5000),

    ok.

broker_list() ->
    [{"kafka00.tc3", 80}, {"kafka01.tc3", 80}, {"kafka02", 80}].

source_topic() ->
    <<"espresso-ct-source-1">>.

sink_topic() ->
    <<"espresso-ct-sink-1">>.

source_partition() ->
    0.

sink_partition() ->
    0.
