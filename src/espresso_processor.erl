-module(espresso_processor).
-behaviour(gen_server).

-export([start/0]).
-export([add_source/2]).
-export([add_sink/2]).
-export([define/2]).
-export([process/2]).
-export([done/1]).
-export([execute/1]).

-export([init/1]).
-export([handle_call/3]).
-export([handle_cast/2]).
-export([handle_info/2]).
-export([terminate/2]).
-export([code_change/3]).

-define(SERVER, ?MODULE).

-record(state, {
	  pid :: pid(),
	  source :: list(espresso_source()),
	  sink :: list(espresso_sink()),
	  function :: espresso_processor(),
	  last_element :: espresso_element()
	 }).

-include("espresso.hrl").
-include_lib("eunit/include/eunit.hrl").

%%%===================================================================
%%% API
%%%===================================================================

-spec start() -> {ok, espresso_processor()}.
start() ->
    gen_server:start(?MODULE, [], []).

-spec add_source(espresso_source(), espresso_processor()) -> {ok, espresso_processor()}.
add_source(Source, Processor) ->
    ok = gen_server:call(Processor, {add_source, Source}),
    {ok, Processor}.

-spec add_sink(espresso_sink(), espresso_processor()) -> {ok, espresso_processor()}.
add_sink(Sink, Processor) ->
    ok = gen_server:call(Processor, {add_sink, Sink}),
    {ok, Processor}.

-spec define(espresso_function(), espresso_processor()) -> {ok, espresso_processor()}.
define(Function, Processor) ->
    ok = gen_server:call(Processor, {define, Function}),
    {ok, Processor}.

-spec process(espresso_element(), espresso_processor()) -> {ok, espresso_processor()}.
process(Element, Processor) ->
    ok = gen_server:cast(Processor, {process, Element}),
    {ok, Processor}.

-spec done(espresso_processor()) -> {ok, espresso_processor()}.
done(Processor) ->
    ok = gen_server:call(Processor, done),
    {ok, Processor}.

-spec execute(espresso_processor()) -> ok.
execute(Processor) ->
    ok = gen_server:call(Processor, execute),
    ok.

%%%===================================================================
%%% Generic functions
%%%===================================================================

init([]) ->
    {ok, #state{pid = self(), source = [], sink = []}}.

handle_call({add_source, Source}, _From, #state{source = Sources} = State) ->
    {reply, ok, State#state{source = [Source | Sources]}};

handle_call({add_sink, Sink}, _From, #state{sink = Sinks} = State) ->
    {reply, ok, State#state{sink = [Sink | Sinks]}};

handle_call({define, Function}, _From, State) ->
    {reply, ok, State#state{function = Function}};

handle_call(done, {FromPID, _FromRef}, #state{source = Sources, sink = Sinks, function = Function} = State) ->

    FunctionType = Function#espresso_function.type,
    NewSources = lists:keydelete(FromPID, #espresso_source.pid, Sources),

    case length(NewSources) of
	0 ->
	    case FunctionType of
		map ->
		    ok;
		reduce ->
		    ok = write_to_sink(State#state.last_element, Sinks)
	    end;
	_ ->
	    ok
    end,

    {reply, ok, State#state{source = NewSources}};

handle_call(execute, _From, #state{pid = EnvPID, source = Sources, sink = Sinks} = State) ->

    NewSources =
	lists:map(fun(#espresso_source{module = SourceModule, opts = SourceOpts} = Source) ->
			  SourcePID = spawn_link(fun() ->
							 ok = SourceModule:run(SourceOpts, EnvPID)
						 end),
			  Source#espresso_source{pid = SourcePID}
		  end,
		  Sources),

    NewSinks =
	lists:map(fun(#espresso_sink{module = SinkModule, opts = SinkOpts} = Sink) ->
			  SinkPID = spawn_link(fun() ->
						       ok = SinkModule:run(SinkOpts, EnvPID)
					       end),
			  Sink#espresso_sink{pid = SinkPID}
		  end,
		  Sinks),

    {reply, ok, State#state{source = NewSources, sink = NewSinks}};

handle_call(_Request, _From, State) ->
    {reply, ok, State}.

handle_cast({process, Element}, #state{sink = Sinks, function = Function} = State) ->

    FunctionType = Function#espresso_function.type,
    FunctionBody = Function#espresso_function.body,

    NewElement =
	case FunctionType of
	    map ->
		ProcessedElement = FunctionBody(Element),
		ok = write_to_sink(ProcessedElement, Sinks),
		ProcessedElement;
	    reduce ->
		LastElement = if
				  State#state.last_element =:= undefined -> 0;
				  true -> State#state.last_element
			      end,
		FunctionBody(Element, LastElement)
	end,

    {noreply, State#state{last_element = NewElement}};

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%%===================================================================
%%% Internal functions
%%%===================================================================

-spec write_to_sink(espresso_element(), list(espresso_sink())) -> ok.
write_to_sink(Element, Sinks) ->
    lists:foreach(fun(#espresso_sink{module = Module, opts = Opts, pid = SinkPID}) ->
			  ok = Module:write(Element, Opts, SinkPID)
		  end,
		  Sinks).
