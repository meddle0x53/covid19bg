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

rm -rf _build/prod
MIX_ENV=prod mix release

VERSION=$(cat $__DIR/mix.exs | grep 'version' | cut -d '"' -f2 | head -n 1)

mkdir -p ${__DIR}/dist

cd ${__DIR}/_build/prod/rel
tar -cvf ${__DIR}/dist/covid19bg_${VERSION}.tar .

scp ${__DIR}/dist/covid19bg_${VERSION}.tar ${DEPLOYMENT_SSH}:

RELEASE_DIR=covid19bg/releases/${VERSION}

ssh -o StrictHostKeyChecking=no -t $DEPLOYMENT_SSH "mkdir -p ${RELEASE_DIR}"
ssh -o StrictHostKeyChecking=no -t $DEPLOYMENT_SSH "tar -xvf covid19bg_${VERSION}.tar -C ${RELEASE_DIR}"

ssh -o StrictHostKeyChecking=no -t $DEPLOYMENT_SSH "./covid19bg/releases/current/covid19bg/bin/covid19bg stop"
ssh -o StrictHostKeyChecking=no -t $DEPLOYMENT_SSH "rm ./covid19bg/releases/current"
ssh -o StrictHostKeyChecking=no -t $DEPLOYMENT_SSH "ln -s ${HOME}/covid19bg/releases/${VERSION}/ ${HOME}/covid19bg/releases/current"
ssh -o StrictHostKeyChecking=no -t $DEPLOYMENT_SSH "./covid19bg/releases/current/covid19bg/bin/covid19bg daemon"
