#  Mess-Paraver portable Makefile
#  - works with system Python, virtualenv, conda, pyenv, Homebrew ...

PYTHON      ?= python3           # interpreter to embed
REQ_FILE    ?= requirements.txt  # pip requirements to bundle

SHELL := /bin/bash

ifneq ($(MAKECMDGOALS),clean)
  PY_OK := $(shell $(PYTHON) -c 'import sys; print("ok" if sys.version_info>=(3,6) else "bad")' 2>/dev/null || echo bad)

  ifeq ($(PY_OK),bad)
    $(error "$(PYTHON) is missing or < 3.6 - run 'make PYTHON=/path/to/python3.11'")
  endif

  PY_VER := $(shell $(PYTHON) -c 'import sys; print("{}.{}".format(sys.version_info[0], sys.version_info[1]))')
  PY_ABI := $(shell $(PYTHON) -c 'import sys; print("cp{}{}".format(sys.version_info[0], sys.version_info[1]))')
  PY_EXECUTABLE := $(shell $(PYTHON) -c 'import sys; print(sys.executable)')
  PY_EXECUTABLE_DIR := $(shell dirname "$(PY_EXECUTABLE)")

  PY_CONFIG := $(shell for candidate in \
                          "$(PY_EXECUTABLE_DIR)/python$(PY_VER)-config" \
                          "python$(PY_VER)-config" \
                          "$(PY_EXECUTABLE)-config" \
                          "$(PYTHON)-config" \
                          "$(PY_EXECUTABLE_DIR)/python3-config" \
                          "python3-config"; do \
                          config="$$(command -v "$$candidate" 2>/dev/null)" || continue; \
                          includes="$$("$$config" --includes 2>/dev/null)" || continue; \
                          if [[ "$$includes" == *"python$(PY_VER)"* ]]; then echo "$$config"; exit 0; fi; \
                        done)

  ifeq ($(PY_CONFIG),)
    $(error "Cannot find python-config matching $(PYTHON) ($(PY_VER)). Install python$(PY_VER)-dev or run 'make PYTHON=/path/to/python$(PY_VER)'")
  endif

  PY_CFLAGS  := $(shell $(PY_CONFIG) --includes)

  PY_LDFLAGS := $(shell for args in "--ldflags --embed" "--ldflags" "--libs"; do \
                          flags="$$($(PY_CONFIG) $$args 2>/dev/null)"; \
                          if [[ "$$flags" == *-lpython* ]]; then echo "$$flags"; exit 0; fi; \
                        done; \
                        for pkg in "python-$(PY_VER)-embed" "python-$(PY_VER)"; do \
                          flags="$$(pkg-config --libs "$$pkg" 2>/dev/null)"; \
                          if [[ "$$flags" == *-lpython* ]]; then echo "$$flags"; exit 0; fi; \
                        done)

  ifeq ($(PY_LDFLAGS),)
    $(error "Cannot find Python linker flags for $(PYTHON). Tried $(PY_CONFIG) and pkg-config for python-$(PY_VER)")
  endif
endif

SRC_CPP_FILES := $(shell find src/ -name '*.cpp')
SRC_CC_FILES  := $(shell find src/ -name '*.cc')

BIN_DIR  := bin
MESS_PATH := libs/PROFET

ifeq ($(shell uname -m),x86_64)
  WHEEL_DIR := $(BIN_DIR)/python_libs_x86_64_$(PY_ABI)
else
  WHEEL_DIR := $(BIN_DIR)/python_libs_arm64_$(PY_ABI)
endif

all: compile_cpp bundle_python_libs

$(BIN_DIR):
	@mkdir -p $@

compile_cpp: | $(BIN_DIR)
	g++ -Wall -Wno-c++11-narrowing -std=c++17 -fPIE \
	    $(PY_CFLAGS) \
	    -DMESS_PYTHON_EXECUTABLE='"$(PY_EXECUTABLE)"' \
	    -I libs/paraver-kernel/utils/traceparser \
	    -I libs/boost_1_79_0 \
	    -I libs/json-develop \
	    -o $(BIN_DIR)/mess-prv $(SRC_CPP_FILES) $(SRC_CC_FILES) \
	    $(PY_LDFLAGS) \
	    $(shell if [[ $$(uname) == Linux ]] && [[ $$(g++ -dumpversion | cut -d. -f1) -lt 8 ]]; then echo -lstdc++fs; fi)

install_mess:
	@command -v pip >/dev/null 2>&1 || { echo "pip is required but not installed."; exit 1; }
	@echo "Installing Python dependencies from $(MESS_PATH)..."
	@$(PYTHON) -m pip install -e $(MESS_PATH)

bundle_python_libs: | $(BIN_DIR)
	@echo "Bundling wheels into $(WHEEL_DIR)"
	@rm -rf "$(WHEEL_DIR)"
	@mkdir -p "$(WHEEL_DIR)"
	@$(PYTHON) -m pip install --upgrade --no-compile --no-cache-dir --target="$(WHEEL_DIR)" -r $(REQ_FILE)
	@echo "Installing MESS into $(WHEEL_DIR)..."
	@$(PYTHON) -m pip install --upgrade --no-compile --no-cache-dir --no-deps --target="$(WHEEL_DIR)" "$(MESS_PATH)"

clean:
	@echo "Cleaning up..."
	@rm -rf $(BIN_DIR)/
	@echo "Done."

.PHONY: all compile_cpp install_mess bundle_python_libs clean
