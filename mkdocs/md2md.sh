#!/usr/bin/env bash
for fn in README.md INSTALLING.md UPGRADING.md; do
	cat ../$fn | perl -pe's/\.pod/.md/g' > docs/$fn
done
