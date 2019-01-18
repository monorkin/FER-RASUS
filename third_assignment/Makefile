DEFUALT_GOAL: re-run
CC = `which gcc`

re-run:
	@rm -f solution
	@$(MAKE) run

run: solution
	@chmod +x solution
	@./solution

solution:
	@$(CC) -o solution -Lpdq/lib -Ipdq/lib -lpdq -lm solution.c

install:
	@curl 'https://downloads.sourceforge.net/project/pdq-qnm-pkg/PDQ%20source/6.2.0/PDQ-6.2.0.tar.gz?r=https%3A%2F%2Fsourceforge.net%2Fprojects%2Fpdq-qnm-pkg%2Ffiles%2FPDQ%2520source%2F6.2.0%2FPDQ-6.2.0.tar.gz%2Fdownload&ts=1547404304' -L -o PDQ-6.2.0.tar.gz
	@tar -xzf PDQ-6.2.0.tar.gz
	@cd pdq/lib && make
	@rm PDQ-6.2.0.tar.gz

uninstall:
	@rm -f PDQ-6.2.0.tar.gz
	@rm -rf pdq
