/*
 
 Universidad del Valle de Guatemala
 CC3056
 Ana Lucia Hernandez. 17138.
 Andrea Argüello. 17801.
 Proyecto 3
 Programación de Microprocesadores
 
*/


#include <iostream>
#include <stdio.h>
#include <string>
#include <string.h>
#include <errno.h>
#include <stdint.h>
#include <stdlib.h>
#include <time.h>
#include <chrono>
#include <io.h>
#include <cuda_runtime.h>
#include <fstream>

#define N 101 //cantidad de datos en los dos dias (serian 192)

using namespace std;

struct regresionLineal
{
    double pendiente;
    double intercepto;
};

regresionLineal calculoRegresion(float *x, float *y)
{
    double m,b; //variables de pendiente e intercepto
    regresionLineal reg = regresionLineal();
    //suma de productos x,y
    double sumx =0;
    double sumy =0;
    double sumx_2 =0;
    double sumProd =0;
    for(int i =0; i<N; i++)
    {
        sumx += (double)x[i];
        sumy += (double)y[i];
        sumProd += (double)x[i]*y[i];
        sumx_2 += (double)x[i]*x[i];
    }
    /* calculo de la pendiente */
    m =(N*sumProd)-(sumx*sumy)/((N*sumx_2)-(sumx*sumx));
    /* calculo del intercepto */
    b = (sumy - (m*sumx))/N;
    reg.pendiente = m;
    reg.intercepto = b;
    return reg;
}

__global__ void prediccion(float *y, float *x, double m, double b)//y es el vector donde se guarda la prediccion
{
    y[(int)threadIdx.x] = ((float)m*x[(int)threadIdx.x]) + (float)b; //ecuacion de una recta
}


int main(int argv, char* argc[])
{
	printf("Iniciando");
    /* creacion streams */
    cudaStream_t stream1, stream2, stream3;
    cudaStreamCreate(&stream1);
    cudaStreamCreate(&stream2);
    cudaStreamCreate(&stream3);
    
    /* variables del host */
    float *dev_temp, *dev_hum, *dev_pres, *dev_secs; // pointers del device
    float *temp, *hum, *pres, *secs;
    string *fechas;
    
    /* reservas en memoria de los arrays a utilizar en host y pasar al device */
    cudaHostAlloc( (void**)&fechas, N * sizeof(int), cudaHostAllocDefault );// reserva de memoria de fechas
    cudaHostAlloc( (void**)&secs, N * sizeof(int), cudaHostAllocDefault );// reserva de memoria de segundos
    cudaMalloc( (void**)&dev_secs, N * sizeof(int) );
    //stream 1
    cudaMalloc( (void**)&dev_temp, N * sizeof(int) );
    cudaHostAlloc( (void**)&temp, N * sizeof(int), cudaHostAllocDefault );
    
    //stream 2
    cudaMalloc( (void**)&dev_hum, N * sizeof(int) );
    cudaHostAlloc( (void**)&hum, N * sizeof(int), cudaHostAllocDefault);
    
    
    //stream 3
    cudaMalloc( (void**)&dev_pres, N * sizeof(int) );
    cudaHostAlloc( (void**)&pres, N * sizeof(int), cudaHostAllocDefault);

printf("Streams terminados");
    
    /* lectura de datos del csv */
    int i = 0; //indice
    string humedad, presion, temperatura, fecha;
    ifstream file("datos.csv");
printf("Leyendo CSV");
    while (getline(file, humedad, ',')) {
		printf("\nIM COMING IN\n");
        std::size_t offset = 0;
        hum[i] = stod(humedad,&offset);
		printf("STOD1:%.2f\n", hum[i]);
        offset = 0;
        getline(file, presion, ',') ;
        pres[i] = stod(presion,&offset);
		printf("STOD2:%.2f\n", pres[i]);
        offset = 0;
        getline(file, temperatura, ',') ;
        temp[i] = stod(temperatura,&offset);
		printf("STOD3:%.2f\n", temp[i]);
        getline(file, fecha);
        fechas[i] = fecha;
		printf("Fecha: %s\n", fechas[i].c_str());
		printf("%d\n",i);
        i++;
    }

printf("CSV leido");

    for (int i =0; i <N; i++)
    {
        secs[i] = 900*i;
    }

printf("Calculando regresion");
    /* calculo de la regresion lineal para temperatura, presion y humedad */
    regresionLineal regHum = calculoRegresion(hum, secs);
    regresionLineal regPres = calculoRegresion(pres, secs);
    regresionLineal regTemp = calculoRegresion(temp, secs);
    
    /* lanzamiento de kernels para la prediccion
        se lanzaran N threads en los que cada uno calculara la prediccion en la hora correspondiente de su variable correspondiente. */

   printf("Pasando a Device");
 cudaMemcpyAsync(dev_hum,hum,N*sizeof(int),cudaMemcpyHostToDevice,stream1);
    cudaMemcpyAsync(dev_pres,pres,N*sizeof(int),cudaMemcpyHostToDevice,stream2);
    cudaMemcpyAsync(dev_temp,temp,N*sizeof(int),cudaMemcpyHostToDevice,stream3);
    cudaMemcpyAsync(dev_secs,secs,N*sizeof(int),cudaMemcpyHostToDevice,stream1);
    cudaMemcpyAsync(dev_secs,secs,N*sizeof(int),cudaMemcpyHostToDevice,stream2);
    cudaMemcpyAsync(dev_secs,secs,N*sizeof(int),cudaMemcpyHostToDevice,stream3);

printf("Kernels");

    prediccion<<<1, N, 0, stream1>>>(dev_hum, dev_secs, regHum.pendiente, regHum.intercepto);
    prediccion<<<1, N, 1, stream2>>>(dev_pres, dev_secs, regPres.pendiente, regPres.intercepto);
    prediccion<<<1, N, 2, stream3>>>(dev_temp, dev_secs, regTemp.pendiente, regTemp.intercepto);

printf("Device a Host");

cudaMemcpyAsync(hum,dev_hum,N*sizeof(int),cudaMemcpyDeviceToHost,stream1);
    cudaMemcpyAsync(pres,dev_pres,N*sizeof(int),cudaMemcpyDeviceToHost,stream2);
    cudaMemcpyAsync(temp,dev_temp,N*sizeof(int),cudaMemcpyDeviceToHost,stream3);
    
printf("Prints");

for(int i=0; i<N; i++)
{
	printf("Humedad dia %d: %.2f\n", i, hum[i]);
	printf("Presion dia %d: %.2f\n", i, pres[i]);
	printf("Temperatura dia %d: %.2f\n", i, temp[i]);
}
    /* display de prediccion o escritura en un nuevo .csv */
    
    
    
    cudaStreamSynchronize(stream1); // wait for stream1 to finish
    cudaStreamSynchronize(stream2); // wait for stream2 to finish
    cudaStreamSynchronize(stream3); // wait for stream2 to finish
    cudaStreamDestroy(stream1);
    cudaStreamDestroy(stream2);
    cudaStreamDestroy(stream3);
    cudaFree(dev_hum);
    cudaFree(dev_temp);
    cudaFree(dev_pres);
    cudaFree(dev_secs);
    return 0;
}
