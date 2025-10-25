set PATH=%PATH%;C:\dev\tools\libtorch\lib
buysell C:\dev\repos\buy-sell\ohlc.csv --train-start 100 --train-end 800 --test-start  800 --test-end   1000 --W 64 --H 12 --epochs 10 --hidden 64
