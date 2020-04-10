#!/usr/bin/env bash

__DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
__FILE="${__DIR}/$(basename "${BASH_SOURCE[0]}")"

cd ${__DIR}

if [ -f $__DIR/.envrc ]; then
  . $__DIR/.envrc
else
  echo 'Error: The is no environment set.' > /dev/stderr
  echo 'Note: Create a ~/.envrc file with all of the environment variables needed.' > /dev/stderr
  exit 1
fi

MIX_ENV=prod mix release

VERSION=$(cat $__DIR/mix.exs | grep 'version' | cut -d '"' -f2 | head -n 1)

mkdir -p ${__DIR}/dist

cd ${__DIR}/_build/prod/rel
tar -cvf ${__DIR}/dist/covid19bg_${VERSION}.tar .

scp ${__DIR}/dist/covid19bg_${VERSION}.tar ${DEPLOYMENT_SSH}:

ssh -o StrictHostKeyChecking=no -t $DEPLOYMENT_SSH "mkdir -p covid19/releases"
