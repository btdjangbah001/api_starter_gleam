-module(app_test_ffi).
-export([rescue/1]).

rescue(Work) ->
    try {ok, Work()} catch _:_ -> {error, nil} end.
