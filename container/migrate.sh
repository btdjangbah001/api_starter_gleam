#!/bin/sh
set -eu
cd "$(dirname "$0")"
exec erl -pa ./*/ebin -noshell -eval "{ok, _} = application:ensure_all_started(api_starter), app@migrate:main(), init:stop()."
