-module(app_ffi).

-export([rate_limit_table_create/0, gcra_allow/4, rate_limit_purge_expired/0,
         admission_install/0, admission_run/3, admission_in_flight/0,
         priv_directory/0]).

-define(TABLE, app_rate_limits).

rate_limit_table_create() ->
    case ets:info(?TABLE) of
        undefined ->
            ets:new(?TABLE, [named_table, public, set,
                             {write_concurrency, auto}, {read_concurrency, true},
                             {decentralized_counters, true}]),
            nil;
        _ ->
            nil
    end.

%% Generic Cell Rate Algorithm. Each key stores only its theoretical arrival
%% time (TAT) in microseconds. Emission interval T = Period / Limit and the
%% burst tolerance is Period - T, so up to Limit requests may arrive at once
%% and then one more every T. A request at time Now is admitted when
%% max(TAT, Now) + T - Now =< Period; admission advances TAT by T.
%% Updates are a lock-free compare-and-swap via ets:select_replace/2 so
%% concurrent schedulers never lose an increment.
gcra_allow(Bucket, Key, PeriodSeconds, Limit) when Limit > 0, PeriodSeconds > 0 ->
    Id = {Bucket, Key},
    Period = PeriodSeconds * 1000000,
    EmissionInterval = Period div Limit,
    try
        gcra_attempt(Id, Period, EmissionInterval)
    catch
        error:badarg -> true
    end.

gcra_attempt(Id, Period, EmissionInterval) ->
    Now = erlang:monotonic_time(microsecond),
    case ets:lookup(?TABLE, Id) of
        [] ->
            case ets:insert_new(?TABLE, {Id, Now + EmissionInterval}) of
                true -> true;
                false -> gcra_attempt(Id, Period, EmissionInterval)
            end;
        [{Id, StoredTat}] ->
            NewTat = max(StoredTat, Now) + EmissionInterval,
            case NewTat - Now =< Period of
                false ->
                    false;
                true ->
                    Swap = [{{Id, StoredTat}, [], [{{{const, Id}, {const, NewTat}}}]}],
                    case ets:select_replace(?TABLE, Swap) of
                        1 -> true;
                        0 -> gcra_attempt(Id, Period, EmissionInterval)
                    end
            end
    end.

rate_limit_purge_expired() ->
    Now = erlang:monotonic_time(microsecond),
    try
        ets:select_delete(?TABLE, [{{'_', '$1'}, [{'<', '$1', Now}], [true]}])
    catch
        error:badarg -> 0
    end.

%% Admission control: one lock-free atomic counts in-flight requests. Over the
%% limit the increment is undone and the request is rejected before any work.
%% `after` guarantees the slot is released even if the admitted handler crashes.
admission_install() ->
    case persistent_term:get(app_admission, undefined) of
        undefined -> persistent_term:put(app_admission, atomics:new(1, [{signed, true}])), nil;
        _ -> nil
    end.

admission_run(Limit, Admitted, Rejected) ->
    Counter = admission_counter(),
    case atomics:add_get(Counter, 1, 1) =< Limit of
        true ->
            try Admitted() after atomics:sub(Counter, 1, 1) end;
        false ->
            atomics:sub(Counter, 1, 1),
            Rejected()
    end.

admission_in_flight() ->
    atomics:get(admission_counter(), 1).

admission_counter() ->
    case persistent_term:get(app_admission, undefined) of
        undefined -> admission_install(), persistent_term:get(app_admission);
        Counter -> Counter
    end.

priv_directory() ->
    case code:priv_dir(api_starter) of
        {error, _} -> <<"priv">>;
        Directory -> unicode:characters_to_binary(Directory)
    end.
