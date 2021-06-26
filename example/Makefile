all:
	@echo "Use 'make test' to run the test and 'make clean' to clean up afterwards"

test:
	@sh ../merge-shell.sh split-script.sh > merged-script.sh
	@diff -u original-script.sh merged-script.sh
	@echo "Test passed"

clean:
	rm -f merged-script.sh

