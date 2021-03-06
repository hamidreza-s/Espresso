-module(espresso).

-export([new/0]).
-export([add_source/3]).
-export([add_sink/3]).
-export([execute/1]).
-export([chain/3]).
-export([map/2]).
-export([reduce/2]).

-include("espresso.hrl").
-include_lib("eunit/include/eunit.hrl").

%%%===================================================================
%%% API
%%%===================================================================

-spec new() -> {ok, espresso_processor()}.
new() ->
    espresso_processor:start().

-spec add_source(module(), map(), espresso_processor()) -> {ok, espresso_processor()}.
add_source(Module, Opts, Processor) ->
    Source = #espresso_source{module = Module, opts = Opts},
    espresso_processor:add_source(Source, Processor).

-spec add_sink(module(), map(), espresso_processor()) -> {ok, espresso_processor()}.
add_sink(Module, Opts, Processor) ->
    Sink = #espresso_sink{module = Module, opts = Opts},
    espresso_processor:add_sink(Sink, Processor).

-spec execute(espresso_processor()) -> ok.
execute(Processor) ->
    espresso_processor:execute(Processor).

-spec chain({module(), string()}, list(), {module(), string()}) -> ok.
chain({SourceModule, SourcePath}, FunctionChain, {SinkModule, SinkPath}) ->

    {ok, FirstProcessor} = espresso:new(),
    {ok, FirstProcessor} = espresso:add_source(SourceModule, SourcePath, FirstProcessor),

    LastProcessor =
	lists:foldl(fun({FunctionType, FunctionBody}, CurrentProcessor) ->

			    TableID = ets:new(espresso_sink_buffer, [public, duplicate_bag]),

			    {ok, CurrentProcessor} = espresso:add_sink(espresso_sink_buffer, #{table => TableID}, CurrentProcessor),

			    case FunctionType of
				map ->
				    {ok, CurrentProcessor} = espresso:map(FunctionBody, CurrentProcessor);
				reduce ->
				    {ok, CurrentProcessor} = espresso:reduce(FunctionBody, CurrentProcessor)
			    end,

			    ok = espresso:execute(CurrentProcessor),

			    timer:sleep(1000), %% @TODO: fix it!

			    {ok, NextProcessor} = espresso:new(),
			    {ok, NextProcessor} = espresso:add_source(espresso_source_buffer, #{table => TableID}, NextProcessor),

			    NextProcessor

		    end,
		    FirstProcessor,
		    FunctionChain),

    {ok, LastProcessor} = espresso:add_sink(SinkModule, SinkPath, LastProcessor),
    {ok, LastProcessor} = espresso:map(fun(Element) -> Element end, LastProcessor),
    ok = espresso:execute(LastProcessor),

    ok.

-spec map(fun((espresso_element_bin()) -> espresso_element_bin()), espresso_processor()) ->
		 {ok, espresso_processor()}.
map(Fun, Processor) ->
    Function = #espresso_function{type = map, body = Fun, opts = #{}},
    espresso_processor:define(Function, Processor).

-spec reduce(fun((espresso_element_bin(), espresso_element_int()) -> espresso_element_int()), espresso_processor()) ->
		    {ok, espresso_processor()}.
reduce(Fun, Processor) ->
    Function = #espresso_function{type = reduce, body = Fun, opts = #{}},
    espresso_processor:define(Function, Processor).

%%%===================================================================
%%% Unit tests
%%%===================================================================

kafka_source_file_sink_map_execute_test() ->

    {ok, _} = application:ensure_all_started(brod),

    BrokerList = [{"kafka00.tc3", 80}, {"kafka01.tc3", 80}, {"kafka02", 80}],
    SourceTopic =  <<"espresso-eunit-source-1">>,
    SinkPath =  <<"/tmp/espresso.test.kafka.map.sink.1">>,
    SourcePartition = 0,

    SourceOpts = #{topic => SourceTopic,
		   partitions => [SourcePartition],
		   brokers => BrokerList,
		   config => [{begin_offset, earliest}]},

    {ok, Processor} = espresso:new(),
    {ok, Processor} = espresso:add_source(espresso_source_kafka, SourceOpts, Processor),
    {ok, Processor} = espresso:add_sink(espresso_sink_file, #{path => SinkPath}, Processor),
    {ok, Processor} = espresso:map(fun(X) -> X end, Processor),

    ok = espresso:execute(Processor),

    timer:sleep(2000),

    ok.

file_source_kafka_sink_map_execute_test() ->

    {ok, _} = application:ensure_all_started(brod),

    BrokerList = [{"kafka00.tc3", 80}, {"kafka01.tc3", 80}, {"kafka02", 80}],
    SourcePath =  <<"/tmp/espresso.test.kafka.map.source.1">>,
    SinkTopic =  <<"espresso-eunit-sink-1">>,
    SinkPartition = 0,

    SinkOpts = #{topic => SinkTopic,
		 partition => SinkPartition,
		 brokers => BrokerList},


    _ = file:delete(SourcePath),

    ok = file:write_file(SourcePath, <<"first msg\nsecond msg\nthird msg">>),

    {ok, Processor} = espresso:new(),
    {ok, Processor} = espresso:add_source(espresso_source_file, #{path => SourcePath}, Processor),
    {ok, Processor} = espresso:add_sink(espresso_sink_kafka, SinkOpts, Processor),
    {ok, Processor} = espresso:map(fun(X) -> <<X/binary, " ...!">> end, Processor),

    ok = espresso:execute(Processor),

    timer:sleep(2000),

    ok.

file_source_file_sink_map_reduce_chain_test() ->

    SourcePath = "/tmp/espresso.test.map.reduce.source.chain",
    SinkPath = "/tmp/espresso.test.map.reduce.sink.chain",

    _ = file:delete(SourcePath),

    ok = file:write_file(SourcePath, <<"Lorem ipsum\ndolor sit amet\nconsectetur">>),

    timer:sleep(1000),

    ok = espresso:chain({espresso_source_file, #{path => SourcePath}},
			[
			 {map, fun(X) ->
				       ByteSize = byte_size(X),
				       integer_to_binary(ByteSize)
			       end},
			 {reduce, fun(X, Acc) ->
					  binary_to_integer(X) + Acc
				  end}
			],
			{espresso_sink_file, #{path => SinkPath}}),

    timer:sleep(1000),

    {ok, SinkResult} = file:read_file(SinkPath),
    ExpectedResult = <<"36\n">>,
    ?assert(ExpectedResult =:= SinkResult),

    ok.

file_source_file_sink_map_reduce_execute_test() ->

    SourcePath1 = "/tmp/espresso.test.map.reduce.source.1",
    SourcePath2 = "/tmp/espresso.test.map.reduce.source.2",
    SinkPath1 = "/tmp/espresso.test.map.sink.1",
    SinkPath2 = "/tmp/espresso.test.map.sink.2",
    SinkPath3 = "/tmp/espresso.test.reduce.sink.1",
    SinkPath4 = "/tmp/espresso.test.reduce.sink.2",

    _ = file:delete(SourcePath1),
    _ = file:delete(SourcePath2),

    ok = file:write_file(SourcePath1, <<"Lorem ipsum\ndolor sit amet\nconsectetur">>),
    ok = file:write_file(SourcePath2, <<"adipiscing elit\nsed do eiusmod\ntempor">>),

    {ok, ProcessorMap} = espresso:new(),
    {ok, ProcessorMap} = espresso:add_source(espresso_source_file, #{path => SourcePath1}, ProcessorMap),
    {ok, ProcessorMap} = espresso:add_source(espresso_source_file, #{path => SourcePath2}, ProcessorMap),
    {ok, ProcessorMap} = espresso:add_sink(espresso_sink_file, #{path => SinkPath1}, ProcessorMap),
    {ok, ProcessorMap} = espresso:add_sink(espresso_sink_file, #{path => SinkPath2}, ProcessorMap),
    {ok, ProcessorMap} = espresso:map(fun(X) ->
					    ByteSize = byte_size(X),
					    integer_to_binary(ByteSize)
				    end,
				    ProcessorMap),
    ok = espresso:execute(ProcessorMap),

    {ok, ProcessorReduce} = espresso:new(),
    {ok, ProcessorReduce} = espresso:add_source(espresso_source_file, #{path => SinkPath1}, ProcessorReduce),
    {ok, ProcessorReduce} = espresso:add_source(espresso_source_file, #{path => SinkPath2}, ProcessorReduce),
    {ok, ProcessorReduce} = espresso:add_sink(espresso_sink_file, #{path => SinkPath3}, ProcessorReduce),
    {ok, ProcessorReduce} = espresso:add_sink(espresso_sink_file, #{path => SinkPath4}, ProcessorReduce),
    {ok, ProcessorReduce} = espresso:reduce(fun(X, Acc) ->
						binary_to_integer(X) + Acc
					end, ProcessorReduce),
    ok = espresso:execute(ProcessorReduce),

    timer:sleep(1000),

    {ok, ReduceResult1} = file:read_file(SinkPath3),
    {ok, ReduceResult2} = file:read_file(SinkPath4),

    ExpectedReduceResult = <<"142\n">>,
    ?assert(ExpectedReduceResult =:= ReduceResult1),
    ?assert(ExpectedReduceResult =:= ReduceResult2),

    ok.
