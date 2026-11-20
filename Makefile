AS := vasm
AS_FLAGS := -quiet -Fvobj

OUT_DIR := out
TARGET := $(OUT_DIR)/widgets.o

SRC_DIR := src
SRCS := $(wildcard $(SRC_DIR)/%.asm)
MAIN_FILE := $(SRC_DIR)/widgets.asm

$(TARGET): $(SRCS)
	mkdir -p $(OUT_DIR)
	$(AS) $(AS_FLAGS) $(MAIN_FILE) -o $(TARGET)
	@echo Success, assembled to object file. You can now link with another project.

clean:
	rm -rf $(OUT_DIR)

.PHONY: clean
