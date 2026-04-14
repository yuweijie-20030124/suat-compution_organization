ALL?=ai

$(ALL).hex: $(ALL).bin
	od -t x4 -An -w4 -v $< > $@

$(ALL).bin: $(ALL).o
	riscv64-unknown-elf-objcopy -S --set-section-flags .bss=alloc,contents -O binary $< $@

$(ALL).o: $(ALL).S
	riscv64-unknown-elf-gcc -march=rv32i -mabi=ilp32 -c $< -o $@

.PHONY: clean
clean:
	rm *.hex *.bin *.o
