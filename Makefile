# TODO: Check for
# fastcgi.h - libfcgi-dev
# curl.h    - libcurl*-dev
PRODUCT               =k7
VERSION               =20090415

PLATFORM              =$(shell uname -s)
CPP                   =g++
CPPFLAGS              =
CPPFLAGS              += -DK7_VERSION=$(VERSION)
BUILD_DIR             =build
BUILD_LIBS            =-lpthread -ldl
# NOTE: On OSX, I think -liconv is necessary, search for Darwin in Makefile
BUILD_BINLIBS         =$(V8_BINARY) deps/shttpd/src/libshttpd.a

V8_INCLUDE            =deps/v8/include
V8_BINARY             =deps/v8/libv8.a
JS2H                  =tools/js2h
SOURCES               =$(wildcard src/*.cpp)
SOURCES_API           =$(shell find lib -name "*.api")
HEADERS               =$(wildcard src/*.h)
MODULES               =$(wildcard lib/*.cpp lib/*/*.cpp lib/*/*/*.cpp lib/*/*/*/*.cpp)
MODULES_JS            =$(wildcard lib/*.js lib/*/*.js lib/*/*/*.js lib/*/*/*/*.js)
MODULES_JS_H          =$(MODULES_JS:lib/%.js=build/include/%.js.h)
OBJECTS               =$(SOURCES:src/%.cpp=build/%.o)
SOBJECTS              =$(MODULES:lib/%.cpp=build/%.o)
INCLUDES              =-I$(V8_INCLUDE) -Isrc -Ideps

# Modules
HAS_CURL              =$(shell locate include/curl/curl.h)
HAS_FCGI              =$(shell locate include/fastcgi.h)
HAS_LIBTASK           =1
ifeq  ($(PLATFORM),Darwin)
	BUILD_LIBS        +=-liconv
endif
ifneq ($(strip $(HAS_CURL)),)
	CPPFLAGS          +=-DWITH_CURL
	BUILD_LIBS        +=-lcurl
endif
ifneq ($(strip $(HAS_FCGI)),)
	CPPFLAGS          +=-DWITH_FCGI
	BUILD_LIBS        +=-lfcgi
endif
ifeq ($(HAS_LIBTASK),1)
	CPPFLAGS          += -DWITH_LIBTASK
	BUILD_BINLIBS     += deps/libtask/libtask.a
endif

all: $(OBJECTS) $(SOBJECTS) $(BUILD_BINLIBS) $(V8_BINARY)
	$(CPP) $(CPPFLAGS) $(INCLUDES) $(OBJECTS) $(SOBJECTS) -o $(PRODUCT) $(BUILD_BINLIBS) $(BUILD_LIBS)

info:
	@echo "Modules (native): $(MODULES)"
	@echo "Modules (js):     $(MODULES_JS)"
	@echo "Sources:          $(SOURCES)"
	@echo "API:              $(SOURCES_API)"

api: doc/k7-api.html
	

build:
	mkdir build

clean:
	rm -rf build

deps:
	mkdir deps

compact: k7
	strip $<
	upx --version && upx $<

deps/v8:
	#cd deps && svn checkout http://v8.googlecode.com/svn/trunk v8
	cd deps && svn checkout http://v8.googlecode.com/svn/branches/bleeding_edge v8

deps/mongoose:
	cd deps && svn checkout http://mongoose.googlecode.com/svn/trunk/ mongoose

deps/shttpd/src/libshttpd.a:
	cd deps/shttpd/src && make unix LIBS="-ldl -lpthread"

deps/shttpd:
	cd deps && wget 'http://voxel.dl.sourceforge.net/sourceforge/shttpd/shttpd-1.42.tar.gz' && tar fvxz shttpd-1.42.tar.gz && rm shttpd-1.42.tar.gz && mv shttpd-1.42 shttpd
deps/v8/libv8.a: deps/v8
	cd deps/v8 && scons

deps/libtask/libtask.a: deps/libtask
	cd deps/libtask && make

build/%.o: src/%.cpp $(HEADERS) build deps/v8
	$(CPP) $(CPPFLAGS) $(INCLUDES) -c $< -o $@

#g++ $(INCLUDES) -fPIC $< -o $@ $(V8_BINARY) $(BUILD_LIBS)
build/%.o: lib/%.cpp  $(HEADERS)
	@mkdir -p `dirname $@` || true
	@# Using ifeq or sh if did not work... had to resort to this :/
	@test -e lib/$*.js && mkdir -p `dirname build/include/$*` || true
	@test -e lib/$*.js && $(JS2H) lib/$*.js > build/include/$*.js.h || true
	$(CPP) $(CPPFLAGS) $(INCLUDES) -Ibuild/include/$(dir $*) -c $< -o $@

build/include/%.js.h: lib/%.js $(JS2H)
	@mkdir -p `dirname $@` || true
	$(JS2H) $< > $@

doc/k7-api.html: $(SOURCES_API)
	@mkdir -p `dirname $@` || true
	sugar -a$@ -ljs $(SOURCES_API)

# EOF
