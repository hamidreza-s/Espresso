-module(espresso_utils).

-export([to_binary/1]).

-include("espresso.hrl").
-include_lib("eunit/include/eunit.hrl").

-spec to_binary(any()) -> binary().
to_binary(Element) when is_binary(Element) -> Element;
to_binary(Element) when is_integer(Element) -> integer_to_binary(Element);
to_binary(Element) when is_list(Element) -> list_to_binary(Element);
to_binary(_Element) -> <<"bad-formatted-data\n">>.
