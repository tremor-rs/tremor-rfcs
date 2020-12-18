docs: mkdocs.yml
	mkdocs build

mkdocs.yml: mkdocs.hdr.yml text/*.md *.md
	- mkdir src
	cp favicon.ico *.md src/
	cp LICENSE src/LICENSE.txt
	cp -rf img src/
	./build-yml.sh


clean:
	- rm mkdocs.yml
	- rm text/*.pdf text/*.docx
	- rm -r src/

serve: docs
	mkdocs serve

new:
	@if [ -z "$(name)" ]; then echo "please use 'make new name=new-rfc-name'"; exit 1; fi
	@if [ -f text/0000-$(name).md ]; then echo "RFC 'text/0000-$(name).md' already exists"; exit 1; fi
	@echo "Creating new branch $(name)"
	@git checkout -b $(name)
	@echo "Added new RFC: text/0000-$(name).md"
	@cp 0000-template.md text/0000-$(name).md
	@git add text/0000-$(name).md
	@echo "done."