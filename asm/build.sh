
if [ ! -d ./output ]; then
  mkdir ./output
fi;

rm ./output/main.rom
zcc +z80 --no-crt main.asm -bn ./output/main.bin -create-app -m -Cz--romsize=32768 
#zcc +z80 --no-crt echo.asm -bn ./output/main.bin -create-app -m -Cz--romsize=32768 


rm output/testload__.ihx
# 8300 hex is 33536 dec
#zcc +z80 --no-crt  testload.asm -bn ./output/testload.bin -create-app -m -Cz--ihex -Cz--rombase=33536 
zcc +z80 --no-crt testload.asm -m -o ./output/testload
z88dk-appmake +glue -b ./output/testload --ihex
