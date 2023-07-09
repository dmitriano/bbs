#!/bin/bash
CPP_FILE=$1
OUT_FILE=$(basename "$CPP_FILE" .cpp)
g++ -std=c++20 -pthread $CPP_FILE -o $OUT_FILE


