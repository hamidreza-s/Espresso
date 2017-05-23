-module(espresso_sink).

-include("espresso.hrl").

-callback run(Opts :: map(), Processor :: espresso_processor()) -> ok.

-callback write(Element :: espresso_element(), Opts :: map(), SinkPID :: pid()) -> ok.
