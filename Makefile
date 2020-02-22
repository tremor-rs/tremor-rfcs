docs: mkdocs.yml
	mkdocs build

mkdocs.yml: mkdocs.hdr.yml text/*.md *.md
	- mkdir src
	cp favicon.ico *.md src/
	cp -rf img src/
	./build-yml.sh


clean:
	- rm mkdocs.yml
	- rm text/*.pdf text/*.docx
	- rm -r src/

serve: docs
	mkdocs serve
