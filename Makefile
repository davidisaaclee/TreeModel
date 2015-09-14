SOURCES=src/TreeModel.coffee
COFFEE=coffee
CFLAGS=-o $(OUTPUT_DIR) -c
OUTPUT_DIR=./build

CFLAGS_TEST=-o $(TEST_DIR)/build -c
TEST_DIR=./spec
SPEC=$(TEST_DIR)/src/TreeModelSpec.coffee

JASMINE=node ./node_modules/jasmine/bin/jasmine

all:
	$(COFFEE) $(CFLAGS) $(SOURCES)

test: build-tests
	$(JASMINE)

build-tests:
	$(COFFEE) $(CFLAGS_TEST) $(SPEC)