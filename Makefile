
help:

	@echo "Possible targets:"
	@echo "  test - build all test suites"
	@echo "  test-constant - build all test suites, as soon as a file changes"
	exit 0

test:

	@./run_tests.sh

test-constant:

	@echo "Waiting for files to change ..."
	@while [ 1 ]; do inotifywait --quiet -r -e close_write .; make test; sleep 1; done

.PHONY: test help

# vim: ts=4:sw=4:noexpandtab!:
