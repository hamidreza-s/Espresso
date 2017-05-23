-module(espresso).

-export([new/0]).
-export([add_source/2]).
-export([add_sink/2]).
-export([execute/1]).
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

-spec add_source(espresso_source(), espresso_processor()) -> {ok, espresso_processor()}.
add_source(Source, Processor) ->
    espresso_processor:add_source(Source, Processor).

-spec add_sink(espresso_sink(), espresso_processor()) -> {ok, espresso_processor()}.
add_sink(Sink, Processor) ->
    espresso_processor:add_sink(Sink, Processor).

-spec execute(espresso_processor()) -> ok.
execute(Processor) ->
    espresso_processor:execute(Processor).

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

file_source_file_sink_map_reduce_test() ->

    {ok, Processor0} = espresso:new(),
    {ok, Processor1} = espresso:add_source(#espresso_source{module = espresso_source_file, opts = #{path => "/tmp/foo"}}, Processor0),
    {ok, Processor2} = espresso:add_source(#espresso_source{module = espresso_source_file, opts = #{path => "/tmp/fee"}}, Processor1),
    {ok, Processor3} = espresso:add_sink(#espresso_sink{module = espresso_sink_file, opts = #{path => "/tmp/bar"}}, Processor2),
    {ok, Processor4} = espresso:add_sink(#espresso_sink{module = espresso_sink_file, opts = #{path => "/tmp/bat"}}, Processor3),
    {ok, Processor5} = espresso:map(fun(X) ->
				      ByteSize = byte_size(X),
				      integer_to_binary(ByteSize)
			      end,
			      Processor4),
    ok = espresso:execute(Processor5),

    timer:sleep(1000), % @TODO: fix it!

    {ok, Processor10} = espresso:new(),
    {ok, Processor11} = espresso:add_source(#espresso_source{module = espresso_source_file, opts = #{path => "/tmp/bar"}}, Processor10),
    {ok, Processor12} = espresso:add_source(#espresso_source{module = espresso_source_file, opts = #{path => "/tmp/bat"}}, Processor11),
    {ok, Processor13} = espresso:add_sink(#espresso_sink{module = espresso_sink_file, opts = #{path => "/tmp/bal"}}, Processor12),
    {ok, Processor14} = espresso:reduce(fun(X, Acc) ->
    					  binary_to_integer(X) + Acc
    				  end, Processor13),
    ok = espresso:execute(Processor14),

    ok.
