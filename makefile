all:
	vim -c "call lazy_c#test()"
	cat lazy_c_test.txt

watch:
	watchr -e 'watch(".") {system "make"}'
