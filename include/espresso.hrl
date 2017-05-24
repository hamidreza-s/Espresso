-record(espresso_source, {
	  module :: module(),
	  opts :: map(),
	  pid :: pid()
	 }).

-record(espresso_sink, {
	  module :: module(),
	  opts :: map(),
	  pid :: pid()
	 }).

-record(espresso_function, {
	  type :: espresso_function_type(),
	  body :: function() | mfa(),
	  opts :: map()
	 }).

-type espresso_processor() :: pid().
-type espresso_element_bin() :: binary().
-type espresso_element_int() :: integer().
-type espresso_element() :: espresso_element_bin()
			  | espresso_element_int()
			  | any().
-type espresso_source() :: #espresso_source{}.
-type espresso_sink() :: #espresso_sink{}.
-type espresso_function() :: #espresso_function{}.
-type espresso_function_type() :: map
				| reduce
				| filter
				| aggregate.

-ifdef(TEST).
-define(LOG(Format, Args), ct:print(default, 50, Format, Args)).
-else.
-define(LOG(Format, Args), error_logger:info_msg(Format, Args)).
-endif.
