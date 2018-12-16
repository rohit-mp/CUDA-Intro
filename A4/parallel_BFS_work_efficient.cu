#include<bits/stdc++.h>
using namespace std;

#define MAX_VAL 1e9

__global__ void compute(int *d_r, int *d_c, int *d_depth, int *max_depth, int *Q1, int *Q2, int nodes){
    int idx = threadIdx.x;
    __shared__ int len1, len2, curr_depth;
    int i;
    
    for(i=idx; i<nodes; i+=1024){
        d_depth[i] = MAX_VAL;
    }
    if(idx == 0){
        d_depth[0] = 0;
        curr_depth = 0;
        len1 = 1;
        len2 = 0;
        Q1[0] = 0;
    }
    __syncthreads();

    do{
        /*if(idx<len1){
            for(int j=d_r[Q1[idx]]; j<d_r[Q1[idx]+1]; j++){
                d_depth[d_c[j]] = curr_depth+1;
                Q2[len2++] = d_c[j];
            }
        }*/
        for(i=idx; i<nodes; i+=1024){
            if(i<len1){
                for(int j=d_r[Q1[i]]; j<d_r[Q1[i]+1]; j++){
                    if(atomicCAS(&d_depth[j], MAX_VAL, d_depth[i]+1) == MAX_VAL){
                        int t = atomicAdd(&len2,1);
                        Q2[t] = j;  
                    }
                }
            }
            else break;
        }
        __syncthreads();

        if(idx==0){
            for(i=0; i<len2; i++){
                Q1[i] = Q2[i];
            }
            len1 = len2;
            len2 = 0;
            curr_depth++;
        }
        __syncthreads();
    }while(len1);

    max_depth[0] = curr_depth-1;
}

int main(int argc, char *argv[]){
    if(argc<2){
        cout << "Usage: " << argv[0] << " <graph_file_name>\n";
        return 0;
    }

    ifstream input;
    input.open(argv[1]);

    int nodes, edges, i;
    input >> nodes;
    input >> edges;

    int *h_r = (int*)malloc((nodes+1)*sizeof(int));
    int *h_c = (int*)malloc(edges*2*sizeof(int));

    for(i=0; i<nodes+1; i++){
        input >> h_r[i];
    }
    for(i=0; i<edges*2; i++){
        input >> h_c[i];
    }
    
    int *Q1, *Q2, *d_r, *d_c, *d_depth, *max_depth;
    cudaMalloc((void**)&Q1, nodes*sizeof(int));
    cudaMalloc((void**)&Q2, nodes*sizeof(int));
    cudaMalloc((void**)&d_r, (nodes+1)*sizeof(int));
    cudaMalloc((void**)&d_c, edges*2*sizeof(int));
    cudaMalloc((void**)&d_depth, nodes*sizeof(int));
    cudaMalloc((void**)&max_depth, sizeof(int));

    cudaMemcpy(d_r, h_r, (nodes+1)*sizeof(int), cudaMemcpyHostToDevice);
    cudaMemcpy(d_c, h_c, edges*2*sizeof(int), cudaMemcpyHostToDevice);

    printf("Starting Computation\n");
    compute <<<1, 1024>>> (d_r, d_c, d_depth, max_depth, Q1, Q2, nodes);
    printf("Finished Computation\n");

    int *result = (int *)malloc(sizeof(int));
    printf("done\n");
    cudaMemcpy(result, max_depth, sizeof(int), cudaMemcpyDeviceToHost);

    printf("Depth : %d\n", result[0]);

    
    int *h_depth = (int*) malloc(nodes*sizeof(int));
	cudaMemcpy(h_depth, d_depth, nodes*sizeof(int), cudaMemcpyDeviceToHost);
	int *h_check_depth = (int*)malloc(nodes*sizeof(int));
	freopen(argv[2], "r", stdin);

	for(int i = 0; i < nodes; i++) {
		cin>>h_check_depth[i];
    }
    printf("Finished reading output file\n");
	bool flag = true;
	int count = 0;

    printf("Starting checking\n");
	for(int i = 0; i < nodes; i++) {
		if(h_depth[i] != h_check_depth[i]) {
            printf("Found %d, Expected %d\n",h_depth[i], h_check_depth[i]);
			flag = false;
			count++;
		}
    }
    printf("Finished checking\n");

	if(flag) {
		cout<<"Solution is correct!\n";
	}
	else {
		cout<<"Solution is incorrect!"<<endl;
		cout<<count<<" testcases failed.\n";
	}
    return 0;   
}