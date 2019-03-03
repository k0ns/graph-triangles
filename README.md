# graph-triangles
count triangles in graph using CUDA


## Compilation 

For the serial algorithm:
```bash
gcc -O3 count_triangles.c -o cnt
```

For the CUDA algorithm:
```bash
nvcc -O3 cu_count_triangles.c -o cuda_cnt
```

## Usage 
```bash
./cuda_cnt [filename]
```

## Data
Data files were too large to upload so [here](https://www.dropbox.com/sh/as8yyotojk53kom/AAB-jU0RdvO5GxiApBzDWqioa?dl=0)'s a link
