all:
	vim -c "call lazy_sea#test()"
	cat lazy_sea_test.txt

watch:
	watchr -e 'watch(".") {system "make"}'
