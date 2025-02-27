run:
	odin run ./src -out=bin/tyler

build:
	odin build ./src -out=bin/tyler

build-debug:
	odin build ./src -out=bin/tyler-debug -debug

clean:
	rm -rf ./bin/*