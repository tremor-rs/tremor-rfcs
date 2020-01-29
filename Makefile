docs: mkdocs.yml
	mkdocs build

mkdocs.yml: mkdocs.hdr.yml text/*.md *.md
	- mkdir src
	cp *.md src/
	cp -r img src/
	./build-yml.sh


clean:
	- rm mkdocs.yml
	- rm text/*.pdf text/*.docx
	- rm -r src/

serve: docs
	mkdocs serve