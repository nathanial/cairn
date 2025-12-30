#!/bin/bash
set -e

# Build tests
LEAN_CC=/usr/bin/clang lake build cairn_tests

# Run tests
.lake/build/bin/cairn_tests
