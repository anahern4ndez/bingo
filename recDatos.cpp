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
#include <errno.h>
#include <stdint.h>
#include <time.h>
#include <math.h>
#include <chrono>
#include <unistd.h>
#include <wiringPiI2C.h>
#include <fstream>
#include "bme280.h"

#define N 96 // cantidad de mediciones, para 3 dias son 288 mediciones, para cada dia son 96 mediciones
#define delayedTime 900 //segundos, 15 min son 900 seg

using namespace std;

struct maxmin
{
    double valor; // se guardara el valor maximo de la variable deseada, puede ser temperatura, presion o humedad.
    string tiempo; // hora y fecha a la cual fue tomada la medicion
};

int main(int argv, char* argc[])
{
    int fd = wiringPiI2CSetup(BME280_ADDRESS);
    if(fd < 0)
    {
        printf("Device not found");
        return -1;
    }
    bme280_calib_data cal;
    readCalibrationData(fd, &cal);
    
    /* info para obtener la hora y fecha */
    time_t rawtime; //creates and object of the built in time function
    struct tm * timeinfo;

    
    int timeElapsed =0;
    for(int i=1; i<4;i++) //for para que lo haga tres dias y marcar cuando termina cada dia
    {
        /* structs para los valores maximos y minimos */
        maxmin tempMax = maxmin();
        maxmin PresMax = maxmin();
        maxmin HumMax = maxmin();
        maxmin tempMin = maxmin();
        maxmin PresMin = maxmin();
        maxmin HumMin = maxmin();
        
        /* promedios diarios */
        double avTem =0;
        double avPres =0;
        double avHum =0;
        string nombreArc ="";
        if (i ==1) nombreArc = "dia1.csv";
        if (i ==2) nombreArc = "dia2.csv";
        if (i ==3) nombreArc = "dia3.csv";
        ofstream MiArchivo (nombreArc);
        time( &rawtime ); //gets the time from the computer
        timeinfo = localtime( &rawtime ); //store that time here
        MiArchivo << "\n#Dia " << i << ", Fecha y hora: " << asctime(timeinfo) << "\n";
        auto start = chrono::steady_clock::now();
        while (timeElapsed <= N*delayedTime)//cada dia se toman 96 medidas
        {
            wiringPiI2CWriteReg8(fd, 0xf2, 0x01);   // humidity oversampling x 1
            wiringPiI2CWriteReg8(fd, 0xf4, 0x25);   // pressure and temperature oversampling x 1, mode normal
            bme280_raw_data raw;
            getRawData(fd, &raw);
            int32_t t_fine = getTemperatureCalibration(&cal, raw.temperature);

            float t = compensateTemperature(t_fine); // C
            float p = compensatePressure(raw.pressure, &cal, t_fine) / 100; // hPa
            float h = compensateHumidity(raw.humidity, &cal, t_fine);       // %
            float a = getAltitude(p);                         // meters
          
            /* obtencion de fecha y hora */
            time( &rawtime ); //gets the time from the computer
            timeinfo = localtime( &rawtime ); //store that time here
            
            // output data to screen
            printf("\"Humedad\":%.2f, \"Presión\":%.2f,"
            " \"Temperatura\":%.2f, \"Altitud\":%.2f, \"Tiempo transcurrido\":%d segundos, \"Hora y fecha\":%s",
            h, p, t, a, timeElapsed, asctime(timeinfo));
            /* grabacion de mediciones en archivo csv */
            if (MiArchivo.is_open())
            {
                MiArchivo <<h<<","<<p<<","<<t<<","<<a<<","<<asctime(timeinfo);
            }
            if (timeElapsed == 0) //set de valores minimos
            {
                PresMin.valor = p;
                HumMin.valor = h;
                tempMin.valor = t;
                PresMin.tiempo = asctime(timeinfo);
                HumMin.tiempo = asctime(timeinfo);
                tempMin.tiempo = asctime(timeinfo);
            }
            
            /* calculo de maximos y minimos */
            if(t > tempMax.valor)
            {
                tempMax.valor = t;
                tempMax.tiempo = asctime(timeinfo);
            }
            if(p > PresMax.valor)
            {
                PresMax.valor = p;
                PresMax.tiempo = asctime(timeinfo);
            }
            if(h > HumMax.valor)
            {
                HumMax.valor = h;
                HumMax.tiempo = asctime(timeinfo);
            }
            if(p < PresMin.valor)
            {
                PresMin.valor = p;
                PresMin.tiempo = asctime(timeinfo);
            }
            if(t < tempMin.valor)
            {
                tempMin.valor = t;
                tempMin.tiempo = asctime(timeinfo);
            }
            if(h < HumMin.valor)
            {
                HumMin.valor = h;
                HumMin.tiempo = asctime(timeinfo);
            }
            avTem += t;
            avHum += h;
            avPres += p;
            sleep(delayedTime); //espera 900 seg (15min)
            auto end = chrono::steady_clock::now();
            timeElapsed = chrono::duration_cast<chrono::seconds>(end-start).count();
        }
        timeElapsed =0;
        avTem = avTem/(double)(N+1);
        avHum = avHum/(double)(N+1);
        avPres = avPres/(double)(N+1);
        /* grabado de datos finales en el archivo csv */
        MiArchivo << "\n#La temperatura maxima medida: " <<tempMax.valor <<" \t Fecha y hora: "<< tempMax.tiempo;
        MiArchivo << "#La presion maxima medida: " <<PresMax.valor <<" \t Fecha y hora: "<< PresMax.tiempo;
        MiArchivo << "#La humedad máxima medida: " <<HumMax.valor <<" \t Fecha y hora: "<< HumMax.tiempo;
        MiArchivo << "#La temperatura minima medida: " <<tempMin.valor <<" \t Fecha y hora: "<< tempMin.tiempo;
        MiArchivo << "#La presión minima medida: " <<PresMin.valor <<" \t Fecha y hora: "<< PresMin.tiempo;
        MiArchivo << "#La humedad minima medida: " <<HumMin.valor <<" \t Fecha y hora: "<< HumMin.tiempo;
        MiArchivo << "#Temperatura promedio: " <<avTem <<endl;
        MiArchivo << "#Humedad promedio: " <<avHum <<endl;
        MiArchivo << "#Presion promedio: " <<avPres <<endl;
        MiArchivo.close();
        /* print de datos finales en terminal */
        printf("---------------- RESULTADOS OBTENIDOS DEL DIA --------------------");
        cout << "\nLa temperatura máxima medida: " <<tempMax.valor << "\t" << "Fecha y hora: " << tempMax.tiempo;
        cout << "\nLa presión máxima medida: " <<PresMax.valor << "\t" << "Fecha y hora: " << PresMax.tiempo;
        cout << "\nLa humedad máxima medida: " <<HumMax.valor << "\t" << "Fecha y hora: " << HumMax.tiempo;
        cout << "\nLa temperatura mínima medida: " <<tempMin.valor << "\t" << "Fecha y hora: " << tempMin.tiempo;
        cout << "\nLa presión mínima medida: " << PresMin.valor << "\t" << "Fecha y hora: " << PresMin.tiempo;
        cout << "\nLa humedad mínima medida: " << HumMin.valor << "\t" << "Fecha y hora: " << HumMin.tiempo;
        cout << "---> Temperatura promedio: " <<avTem <<endl;
        cout << "---> Humedad promedio: " <<avHum <<endl;
        cout << "---> Presión promedio: " <<avPres <<endl;
    }
    return 0;
}
