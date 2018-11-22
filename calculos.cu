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
//#include <string>
//#include <string.h>
//#include <errno.h>
#include <stdint.h>
#include <stdlib.h>
#include <time.h>
//#include <io.h>
#include <cuda_runtime.h>
#include <fstream>

#define N 192 //cantidad de datos en los dos dias (serian 192)
#define T 96 //cantidad de datos del tercer dia (serian 96)
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
    sumx = sumx/2;
    /* calculo de la pendiente */
    m =((N*sumProd)-(sumx*sumy))/((N*sumx_2)-(sumx*sumx));
    /* calculo del intercepto */
    b = (sumy - (m*sumx))/N;
    reg.pendiente = m;
    reg.intercepto = b;
    return reg;
}

__global__ void porcentajeError(float *resultado, float *teorico, float *predic)//el array predic tiene 192 datos pero solo se usaran los primeros 96, el teorico tiene 96 datos
{
    printf("kernel % error");
    int myID = threadIdx.x; //deberian ser 96?
        resultado[myID]=abs(teorico[myID]-predic[myID])*100/teorico[myID];
        printf("\n\tTeorico: %.3f\tPrediccion: %.3f\tError: %.3f");
}

/*__global__ void prediccion(float *y, float *x)//y es el vector donde se guarda la prediccion
{
	float predic[T];
	int ia = threadIdx.x; //indice a (todos los valores del dia 1)
	int ib = (threadIdx.x) + (T); //indice b (todos los valores del dia 2)
	int xf = (threadIdx.x) + (2*T*900); //indice c (del valor y que queremos, en el dia 3)
	predic[ia] = y[ia] + ((xf-x[ia])*((y[ib]-y[ia])/(x[ib]- x[ia])));
    printf("VALOR Y:%.2f\t VALOR X: %.2f\tVALOR INDICE B: %.2f\tVALOR Y1: %.2f\tVALOR Y2: %.2f\n",predic[ia], x[ia], x[ib], y[ia],y[ib]);
	y[ia] = predic[ia];
	
}*/

__global__ void prediccion(float *y, float *x, float *x192, float *y192)//y es el vector donde se guarda la prediccion
{
    int myID= threadIdx.x;
    float m=(y192[myID]-y192[myID+T])/(x192[myID]-x192[myID+T]);
    float b=(m*x192[myID])+y192[myID];
    //regresionLineal myb = calculoRegresion(x192[myID],x192[myID+T],y192[myID],y192[myID+T]);
    //double m=myb.pendiente;
    //double b=myb.intercepto;
    y[myID] = ((float)m*x[myID]) + (float)b; //ecuacion de una recta

}


int main(int argv, char* argc[])
{
    /* creacion streams, un stream por variable */
    cudaStream_t stream1, stream2, stream3, stream4, stream5, stream6;
    cudaStreamCreate(&stream1);
    cudaStreamCreate(&stream2);
    cudaStreamCreate(&stream3);
	cudaStreamCreate(&stream4);
    cudaStreamCreate(&stream5);
    cudaStreamCreate(&stream6);


    /* variables del host */
    float *dev_temp, *dev_hum, *dev_pres, *dev_secs, *dev_secs3, *dev_errorTemp, *dev_errorHum, *dev_errorPres; // pointers del device
    float *dev_temp3, *dev_hum3, *dev_pres3, *dev_tempres, *dev_humres, *dev_presres;
    float *temp, *hum, *pres, *secs, *temp_res, *hum_res, *pres_res, *temp3, *hum3, *pres3;
  //  string *fechas, *fechas3;
    string fechas[N], fechas3[T];
    //float temp3[T],hum3[T],pres3[T],fechas3[T];
    float errorTemp[T],errorHum[T],errorPres[T],secs3[T];

    /* reservas en memoria de los arrays a utilizar en host y pasar al device */
  //  cudaHostAlloc( (void**)&fechas, N * sizeof(int), cudaHostAllocDefault );// reserva de memoria de fechas
   // cudaHostAlloc( (void**)&fechas3, N * sizeof(int), cudaHostAllocDefault );// reserva de memoria de fechas
    cudaHostAlloc( (void**)&secs, N * sizeof(int), cudaHostAllocDefault );// reserva de memoria de segundos
    cudaMalloc( (void**)&dev_secs, N * sizeof(int) );
    cudaMalloc( (void**)&dev_secs3, N * sizeof(int) );
    cudaMalloc( (void**)&dev_humres, N * sizeof(int) );
    cudaMalloc( (void**)&dev_tempres, N * sizeof(int) );
    cudaMalloc( (void**)&dev_presres, N * sizeof(int) );

    //stream 1
    cudaMalloc( (void**)&dev_temp, N * sizeof(int) );
    cudaMalloc( (void**)&dev_temp3, N * sizeof(int) );
	cudaMalloc( (void**)&dev_errorTemp, N * sizeof(int) );
    cudaHostAlloc( (void**)&temp, N * sizeof(int), cudaHostAllocDefault );
    cudaHostAlloc( (void**)&temp_res, N * sizeof(int), cudaHostAllocDefault );
    cudaHostAlloc( (void**)&temp3, N * sizeof(int), cudaHostAllocDefault );


    //stream 2
    cudaMalloc( (void**)&dev_hum, N * sizeof(int) );
    cudaMalloc( (void**)&dev_hum3, N * sizeof(int) );
	cudaMalloc( (void**)&dev_errorHum, N * sizeof(int) );
    cudaHostAlloc( (void**)&hum, N * sizeof(int), cudaHostAllocDefault );
    cudaHostAlloc( (void**)&hum_res, N * sizeof(int), cudaHostAllocDefault );
    cudaHostAlloc( (void**)&hum3, N * sizeof(int), cudaHostAllocDefault);


    //stream 3
    cudaMalloc( (void**)&dev_pres, N * sizeof(int) );
    cudaMalloc( (void**)&dev_pres3, N * sizeof(int) );
	cudaMalloc( (void**)&dev_errorPres, N * sizeof(int) );
    cudaHostAlloc( (void**)&pres3, N * sizeof(int), cudaHostAllocDefault );
    cudaHostAlloc( (void**)&pres_res, N * sizeof(int), cudaHostAllocDefault );
    cudaHostAlloc( (void**)&pres, N * sizeof(int), cudaHostAllocDefault);

    /* lectura de datos del csv */
    int i = 0; //indice
    string humedad, presion, temperatura, altitud, fecha;
    ifstream file("datos.csv");
    while (getline(file, humedad, ',')) {
        //hay que revisar si no esta jalando los datos de altitud, los cuales no sirven
        hum[i] = (float)atof(humedad.c_str());
        getline(file, presion, ',') ;
        pres[i] = (float)atof(presion.c_str());
        getline(file, temperatura, ',') ;
        temp[i] = (float)atof(temperatura.c_str());
        getline(file, altitud, ',');
        getline(file, fecha);
        fechas[i] = fecha;
        i++;
    }

/* lectura de datos del csv del tercer dia*/
    i = 0; //indice
    ifstream file3("dia3.csv");
    while (getline(file, humedad, ',')) {
        //hay que revisar si no esta jalando los datos de altitud, los cuales no sirven
        hum3[i] = (float)atof(humedad.c_str());
        getline(file, presion, ',') ;
        pres3[i] = (float)atof(presion.c_str());
        getline(file, temperatura, ',') ;
        temp3[i] = (float)atof(temperatura.c_str());
        getline(file, altitud, ',');
        getline(file, fecha);
        fechas3[i] = fecha;
        i++;
    }


    /* segundos de las primeras 48hr */
    for (int i =0; i <N; i++)
    {
        secs[i]=i;
    }

    /* calculo de la regresion lineal para temperatura, presion y humedad */
    regresionLineal regHum = calculoRegresion(hum, secs);
    regresionLineal regPres = calculoRegresion(pres, secs);
    regresionLineal regTemp = calculoRegresion(temp, secs);

    /* ajustar el vector de segundos para que ahora sean los segundos del tercer dia (prediccion) */
    for (int i =0; i <T; i++)
    {
        secs3[i] = (i+N); //48hr + segs del tercer dia
    }
    /* lanzamiento de kernels para la prediccion
        se lanzaran N threads en los que cada uno calculara la prediccion en la hora correspondiente de su variable correspondiente. */
    cudaMemcpyAsync(dev_hum,hum,N*sizeof(int),cudaMemcpyHostToDevice,stream1);
    cudaMemcpyAsync(dev_pres,pres,N*sizeof(int),cudaMemcpyHostToDevice,stream2);
    cudaMemcpyAsync(dev_temp,temp,N*sizeof(int),cudaMemcpyHostToDevice,stream3);
    cudaMemcpyAsync(dev_secs,secs,N*sizeof(int),cudaMemcpyHostToDevice,stream1);
    cudaMemcpyAsync(dev_secs,secs,N*sizeof(int),cudaMemcpyHostToDevice,stream2);
    cudaMemcpyAsync(dev_secs,secs,N*sizeof(int),cudaMemcpyHostToDevice,stream3);
    cudaMemcpyAsync(dev_secs3,secs3,N*sizeof(int),cudaMemcpyHostToDevice,stream1);
    cudaMemcpyAsync(dev_secs3,secs3,N*sizeof(int),cudaMemcpyHostToDevice,stream2);
    cudaMemcpyAsync(dev_secs3,secs3,N*sizeof(int),cudaMemcpyHostToDevice,stream3);

    cudaStreamSynchronize(stream1); // wait for stream1 to finish
    cudaStreamSynchronize(stream2); // wait for stream2 to finish
    cudaStreamSynchronize(stream3); // wait for stream3 to finish

    cudaMemcpyAsync(dev_hum3,hum3,N*sizeof(int),cudaMemcpyHostToDevice,stream4);
    cudaMemcpyAsync(dev_pres3,pres3,N*sizeof(int),cudaMemcpyHostToDevice,stream5);
    cudaMemcpyAsync(dev_temp3,temp3,N*sizeof(int),cudaMemcpyHostToDevice,stream6);

    prediccion<<<1, T, 0, stream1>>>(dev_tempres, dev_secs3, dev_secs, dev_hum);
    prediccion<<<1, T, 1, stream2>>>(dev_presres, dev_secs3, dev_secs, dev_pres);
    prediccion<<<1, T, 2, stream3>>>(dev_tempres, dev_secs3, dev_secs, dev_temp);
	cudaMemcpyAsync(hum_res,dev_humres,N*sizeof(int),cudaMemcpyDeviceToHost,stream1);
    cudaMemcpyAsync(pres_res,dev_presres,N*sizeof(int),cudaMemcpyDeviceToHost,stream2);
    cudaMemcpyAsync(temp_res,dev_tempres,N*sizeof(int),cudaMemcpyDeviceToHost,stream3);

/* realizacion y lanzamiento de kernels de porcentaje de error */
    cudaMemcpyAsync(dev_hum,hum_res,N*sizeof(int),cudaMemcpyHostToDevice,stream4);
    cudaMemcpyAsync(dev_pres,pres_res,N*sizeof(int),cudaMemcpyHostToDevice,stream5);
    cudaMemcpyAsync(dev_temp,temp_res,N*sizeof(int),cudaMemcpyHostToDevice,stream6);
    cudaMemcpyAsync(dev_hum3,hum3,N*sizeof(int),cudaMemcpyHostToDevice,stream4);
    cudaMemcpyAsync(dev_pres3,pres3,N*sizeof(int),cudaMemcpyHostToDevice,stream5);
    cudaMemcpyAsync(dev_temp3,temp3,N*sizeof(int),cudaMemcpyHostToDevice,stream6);

	porcentajeError<<<1, T, 0, stream4>>>(dev_errorHum, dev_hum3, dev_humres);
	porcentajeError<<<1, T, 1, stream5>>>(dev_errorTemp, dev_temp3, dev_tempres);
	porcentajeError<<<1, T, 2, stream6>>>(dev_errorPres, dev_pres3, dev_presres);

	cudaMemcpyAsync(errorHum,dev_errorHum,N*sizeof(int),cudaMemcpyDeviceToHost,stream4);
    cudaMemcpyAsync(errorPres,dev_errorPres,N*sizeof(int),cudaMemcpyDeviceToHost,stream5);
    cudaMemcpyAsync(errorTemp,dev_errorTemp,N*sizeof(int),cudaMemcpyDeviceToHost,stream6);
    /* display de prediccion o escritura en un nuevo .csv */
    //falta agregarle la fecha y hora para cada prediccion
  /*  printf("\nPREDICCIONES\n");
    ofstream MiArchivo ("prediccion.csv");
    for(int i=0; i<T; i++)
    {
        if (MiArchivo.is_open())
        {
            printf("Guardando...\t");
            MiArchivo <<hum_res[i]<<","<< errorHum[i]<<","<<pres_res[i]<<","<<errorPres[i]<<","<<temp_res[i]<<","<<errorTemp[i]<<","<<secs[i]<<"\n";
            printf("H: %.2f (%.2f), P: %.2f (%.2f), T: %.2f (%.2f)\n", hum_res[i], errorHum[i], pres_res[i], errorPres[i], temp_res[i], errorTemp[i]);
        }
    }
    MiArchivo.close();*/
        /* display de prediccion o escritura en un nuevo .csv */
    //falta agregarle la fecha y hora para cada prediccion
    printf("\nTEMPERATURAS PREDICCION");
    for(int i=0; i<T; i++){
      printf("\nTiempo %d: %.3f",i,temp_res[i]);
    }
    printf("\nHUMEDADES PREDICCION");
    for(int i=0; i<T; i++){
      printf("\nTiempo %d: %.3f",i,hum_res[i]);
    }
    printf("\nPRESIONES PREDICCION");
    for(int i=0; i<T; i++){
      printf("\nTiempo %d: %.3f",i,pres_res[i]);
    }
    printf("\nPREDICCIONES\n");
    ofstream MiArchivo ("prediccion.csv");
    for(int i=0; i<T; i++)
    {
        if (MiArchivo.is_open())
        {
            printf("Guardando...");
            MiArchivo <<hum_res[i]<<","<< errorHum[i]<<","<<pres_res[i]<<","<<errorPres[i]<<","<<temp_res[i]<<","<<errorTemp[i]<<","<<secs[i]<<"\n";
            printf("H: %.2f (%.6f), P: %.2f (%.6f), T: %.2f (%.6f)\n", hum_res[i], errorHum[i], pres_res[i], errorPres[i], temp_res[i], errorTemp[i]);
        }
    }
    MiArchivo.close();

    cudaStreamSynchronize(stream5);
    cudaStreamSynchronize(stream4);
    cudaStreamSynchronize(stream6);

    cudaStreamDestroy(stream1);
    cudaStreamDestroy(stream2);
    cudaStreamDestroy(stream3);
    cudaStreamDestroy(stream4);
    cudaStreamDestroy(stream5);
    cudaStreamDestroy(stream6);

    cudaFree(dev_hum);
    cudaFree(dev_temp);
    cudaFree(dev_pres);
    cudaFree(dev_secs);
    cudaFree(dev_humres);
    cudaFree(dev_tempres);
    cudaFree(dev_presres);
    cudaFree(dev_secs3);
    cudaFree(dev_errorTemp);
    cudaFree(dev_errorPres);
    cudaFree(dev_errorHum);
    return 0;
}
