#!/usr/bin/env bash

__DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
__FILE="${__DIR}/$(basename "${BASH_SOURCE[0]}")"

cd ${__DIR}

mix release

VERSION=$(cat $__DIR/mix.exs | grep 'version' | cut -d '"' -f2 | head -n 1)
echo $VERSION
