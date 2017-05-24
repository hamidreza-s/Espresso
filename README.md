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