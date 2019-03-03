#include <stdio.h>
#include <stdlib.h>
#include <sys/time.h>
#include <cuda.h>

void load(char* file);
__global__ void count(int *A, int *colind,int *block_sums, int nnz);
void gen_colind();

int *A;
int nnz;
int *colind;

struct timeval startwtime, endwtime;
double seq_time;

#define TPB 1024
#define NB 1024

__global__ void count(int *A, int *colind, int *block_sums, int nnz){

    int idx = blockDim.x*blockIdx.x + threadIdx.x;
    extern __shared__ int cache[];

    int csum = 0;
    int i,j,k,l;
    int nextk,nextl;

    while(idx < nnz){
        i = A[idx];
        j = A[nnz + idx];

        k = colind[j-1];
        l = colind[i-1];

        nextk = (j == A[2*nnz-1])?nnz:colind[j];
        nextl = (i == A[2*nnz-1])?nnz:colind[i];

        do{
            if(A[k] > A[l]){
                l++;
            }
            else if(A[k] < A[l]){
                k++;
            }
            else{
                csum++;
                k++;
                l++;
            }
        }while(k<nextk && l<nextl);

        idx += blockDim.x*gridDim.x;
    }

    cache[threadIdx.x] = csum;
    __syncthreads();

    //per-block Reduction
    for(int s = blockDim.x/2;s>0;s>>=1){

        if(threadIdx.x < s){
            cache[threadIdx.x] += cache[threadIdx.x + s];
            __syncthreads();
        }

    }
    if(threadIdx.x == 0) block_sums[blockIdx.x] = cache[0];
}

int main(int argc, char **argv){

    if(argc != 2){
        printf("Usage: %s [filename]\n",argv[0]);
        printf("Quiting...\n");
        exit(1);
    }

    load(argv[1]);
    gen_colind();

    int nthreads_block = TPB;
    int nblocks = NB;
    int nt;
    int *block_sums = (int *)malloc(nblocks*sizeof(int));

    int *d_A,*d_colind,*d_block_sums;

    cudaMalloc((void **)&d_A,2*nnz*sizeof(int));
    cudaMalloc((void **)&d_colind,A[2*nnz-1]*sizeof(int));
    cudaMalloc((void **)&d_block_sums,nblocks*sizeof(int));

    cudaMemcpy(d_A,A,2*nnz*sizeof(int),cudaMemcpyHostToDevice);
    cudaMemcpy(d_colind,colind,A[2*nnz-1]*sizeof(int),cudaMemcpyHostToDevice);

    //Call kernel and measure time passed
    gettimeofday (&startwtime, NULL);
    count<<<nblocks,nthreads_block,nthreads_block*sizeof(int)>>>(d_A,d_colind,d_block_sums,nnz);
    cudaDeviceSynchronize();
    gettimeofday (&endwtime, NULL);

    //Copy partial sums to host
    cudaMemcpy(block_sums, d_block_sums, nblocks*sizeof(int), cudaMemcpyDeviceToHost);

    //Sum all block sums to solve problem
    nt = 0;
    for(int i=0;i<nblocks;i++){
        nt += block_sums[i];
    }
    nt /= 6;

    seq_time = (double)((endwtime.tv_usec - startwtime.tv_usec)/1.0e3
				+ (endwtime.tv_sec - startwtime.tv_sec)*1.0e3);

    printf("Found %d triangles in %f ms\n",nt,seq_time);

    free(A);
    free(colind);
    free(block_sums);
    cudaFree(d_A);
    cudaFree(d_colind);
    cudaFree(d_block_sums);
}

void load(char* file){
    FILE *fp;
    int size;

    if((fp = fopen(file,"rb")) == NULL){
        printf("Failed to open file.\nExiting...\n");
        exit(1);
    }

    fseek(fp,0,SEEK_END);
    size = ftell(fp);
    size /= 4;
    fseek(fp,0,SEEK_SET);
    A = (int *)malloc(size*sizeof(int));

    int i = 0;
    int nread;

    for(i=0;i<size;i++){
        nread = fread(&A[i],sizeof(int),1,fp);
        if(nread != 1){
            printf("Error reading file!\nExiting...\n");
            printf("%d\n",i);
            exit(1);
        }
    }

    nnz = size/2;
    fclose(fp);
}

void gen_colind(){

    int lastcol = A[2*nnz-1];
    colind = (int *)malloc(lastcol*sizeof(int));

    int prev = 0;
    for(int i=0;i<nnz;i++){
        if(A[nnz+i] != prev){
            prev = A[nnz+i];
            colind[prev-1] = i;
        }
    }

}
