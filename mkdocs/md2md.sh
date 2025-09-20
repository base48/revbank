#!/usr/bin/env bash
for fn in README.md INSTALLING.md UPGRADING.md; do
	cat ../$fn | perl -pe's/\w+\K\.pod/.md/g' > docs/$fn
done
