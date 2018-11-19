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
#define T 101 //cantidad de datos del tercer dia (serian 96)
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

__global__ void porcentajeError(float *resultado, float *teorico, float *predic)//el array predic tiene 192 datos pero solo se usaran los primeros 96, el teorico tiene 96 datos 
{
    int myID = threadIdx.x; //deberian ser 96?
    if(myID<T){
        resultado[myID]=abs(teorico[myID]-predic[myID])*100/teorico[myID];
    }
}

__global__ void prediccion(float *y, float *x, double m, double b)//y es el vector donde se guarda la prediccion
{
    y[(int)threadIdx.x] = ((float)m*x[(int)threadIdx.x]) + (float)b; //ecuacion de una recta
}


int main(int argv, char* argc[])
{
    /* creacion streams, un stream por variable */
    cudaStream_t stream1, stream2, stream3;
    cudaStreamCreate(&stream1);
    cudaStreamCreate(&stream2);
    cudaStreamCreate(&stream3);
    
    /* variables del host */
    float *dev_temp, *dev_hum, *dev_pres, *dev_secs, *dev_errorTemp, *dev_errorHum, *dev_errorPres; // pointers del device
    //float *dev_temp3, *dev_hum3, *dev_pres3;
    float *temp, *hum, *pres, *secs;
    string fechas[N];
    //float temp3[T],hum3[T],pres3[T],fechas3[T],secs3[T];
    float errorTemp[T],errorHum[T],errorPres[T];
    
    /* reservas en memoria de los arrays a utilizar en host y pasar al device */
    cudaHostAlloc( (void**)&fechas, N * sizeof(int), cudaHostAllocDefault );// reserva de memoria de fechas
    cudaHostAlloc( (void**)&secs, N * sizeof(int), cudaHostAllocDefault );// reserva de memoria de segundos
    cudaMalloc( (void**)&dev_secs, N * sizeof(int) );
    
    //stream 1
    cudaMalloc( (void**)&dev_temp, N * sizeof(int) );
    cudaHostAlloc( (void**)&temp, N * sizeof(int), cudaHostAllocDefault );
    cudaMalloc( (void**)&dev_errorTemp, T*sizeof(int) );
    cudaHostAlloc( (void**)&errorTemp, T*sizeof(int), cudaHostAllocDefault );

    
    //stream 2
    cudaMalloc( (void**)&dev_hum, N * sizeof(int) );
    cudaHostAlloc( (void**)&hum, N * sizeof(int), cudaHostAllocDefault);
    cudaMalloc( (void**)&dev_errorHum, T*sizeof(int) );
    cudaHostAlloc( (void**)&errorHum, T*sizeof(int), cudaHostAllocDefault );

    
    //stream 3
    cudaMalloc( (void**)&dev_pres, N * sizeof(int) );
    cudaHostAlloc( (void**)&pres, N * sizeof(int), cudaHostAllocDefault);
    cudaMalloc( (void**)&dev_errorPres, T*sizeof(int) );
    cudaHostAlloc( (void**)&errorPres, T*sizeof(int), cudaHostAllocDefault );


    
    /* lectura de datos del csv */
    int i = 0; //indice
    string humedad, presion, temperatura, altitud, fecha;
    ifstream file("datos.csv");

    while (getline(file, humedad, ',')) {
        //hay que revisar si no esta jalando los datos de altitud, los cuales no sirven
        std::size_t offset = 0;
        hum[i] = stod(humedad,&offset);
        offset = 0;
        getline(file, presion, ',') ;
        pres[i] = stod(presion,&offset);
        offset = 0;
        getline(file, temperatura, ',') ;
        temp[i] = stod(temperatura,&offset);
        getline(file, altitud, ',');
        getline(file, fecha);
        fechas[i] = fecha;
        printf("\ni: %d, Humedad: %.2f, Presion: %.2f, Temp: %.2f, Fecha: %s", i, hum[i], pres[i], temp[i], fechas[i].c_str());
        i++;
    }

/* lectura de datos del csv del tercer dia*/
/*
    int i = 0; //indice
    string humedad3, presion3, temperatura3, altitud3, fecha3;
    ifstream file("dia3.csv");

    while (getline(file, humedad3, ',')) {
        //hay que revisar si no esta jalando los datos de altitud, los cuales no sirven
        std::size_t offset = 0;
        hum3[i] = stod(humedad3,&offset);
        offset = 0;
        getline(file, presion3, ',') ;
        pres3[i] = stod(presion3,&offset);
        offset = 0;
        getline(file, temperatura3, ',') ;
        temp3[i] = stod(temperatura3,&offset);
        getline(file, altitud3, ',');
        getline(file, fecha3);
        fechas3[i] = fecha3;
        printf("\ni: %d, Humedad: %.2f, Presion: %.2f, Temp: %.2f, Fecha: %s", i, hum3[i], pres3[i], temp3[i], fechas3[i].c_str());
        i++;
    }
*/

    /* segundos de las primeras 48hr */
    for (int i =0; i <N; i++)
    {
        secs[i]=900*i;
	/*Ya con los datos de los primeros dos dias
	  if(i<N/2){
        secs[i] = 900*i;}
	  else{
	   secs[i]=900*(i-N/2)+1;//ajuste para que el segundo dia no caiga en la misma hora
       }*/
    }

/*Segundos del tercer dia
for (int i=0; i<T; i++){
        secs3[i]=900*i-1; //ajuste para que no caiga a la misma hora que el dia 1 o dos
}*/

    /* calculo de la regresion lineal para temperatura, presion y humedad */
    regresionLineal regHum = calculoRegresion(hum, secs);
    regresionLineal regPres = calculoRegresion(pres, secs);
    regresionLineal regTemp = calculoRegresion(temp, secs);

    /* ajustar el vector de segundos para que ahora sean los segundos del tercer dia (prediccion) */
    for (int i =0; i <N; i++)
    {
        secs[i] = (192*900)+ (900*i); //48hr + segs del tercer dia
    }
    /* lanzamiento de kernels para la prediccion
        se lanzaran N threads en los que cada uno calculara la prediccion en la hora correspondiente de su variable correspondiente. */

    cudaMemcpyAsync(dev_hum,hum,N*sizeof(int),cudaMemcpyHostToDevice,stream1);
    cudaMemcpyAsync(dev_pres,pres,N*sizeof(int),cudaMemcpyHostToDevice,stream2);
    cudaMemcpyAsync(dev_temp,temp,N*sizeof(int),cudaMemcpyHostToDevice,stream3);
    cudaMemcpyAsync(dev_secs,secs,N*sizeof(int),cudaMemcpyHostToDevice,stream1);
    cudaMemcpyAsync(dev_secs,secs,N*sizeof(int),cudaMemcpyHostToDevice,stream2);
    cudaMemcpyAsync(dev_secs,secs,N*sizeof(int),cudaMemcpyHostToDevice,stream3);

    cudaMemcpyAsync(dev_errorHum,errorHum,T*sizeof(int),cudaMemcpyHostToDevice,stream1);
    cudaMemcpyAsync(dev_errorPres,errorPres,T*sizeof(int),cudaMemcpyHostToDevice,stream2);
    cudaMemcpyAsync(dev_errorTemp,errorTemp,T*sizeof(int),cudaMemcpyHostToDevice,stream3);

    prediccion<<<1, N, 0, stream1>>>(dev_hum, dev_secs, regHum.pendiente, regHum.intercepto);
    prediccion<<<1, N, 1, stream2>>>(dev_pres, dev_secs, regPres.pendiente, regPres.intercepto);
    prediccion<<<1, N, 2, stream3>>>(dev_temp, dev_secs, regTemp.pendiente, regTemp.intercepto);

    porcentajeError<<<1,N,0,stream1>>>(dev_errorHum,dev_hum,dev_hum); //cambiar segundo valor por el teorico
    porcentajeError<<<1,N,0,stream2>>>(dev_errorPres,dev_pres,dev_pres); //cambiar segundo valor por el teorico
    porcentajeError<<<1,N,0,stream3>>>(dev_errorTemp,dev_temp,dev_temp); //cambiar segundo valor por el teorico


    cudaMemcpyAsync(hum,dev_hum,N*sizeof(int),cudaMemcpyDeviceToHost,stream1);
    cudaMemcpyAsync(pres,dev_pres,N*sizeof(int),cudaMemcpyDeviceToHost,stream2);
    cudaMemcpyAsync(temp,dev_temp,N*sizeof(int),cudaMemcpyDeviceToHost,stream3);

    cudaMemcpyAsync(errorHum,dev_errorHum,T*sizeof(int),cudaMemcpyDeviceToHost,stream1);
    cudaMemcpyAsync(errorPres,dev_errorPres,T*sizeof(int),cudaMemcpyDeviceToHost,stream2);
    cudaMemcpyAsync(errorTemp,dev_errorTemp,T*sizeof(int),cudaMemcpyDeviceToHost,stream3);


    /* display de prediccion o escritura en un nuevo .csv */
    //falta agregarle la fecha y hora para cada prediccion
    ofstream MiArchivo ("prediccion.csv");
    for(int i=0; i<T; i++)
    {
        if (MiArchivo.is_open())
        {
            MiArchivo <<hum[i]<<","<< errorHum[i]<<","<<pres[i]<<","<<errorPres[i]<<","<<temp[i]<<","<<errorTemp[i]<<","<<secs[i]<<"\n";
        }
    }
    MiArchivo.close();
    
    
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
    cudaFree(dev_errorTemp);
    cudaFree(dev_errorPres);
    cudaFree(dev_errorHum);
    return 0;
}
