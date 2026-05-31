Z88 = zcc

TARGET = main

all: $(TARGET)

$(TARGET): $(TARGET).asm
	mkdir ./out || true
	$(Z88) +z80 --no-crt $(TARGET).asm -bn ./out/$(TARGET).bin -create-app -m -Cz--romsize=32768 

install: $(TARGET)
	minipro -p AT28C256 -w ./out/$(TARGET).rom
	
test: $(TARGET)
	hexdump -C ./out/$(TARGET).rom

clean:
	$(RM) ./out/$(TARGET).*