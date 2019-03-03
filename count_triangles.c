#include <stdio.h>
#include <stdlib.h>
#include <sys/time.h>

void load(char* file);
int count();
void gen_colind();

int *A;
int nnz;
int *colind;

struct timeval startwtime, endwtime;
double seq_time;

int main(int argc, char **argv){

    if(argc != 2){
        printf("Usage: %s [filename]\n",argv[0]);
        printf("Quiting...\n");
        exit(1);
    }

    load(argv[1]);
    gen_colind();

    gettimeofday (&startwtime, NULL);
    int nt = count();
    gettimeofday (&endwtime, NULL);

    seq_time = (double)((endwtime.tv_usec - startwtime.tv_usec)/1.0e3
				+ (endwtime.tv_sec - startwtime.tv_sec)*1.0e3);

    printf("Found %d triangles in %f ms\n",nt,seq_time);

    free(A);
    free(colind);
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


int count(){

    int csum = 0;

    int lastcol = A[2*nnz-1];
    int i,j,k,l;
    int nextk,nextl;
    for(int e = 0; e < nnz; e++){

        i = A[e];
        j = A[nnz + e];

        k = colind[j-1];
        l = colind[i-1];

        nextk = (j != lastcol)?colind[j]:nnz;
        nextl = (i != lastcol)?colind[i]:nnz;

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

    }
    return csum/6;
}
