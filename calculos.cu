/*

 Universidad del Valle de Guatemala
 CC3056
 Ana Lucia Hernandez. 17138.
 Andrea Arg�ello. 17801.
 Proyecto 3
 Programaci�n de Microprocesadores

*/


#include <iostream>
#include <stdio.h>
#include <string>
#include <string.h>
#include <errno.h>
#include <stdint.h>
#include <stdlib.h>
#include <time.h>
#include <io.h>
#include <cuda_runtime.h>
#include <fstream>

#define N 192 //cantidad de datos en los dos dias
#define T 96 //cantidad de datos del tercer dia

using namespace std;

/* El vector y guarda 96 predicciones
 * El vector x contiene los numeros de 0-95, o sea el numero de medicion de 15 minutos a evaluar
 * x192 contiene las mediciones de 15 minutos de los primeros dos dias
 * y192 contiene el valor en y (temperatura, humedad o presion) de los primeros dos dias
 */
__global__ void prediccion(float *y, float *x, float *x192, float *y192)
{
    int myID= (int)threadIdx.x; //
    float m=(y192[myID]-y192[myID+T])/(x192[myID]-x192[myID+T]); //pendiente
    float b=(m*x192[myID])+y192[myID]; //intercepto
    y[myID] = ((float)m*x[myID]) + (float)b; //ecuacion de una recta
}

__global__ void porcentajeError(float *resultado, float *teorico, float *predic)//los tres arrays son/seran de 96 datos
{
    int myID = (int)threadIdx.x; //deberian ser 96
    resultado[myID]=(float) (predic[myID]-teorico[myID])*100/teorico[myID];
}

int main(int argv, char* argc[])
{
    /* creacion streams, un stream por variable
     * (temperatura, presion, humedad) y sus respectivos % de error */
    cudaStream_t stream1, stream2, stream3, stream4, stream5, stream6;
    cudaStreamCreate(&stream1);
    cudaStreamCreate(&stream2);
    cudaStreamCreate(&stream3);
	  cudaStreamCreate(&stream4);
    cudaStreamCreate(&stream5);
    cudaStreamCreate(&stream6);


    /* variables del host */
    float *dev_temp, *dev_hum, *dev_pres, *dev_secs, *dev_secs3, *dev_errorTemp, *dev_errorHum, *dev_errorPres; // pointers del device
    float *dev_temp3, *dev_hum3, *dev_pres3, *dev_tempres, *dev_humres, *dev_presres, *dev_phum, *dev_ppres, *dev_ptemp;
    float *temp, *hum, *pres, *secs, *temp_res, *hum_res, *pres_res, *temp3, *hum3, *pres3;
    string fechas[N], fechas3[T];
    float *errorTemp,*errorHum,*errorPres,secs3[T];

    /* reservas en memoria de los arrays a utilizar en host y pasar al device */
    cudaHostAlloc( (void**)&secs, N * sizeof(int), cudaHostAllocDefault );// reserva de memoria de segundos
    cudaHostAlloc( (void**)&secs3, T * sizeof(int), cudaHostAllocDefault );//segundos del tercer dia
    cudaHostAlloc( (void**)&pres3, T * sizeof(int), cudaHostAllocDefault );//presion teorica dia 3
    cudaHostAlloc( (void**)&temp3, T * sizeof(int), cudaHostAllocDefault );//temperatura teorica dia 3
    cudaHostAlloc( (void**)&hum3, T * sizeof(int), cudaHostAllocDefault);//humedad teorica dia 3

    /*reservas en memoria de arrays de segundos y resultados del device*/
    cudaMalloc( (void**)&dev_secs, N * sizeof(int) );
    cudaMalloc( (void**)&dev_secs3, T * sizeof(int) );
    cudaMalloc( (void**)&dev_humres, T * sizeof(int) );//prediccion de humedad
    cudaMalloc( (void**)&dev_tempres, T * sizeof(int) );//prediccion de temperatura
    cudaMalloc( (void**)&dev_presres, T * sizeof(int) );//prediccion de presion


    //stream 1
    cudaMalloc( (void**)&dev_temp, N * sizeof(int) );
    cudaHostAlloc( (void**)&temp, N * sizeof(int), cudaHostAllocDefault );
    cudaHostAlloc( (void**)&temp_res, T * sizeof(int), cudaHostAllocDefault );



    //stream 2
    cudaMalloc( (void**)&dev_hum, N * sizeof(int) );
    cudaHostAlloc( (void**)&hum, N * sizeof(int), cudaHostAllocDefault );
    cudaHostAlloc( (void**)&hum_res, T * sizeof(int), cudaHostAllocDefault );


    //stream 3
    cudaMalloc( (void**)&dev_pres, N * sizeof(int) );
    cudaHostAlloc( (void**)&pres_res, T * sizeof(int), cudaHostAllocDefault );
    cudaHostAlloc( (void**)&pres, N * sizeof(int), cudaHostAllocDefault);

    //stream 4
    cudaMalloc( (void**)&dev_hum3, T * sizeof(int) ); //humedad dia 3
    cudaMalloc( (void**)&dev_errorHum, T * sizeof(int) ); // % error device
    cudaHostAlloc( (void**)&errorHum, T * sizeof(int), cudaHostAllocDefault ); // % error
    cudaMalloc( (void**)&dev_phum, T * sizeof(int) ); //prediccion de humedad en device

    //stream 5
    cudaMalloc( (void**)&dev_ppres, T * sizeof(int) ); //prediccion de presion en device
    cudaMalloc( (void**)&dev_pres3, T * sizeof(int) ); //presion dia 3
    cudaMalloc( (void**)&dev_errorPres, T * sizeof(int) ); // % error device
    cudaHostAlloc( (void**)&errorPres, T * sizeof(int), cudaHostAllocDefault ); // % error


    //stream 6
    cudaMalloc( (void**)&dev_ptemp, T * sizeof(int) ); //prediccion de temperatura en device
    cudaMalloc( (void**)&dev_temp3, T * sizeof(int) ); //temperatura dia 3
    cudaMalloc( (void**)&dev_errorTemp, T * sizeof(int) ); // % error device
    cudaHostAlloc( (void**)&errorTemp, T * sizeof(int), cudaHostAllocDefault ); // % error


    /* lectura de datos del csv dias 1 y 2*/
    int i = 0; //indice
    string humedad, presion, temperatura, altitud, fecha;
    ifstream file("datos.csv");
    while (getline(file, humedad, ',')) {
        hum[i] = (float)atof(humedad.c_str());
        getline(file, presion, ',') ;
        pres[i] = (float)atof(presion.c_str());
        getline(file, temperatura, ',') ;
        temp[i] = (float)atof(temperatura.c_str());
        getline(file, altitud, ','); //no se almacena
        getline(file, fecha);
        fechas[i] = fecha;
        i++;
    }


    /* lectura de datos del csv del tercer dia*/
    int j = 0; //indice
    ifstream file3("dia3.csv");
    while (getline(file3, humedad, ',')) {
        hum3[j] = (float)atof(humedad.c_str());
        getline(file3, presion, ',') ;
        pres3[j] = (float)atof(presion.c_str());
        getline(file3, temperatura, ',') ;
        temp3[j] = (float)atof(temperatura.c_str());
        getline(file3, altitud, ',');
        getline(file3, fecha);
        fechas3[j] = fecha;
        j++;
    }


    /* segundos de las primeras 48hr */
    for (int i =0; i <N; i++)
    {
        secs[i]=i;
    }


    /* ajustar el vector de segundos para que ahora sean los segundos del tercer dia (prediccion) */
    for (int i =0; i <T; i++)
    {
        secs3[i] = (i+N); //48hr + segs del tercer dia
    }

    /* lanzamiento de kernels para la prediccion
     * se lanzaran N threads en los que cada uno calculara
     * la prediccion en la hora correspondiente de su variable correspondiente. */
    cudaMemcpyAsync(dev_hum,hum,N*sizeof(int),cudaMemcpyHostToDevice,stream1);
    cudaMemcpyAsync(dev_pres,pres,N*sizeof(int),cudaMemcpyHostToDevice,stream2);
    cudaMemcpyAsync(dev_temp,temp,N*sizeof(int),cudaMemcpyHostToDevice,stream3);
    cudaMemcpyAsync(dev_secs,secs,N*sizeof(int),cudaMemcpyHostToDevice,stream1);
    cudaMemcpyAsync(dev_secs,secs,N*sizeof(int),cudaMemcpyHostToDevice,stream2);
    cudaMemcpyAsync(dev_secs,secs,N*sizeof(int),cudaMemcpyHostToDevice,stream3);
    cudaMemcpyAsync(dev_secs3,secs3,T*sizeof(int),cudaMemcpyHostToDevice,stream1);
    cudaMemcpyAsync(dev_secs3,secs3,T*sizeof(int),cudaMemcpyHostToDevice,stream2);
    cudaMemcpyAsync(dev_secs3,secs3,T*sizeof(int),cudaMemcpyHostToDevice,stream3);

    prediccion<<<1, T, 0, stream1>>>(dev_humres, dev_secs3, dev_secs, dev_hum);
    prediccion<<<1, T, 1, stream2>>>(dev_presres, dev_secs3, dev_secs, dev_pres);
    prediccion<<<1, T, 2, stream3>>>(dev_tempres, dev_secs3, dev_secs, dev_temp);
	cudaMemcpyAsync(hum_res,dev_humres,T*sizeof(int),cudaMemcpyDeviceToHost,stream1);
    cudaMemcpyAsync(pres_res,dev_presres,T*sizeof(int),cudaMemcpyDeviceToHost,stream2);
    cudaMemcpyAsync(temp_res,dev_tempres,T*sizeof(int),cudaMemcpyDeviceToHost,stream3);


    cudaStreamSynchronize(stream1); // wait for stream1 to finish
    cudaStreamSynchronize(stream2); // wait for stream2 to finish
    cudaStreamSynchronize(stream3); // wait for stream3 to finish

    /* realizacion y lanzamiento de kernels de porcentaje de error */
    cudaMemcpyAsync(dev_phum,hum_res,T*sizeof(int),cudaMemcpyHostToDevice,stream4);
    cudaMemcpyAsync(dev_ppres,pres_res,T*sizeof(int),cudaMemcpyHostToDevice,stream5);
    cudaMemcpyAsync(dev_ptemp,temp_res,T*sizeof(int),cudaMemcpyHostToDevice,stream6);
    cudaMemcpyAsync(dev_hum3,hum3,T*sizeof(int),cudaMemcpyHostToDevice,stream4);
    cudaMemcpyAsync(dev_pres3,pres3,T*sizeof(int),cudaMemcpyHostToDevice,stream5);
    cudaMemcpyAsync(dev_temp3,temp3,T*sizeof(int),cudaMemcpyHostToDevice,stream6);

    //3 kernels de un bloque de T hilos, un hilo por cada dato

	  porcentajeError<<<1, T, 0, stream4>>>(dev_errorHum, dev_hum3, dev_phum);
	  porcentajeError<<<1, T, 0, stream5>>>(dev_errorPres, dev_pres3, dev_ppres);
    porcentajeError<<<1, T, 0, stream6>>>(dev_errorTemp, dev_temp3, dev_ptemp);

	  cudaMemcpyAsync(errorHum,dev_errorHum,T*sizeof(int),cudaMemcpyDeviceToHost,stream4);
    cudaMemcpyAsync(errorPres,dev_errorPres,T*sizeof(int),cudaMemcpyDeviceToHost,stream5);
    cudaMemcpyAsync(errorTemp,dev_errorTemp,T*sizeof(int),cudaMemcpyDeviceToHost,stream6);

    //Esperar a finalizacion de streams
    cudaStreamSynchronize(stream5);
    cudaStreamSynchronize(stream4);
    cudaStreamSynchronize(stream6);


    //Impresion de datos
    printf("\t\t\t\t\t\t\tPROYECTO FINAL MICROPROCESADORES");
    printf("\n\t\t\t\t\t\tAndrea Arguello 17801 \t Ana Lucia Hernandez 17138\n");

    printf("\n|\t\t\t\t\t\t\tDATOS TOMADOS DE LOS PRIMEROS DOS DIAS\t\t\t\t\t\t|");
    printf("\n|    Minutos\t|\t\t\t\tDIA 1\t\t\t|\t\t\t\tDIA 2\t\t\t|");
    for(int i=0; i<T; i++){
      printf("\n|\t%d.\t|\tH: %.2f\tP: %.2f\tT: %.2f\t|\tH: %.2f\tP: %.2f\tT: %.2f\t|",i*15,hum[i],pres[i],temp[i],hum[i+T],pres[i+T],temp[i+T]);
    }

    printf("\n\n\n|\t\t\t\t\t\t\t\t\t\tPREDICCIONES Y VALORES TEORICOS DEL TERCER DIA\t\t\t\t\t\t\t\t\t\t|");
    printf("\n|Min.\t|\t\t\t\tHUMEDAD\t\t\t\t|\t\t\t\tPRESION\t\t\t\t|\t\t\t\tTEMPERATURA\t\t\t|\n");
    ofstream MiArchivo ("prediccion.csv");
    for(int i=0; i<T; i++)
    {
        if (MiArchivo.is_open())
        {
            MiArchivo <<hum_res[i]<<","<< errorHum[i]<<","<<pres_res[i]<<","<<errorPres[i]<<","<<temp_res[i]<<","<<errorTemp[i]<<","<<(secs[i]+192)*900<<"\n";
            printf("| %d.\t|  Teorica %.2f\tPrediccion %.2f (%.2f%% de error)\t|\tTeorica %.2f\tPrediccion %.2f (%.2f%% de error)\t|\tTeorica %.2f\tExperimental %.2f (%.2f%% de error)\t|\n",(int)secs[i]*15, hum3[i], hum_res[i], errorHum[i], pres3[i], pres_res[i], errorPres[i], temp3[i], temp_res[i], errorTemp[i]);
        }
    }
    MiArchivo.close();

    printf("TIEMPOS DE EJECUCION");

    //Destruccion de streams
    cudaStreamDestroy(stream1);
    cudaStreamDestroy(stream2);
    cudaStreamDestroy(stream3);
    cudaStreamDestroy(stream4);
    cudaStreamDestroy(stream5);
    cudaStreamDestroy(stream6);

    //Liberar memoria
    cudaFree(dev_hum);
    cudaFree(dev_temp);
    cudaFree(dev_pres);
    cudaFree(dev_secs);
    cudaFree(dev_humres);
    cudaFree(dev_tempres);
    cudaFree(dev_presres);
    cudaFree(dev_secs3);
    cudaFree(dev_ppres);
    cudaFree(dev_ptemp);
    cudaFree(dev_phum);
    cudaFree(dev_pres3);
    cudaFree(dev_temp3);
    cudaFree(dev_hum3);
    cudaFree(dev_errorTemp);
    cudaFree(dev_errorPres);
    cudaFree(dev_errorHum);

    //Fin
    return 0;
}
