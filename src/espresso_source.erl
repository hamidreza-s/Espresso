-module(espresso_source).

-include("espresso.hrl").

-callback run(Opts :: map(), Processor :: espresso_processor()) -> ok.
