BUILD=./build.sh

all: commit

local:
	$(BUILD) -l

website:
	$(BUILD)

commit: website
	git add *.html home/ && git commit -v

deploy: commit
	git push origin master
