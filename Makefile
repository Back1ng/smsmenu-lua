.PHONY: build clean all

OUT_DIR = build
OUT_FILE = $(OUT_DIR)\smsmenu.lua
SRC_FILE = src\smsmenu.lua

all: build

build: 
	node build.js

clean:
	@if exist $(OUT_DIR) rmdir /S /Q $(OUT_DIR)
