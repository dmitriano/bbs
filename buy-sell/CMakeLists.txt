cmake_minimum_required(VERSION 3.18)
project(buysell CXX)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Укажи путь к распакованному LibTorch:
# cmake -DCMAKE_PREFIX_PATH=/path/to/libtorch ..
find_package(Torch REQUIRED)

add_executable(buysell main.cpp)
target_link_libraries(buysell "${TORCH_LIBRARIES}")

# === убираем warning C4267 и C4244 на MSVC ===
if(MSVC)
    target_compile_options(buysell PRIVATE /wd4267 /wd4244)
endif()

# (опционально — чтобы не было "unsafe" CRT предупреждений)
if(MSVC)
    target_compile_definitions(buysell PRIVATE _CRT_SECURE_NO_WARNINGS)
endif()
