Espresso
=====

An Erlang/Elixir Stream Processing Library.

What is Espresso
-----

To put it shortly, it is something like [Apache Flink]() or [Apache Kafka Stream API]() but in Erlang/Elixir.

Name origin
-----
The `e`, `s`, and `p` letters of Epresso stand for `Erlang/Elixir`, `Stream`, and `Processing` respectively, and `resso` stands for nothing :)

What it does
-----

It gets inputs from different **sources** and after **processing** its elements puts it as output to different **sinks**.

Concepts
-----

The concepts are similar to other steam processing libraries. They are as follows:

- **Source**: The input stream which can be any of *Unix file*, *Unix socket*, *Kafka topic*, *RabbitMQ queue*, and etc.
- **Sink**: The output stream which can be any of *Unix file*, *Unix socket*, *Kafka topic*, *RabbitMQ queue*, and etc.
- **Processor**: The processing action on the elements of a stream, such as `Map`, `reduce`, `filter`, `aggregate`, and etc.

Architecture
-----

- Each Source, Sink, and Processor is an Actor which run concurrently.
- It is possible that each Processor has one or more Source or Sink.


```
+-------------------+   +-------------------+   +-------------------+
|                   |   |                   |   |                   |
|    File Source    |   |   Kafka Source    |   |   Rabbit Source   |
|                   |   |                   |   |                   |
+---------+---------+   +---------+---------+   +---------+---------+
          |                       |                       |
          |                       |                       |
          |     +-----------------v-------------+         |
          |     |                               |         |
          +----->        Map Processor          <---------+
                |                               |
                +-------+------------------+----+
                        |                  |
                        |                  |
           +------------v------+   +-------v-----------+
           |                   |   |                   |
           | Kafka Source/Sink |   | File Source/Sink  |
           |                   |   |                   |
           +------------+------+   +-------+-----------+
                        |                  |
                        |                  |
                +-------v------------------v----+
                |                               |
          +-----+        Reduce Processor       +--------+
          |     |                               |        |
          |     +-----------------+-------------+        |
          |                       |                      |
          |                       |                      |
+---------v---------+   +---------v---------+   +--------v----------+
|                   |   |                   |   |                   |
|   File Sink       |   |   Kafka Sink      |   |    Rabbit Sink    |
|                   |   |                   |   |                   |
+-------------------+   +-------------------+   +-------------------+

```

How to implement a new Source
-----

The `espresso_source.erl` is the behaviour for writing new sources with the following callback:

```erlang
-callback run(Opts :: map(), Processor :: espresso_processor()) -> ok.
```

Now, implementing a Unix file source is as simple as follows:

```erlang
-module(espresso_source_file).
-behaviour(espresso_source).

-export([run/2]).

-spec run(map(), espresso_processor()) -> ok.
run(Opts, Processor) ->
    Path = maps:get(path, Opts),
    {ok, File} = file:open(Path, [read, binary]),
    do_run(File, Processor).

do_run(File, Processor) ->
    case file:read_line(File) of
	{ok, Element} ->
	    {ok, Processor} = espresso_processor:process(Element, Processor),
	    do_run(File, Processor);
	eof ->
	    {ok, Processor} = espresso_processor:done(Processor),
	    file:close(File),
	    ok
    end.
```

How to implement a new Sink
-----

The `espresso_source.erl` is the behaviour for writing new sinks with the following callbacks:

```erlang
-callback run(Opts :: map(), Processor :: espresso_processor()) -> ok.

-callback write(Element :: espresso_element(), Opts :: map(), SinkPID :: pid()) -> ok.
```

Again, implementing a Unix file sink is as simple as follows:

```erlang
-module(espresso_sink_file).
-behaviour(espresso_sink).

-export([run/2]).
-export([write/3]).

-spec run(map(), espresso_processor()) -> ok.
run(Opts, Processor) ->
    Path = maps:get(path, Opts),
    {ok, File} = file:open(Path, [write, binary]),
    do_run(File, Processor).

do_run(File, Processor) ->
    receive
	{write, Element} ->
	    ok = file:write(File, ElementLine),
	    do_run(File, Processor)
    end.

-spec write(espresso_element(), map(), pid()) -> ok.
write(Element, _Opts, SinkPID) ->
    SinkPID ! {write, Element},
    ok.
```

Examples
-----

The following examples are in Erlang, but apparently the API can be used in Elixir as well.

- A MapReduce from file to file:

```erlang
%% define file source
Source = {espresso_source_file, #{path => "/path/to/source/file"}},

%% define file sink
Sink = {espresso_sink_file, #{path => "/path/to/sink/file"}},

%% define a chain of processors
Processors = [{map, fun(X) -> ByteSize = byte_size(X), integer_to_binary(ByteSize) end},
              {reduce, fun(X, Acc) -> binary_to_integer(X) + Acc end}],

%% execute them on a chain of processors
ok = espresso:chain(Source, Processors, Sink),
```

- A MapReduce from file to kafka:

```erlang
%% define file source
Source = {espresso_source_file, #{path => "/path/to/source/file"}},

%% define kafka sink
Sink = {espresso_sink_file, #{path => "/path/to/sink/file"}},
SinkOpts = #{topic => SinkTopic,
             partition => SinkPartition,
             brokers => BrokerList},
Sink = {espresso_source_kafka, SinkOpts},

%% define a chain of processors
Processors = [{map, fun(X) -> ByteSize = byte_size(X), integer_to_binary(ByteSize) end},
              {reduce, fun(X, Acc) -> binary_to_integer(X) + Acc end}],

%% execute them on a chain of processors
ok = espresso:chain(Source, Processors, Sink),
```

It is Elixir-friendly
-----

Since the API is Elixir-friendly, you can use `|>` operator for writing processors simpler:

```elixir
:espresso.new
         |> :espresso.add_source(:espresso_source_file, %{:path => "/path/to/source1"})
	 |> :espresso.add_source(:espresso_source_file, %{:path => "/path/to/source2"})
	 |> :espresso.add_sink(:espresso_sink_file, %{:path => "/path/to/sink1"})
	 |> :espresso.add_sink(:espresso_sink_file, %{:path => "/path/to/sink2"})
	 |> :espresso.map(fn(X) -> X end)
	 |> :espresso.execute
```
