
# extract python flags for compilation
PY_VERSION_FULL := $(wordlist 2, 4, $(subst ., ,$(shell python3 --version 2>&1)))
PY_VERSION_MAJOR := $(word 1, ${PY_VERSION_FULL})
PY_VERSION_MINOR := $(word 2, ${PY_VERSION_FULL})
# PY_VERSION_PATCH := $(word 3, ${PY_VERSION_FULL})

PY_CFLAGS  := $(shell python3-config --cflags)

# use libs or embed depending on python version
ifeq ($(shell expr $(PY_VERSION_MINOR) \<= 6), 1)
PY_LDFLAGS := $(shell python3-config --ldflags --libs)
else
PY_LDFLAGS := $(shell python3-config --ldflags --embed)
endif

# create bin directory if it does not exist
$(shell mkdir -p bin/)

# get all cpp files in src/ folder and its subdirectories
SRC_CPP_FILES := $(shell find src/ -name '*.cpp')
SRC_CC_FILES := $(shell find src/ -name '*.cc')

# path to the PROFET submodule in the libs folder
PROFET_PATH := libs/PROFET

all: install_profet compile_cpp

clean:
	@echo "Cleaning up..."
	@rm -rf bin/
	@echo "Cleaned up."

install_profet:
	@command -v pip > /dev/null 2>&1 || { echo >&2 "pip is required but not installed. Please install pip and try again."; exit 1; }
	@echo "Installing Python dependencies from ${PROFET_PATH}..."
	@pip install -e ${PROFET_PATH}

compile_cpp:
	g++ -Wall -Wno-c++11-narrowing -fPIE -std=c++17 \
	$(PY_CFLAGS) \
	-I libs/paraver-kernel/utils/traceparser \
	-I libs/boost_1_79_0 \
	-I libs/json-develop/ \
	-o bin/mess-prv $(SRC_CPP_FILES) $(SRC_CC_FILES) $(PY_LDFLAGS)

.PHONY: all install_profet compile_cpp