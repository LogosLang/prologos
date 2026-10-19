#!/bin/bash
# W2-4 census: production installers of fire-once propagators, and which pass empty inputs.
cd "$1"
FILES=$(find . -name '*.rkt' -not -path '*/tests/*' -not -path '*/benchmarks/*' -not -path '*/tools/*' -not -path '*/compiled/*' -not -path '*/examples/*')
echo "== #:flags passed to net-add-propagator (outside propagator.rkt def)"
grep -n -E '#:flags' $FILES | grep -v -E ':[0-9]+:\s*;'
echo "== elab-add-fire-once-propagator call sites"
grep -n -E '\(elab-add-fire-once-propagator([[:space:])]|$)' $FILES | grep -v -E ':[0-9]+:\s*;' | grep -v '(define (elab-add'
echo "== module-network-install-fire-once call sites"
grep -n -E '\(module-network-install-fire-once([[:space:])]|$)' $FILES | grep -v -E ':[0-9]+:\s*;' | grep -v '(define (module-network'
echo "== net-add-fire-once-propagator call sites with literal empty inputs"
grep -n -E "net-add-fire-once-propagator [^ ]+ '\(\)" $FILES
echo "== power: all net-add-fire-once-propagator call sites"
grep -n -E '\(net-add-fire-once-propagator([[:space:])]|$)' $FILES | grep -v -E ':[0-9]+:\s*;' | grep -v '(define (net-add' | wc -l
