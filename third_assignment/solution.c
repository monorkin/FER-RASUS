#include <stdio.h>
#include <string.h>
#include <math.h>
#include "pdq/lib/PDQ_Lib.h"
/* #include "PDQ_Lib.h"*/

int
main(int _argc, char **_argv)
{
  int nodes;
  int streams;

  float l_inc = 0.1;
  float l = l_inc;
  float l_max = 2.6;

  printf("L        \tS1       \tS2       \tS3       \tS4       \tS5       \tS6       \tS7       \tT\n");

  while(l < l_max)
  {
    // Define a new network
    PDQ_Init("RS homework");

    // Workload
    streams = PDQ_CreateOpen("Requests", l);
    /* PDQ_SetWUnit("Packet");*/
    /* PDQ_SetTUnit("s");*/

    // Nodes
    nodes = PDQ_CreateNode("S1", CEN, FCFS);
    nodes = PDQ_CreateNode("S2", CEN, FCFS);
    nodes = PDQ_CreateNode("S3", CEN, FCFS);
    nodes = PDQ_CreateNode("S4", CEN, FCFS);
    nodes = PDQ_CreateNode("S5", CEN, FCFS);
    nodes = PDQ_CreateNode("S6", CEN, FCFS);
    nodes = PDQ_CreateNode("S7", CEN, FCFS);

    // Requests
    /* PDQ_SetDemand("S1", "Requests", 0.003);*/
    /* PDQ_SetDemand("S2", "Requests", 0.001);*/
    /* PDQ_SetDemand("S3", "Requests", 0.01);*/
    /* PDQ_SetDemand("S4", "Requests", 0.04);*/
    /* PDQ_SetDemand("S5", "Requests", 0.1);*/
    /* PDQ_SetDemand("S6", "Requests", 0.13);*/
    /* PDQ_SetDemand("S7", "Requests", 0.15);*/

    PDQ_SetVisits("S1", "Requests", 1, 0.003);
    PDQ_SetVisits("S2", "Requests", 2.5, 0.001);
    PDQ_SetVisits("S3", "Requests", 0.5, 0.01);
    PDQ_SetVisits("S4", "Requests", 0.75, 0.04);
    PDQ_SetVisits("S5", "Requests", 1.25, 0.1);
    PDQ_SetVisits("S6", "Requests", 2.9148, 0.13);
    PDQ_SetVisits("S7", "Requests", 1.3829, 0.15);

    // Solve the network and show the report
    PDQ_Solve(CANON);
    /* PDQ_Report();*/

    printf("%f\t", l);
    printf("%f\t", PDQ_GetResidenceTime("S1", "Requests", TRANS));
    printf("%f\t", PDQ_GetResidenceTime("S2", "Requests", TRANS));
    printf("%f\t", PDQ_GetResidenceTime("S3", "Requests", TRANS));
    printf("%f\t", PDQ_GetResidenceTime("S4", "Requests", TRANS));
    printf("%f\t", PDQ_GetResidenceTime("S5", "Requests", TRANS));
    printf("%f\t", PDQ_GetResidenceTime("S6", "Requests", TRANS));
    printf("%f\t", PDQ_GetResidenceTime("S7", "Requests", TRANS));
    printf("%f\n", PDQ_GetResponse(TRANS, "Requests"));

    l += l_inc;
  };

  // Exit
  return 0;
}
