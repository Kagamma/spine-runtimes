cmake_minimum_required(VERSION 3.17)
project(spine)

set(CMAKE_INSTALL_PREFIX "./")
set(CMAKE_VERBOSE_MAKEFILE ON)
set(SPINE_SANITIZE FALSE CACHE BOOL FALSE)
set(CMAKE_WINDOWS_EXPORT_ALL_SYMBOLS ON)
# set(CMAKE_SYSTEM_PROCESSOR "arm64-v8a")

if(MSVC)
	message("MSCV detected")
	set (CMAKE_C_FLAGS "${CMAKE_C_FLAGS}")
	set (CMAKE_C_FLAGS "${CMAKE_CXX_FLAGS}")
else()
	set (CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -O3 -DNDEBUG -Wall -Wunused-value -Wno-c++11-long-long -Wno-variadic-macros -pedantic -Wshadow -std=c89")
	set (CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wall -Wunused-value -Wno-c++11-long-long -Wno-variadic-macros -Wnon-virtual-dtor -pedantic -Wshadow -std=c++11 -fno-exceptions -fno-rtti")

	if (${SPINE_SANITIZE})
		set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -fsanitize=address -fsanitize=undefined")
		set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fsanitize=address -fsanitize=undefined")
	endif()
endif()

add_subdirectory(spine-c)
