#!/bin/bash

cd ${0%/*}/..

MIX_ENV=prod mix local.hex --force
MIX_ENV=prod mix local.rebar --force
MIX_ENV=prod mix deps.get
MIX_ENV=prod mix phx.digest
MIX_ENV=prod mix release --overwrite
_build/prod/rel/cmsbear/bin/cmsbear stop
_build/prod/rel/cmsbear/bin/cmsbear daemon_iex
