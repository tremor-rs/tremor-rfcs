cp mkdocs.hdr.yml mkdocs.yml
for f in $(ls text/* | sort)
do
    echo "    - $(basename $f ".md"): $(basename $f)" >> mkdocs.yml
    cp $f src
done