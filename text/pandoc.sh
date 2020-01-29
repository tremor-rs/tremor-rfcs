#!/bin/bash

for f in `ls *.md`;
do
  $(pandoc -o ${f%.*}.pdf $f)
  $(pandoc -o ${f%.*}.docx $f)
done
