#!/bin/sh
cd ext;
ruby extconf.rb;
make;
cp elf32.so ../ELF;
cd ../;
