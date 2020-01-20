#!/bin/sh

set -e

if [ ! -d src ]; then
    mkdir src
fi

echo "[Introduction](introduction.md)\n" > src/SUMMARY.md
echo "- [Language sub-team](lang_changes.md)" >> src/SUMMARY.md
echo "- [Libraries sub-team](libs_changes.md)" >> src/SUMMARY.md
echo "- [API sub-team](api_changes.md)" >> src/SUMMARY.md
echo "- [Architecture sub-team](arch_changes.md)" >> src/SUMMARY.md
echo "\n\n" >> src/SUMMARY.md

for f in $(ls text/* | sort)
do
    echo "- [$(basename $f ".md")]($(basename $f))" >> src/SUMMARY.md
    cp $f src
done

cp README.md src/introduction.md
cp *_changes.md src

mdbook build
