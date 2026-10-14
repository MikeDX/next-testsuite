SJASM ?= sjasmplus
build/nexts.nex: src/nexts.asm sdk/next.asm sdk/next.inc
	mkdir -p build && cd src && $(SJASM) --zxnext --nologo nexts.asm
expected:
	python3 tools/verify.py --gen-only
run:
	SJASM=$(SJASM) tools/run.sh
clean:
	rm -rf build
.PHONY: expected run clean
