# -*- coding: utf-8 -*-
"""
Created on Mon Nov 16 17:34:55 2020

@author: sg316
"""

import numpy as np
import math
import pandas as pd
from random import seed
from random import sample
import random
import openpyxl


#seed random generator
seed(1)
T = 77 #time horizon

P_Group = ["COVID_AGE1", "COVID_AGE2",	"COVID_AGE3", "ICD01_AGE1",	"ICD01_AGE2", "ICD01_AGE3",	"ICD02_AGE1",	"ICD02_AGE2",	"ICD02_AGE3",	"ICD03_AGE1",	"ICD03_AGE2",	"ICD03_AGE3",	"ICD04_AGE1",	"ICD04_AGE2",	"ICD04_AGE3",	"ICD05_AGE1",	"ICD05_AGE2",	"ICD05_AGE3",	"ICD06_AGE1",	"ICD06_AGE2",	"ICD06_AGE3",	"ICD07_AGE1",	"ICD07_AGE2",	"ICD07_AGE3",	"ICD09_AGE1",	"ICD09_AGE2",	"ICD09_AGE3",	"ICD10_AGE1",	"ICD10_AGE2",	"ICD10_AGE3",	"ICD11_AGE1",	"ICD11_AGE2",	"ICD11_AGE3",	"ICD12_AGE1",	"ICD12_AGE2",	"ICD12_AGE3",	"ICD13_AGE1",	"ICD13_AGE2",	"ICD13_AGE3",	"ICD14_AGE1",	"ICD14_AGE2",	"ICD14_AGE3",	"ICD15_AGE1",	"ICD15_AGE2",	"ICD15_AGE3",	"ICD18_AGE1",	"ICD18_AGE2",	"ICD18_AGE3",	"ICD19_AGE1",	"ICD19_AGE2",	"ICD19_AGE3",	"ICD21_AGE1",	"ICD21_AGE2",	"ICD21_AGE3",	"ICD50_AGE1",	"ICD50_AGE2",	"ICD50_AGE3",	"ICD51_AGE1",	"ICD51_AGE2",	"ICD51_AGE3"]

# states: 0: G, 1: G_STAR, 2: C, 3:H, 4: D
states = ["G", "G_STAR", "C", "H", "D"]

delta = np.array([[1, 0], [1, 0], [0, 1]])

class Patient:
    def __init__(self, ICD_type, start_week, adm_type, start_state):
        self.ICD_type = ICD_type
        self.start_week = start_week
        self.adm_type = adm_type
        self.state = start_state

###################################
####### INPUT REQUIRED: input resource capacities here #######
###################################
xi = np.array([102186.0, 4122.0])
#xi = np.array([117869.0, 4939.0]) #extended capacity
###################################
####### INPUT REQUIRED: input time in which cancellation policy is ON here#######
###################################
T_policy = [i for i in range(2,8)]
#T_policy.extend([i for i in range(2,8)])        
#reading in all input data
###################################
####### INPUT REQUIRED: input data file here #######
###################################
fn = 'input_data.xlsx' 

###################################
####### INPUT REQUIRED #######
####### line 169 for reduction of emergencies due to behavioural changes during COVID pandemic
####### line 569 for implementing which cancellation policy is ON: policy 1,2 cancels 100% electives in weeks in T_policy; policy 3,4 cencels 75% electives in weeks in T_policy
###################################

phi_n = pd.read_excel(fn, sheet_name="phi3", nrows = T+1, engine='openpyxl')
phi_e = pd.read_excel(fn, sheet_name="phi3", skiprows = np.arange(1, T+2), engine='openpyxl')

pi_W = pd.read_excel(fn, sheet_name = "pi_x", engine='openpyxl')
frail_N_prop = pd.read_excel(fn, sheet_name = "frailty", nrows = T+1, engine='openpyxl')
frail_E_prop = pd.read_excel(fn, sheet_name = "frailty", skiprows = np.arange(1, T+2), engine='openpyxl')
pi_x_data = pd.read_excel(fn, sheet_name = "pi_x", engine='openpyxl')
pi_x = np.zeros(len(P_Group))

for s in P_Group:
    if (pi_x_data.loc[(pi_x_data['p'] == s) & (pi_x_data['a'] == "N")].empty == 0):
        pi_x[P_Group.index(s)] = pi_x_data.loc[(pi_x_data['p'] == s) & (pi_x_data['a'] == "N")].values[0,2]

pi_y = pd.read_excel(fn, sheet_name = "pi_y", engine='openpyxl')

pi_y_N = pi_y[(pi_y['week'] == 1.5) & (pi_y['a'] == "N")]
pi_y_E = pi_y[(pi_y['week'] == 1.5) & (pi_y['a'] == "E")]

pi_y_0_N = pi_y[(pi_y['week'] == 0.5) & (pi_y['a'] == "N")]
pi_y_0_E = pi_y[(pi_y['week'] == 0.5) & (pi_y['a'] == "E")]

pi_z_N = pd.read_excel(fn, sheet_name="pi_z", nrows = T+1, engine='openpyxl')
pi_z_E = pd.read_excel(fn, sheet_name="pi_z", skiprows = np.arange(1, T+2), engine='openpyxl')
delta_0_N_G = pd.read_excel(fn, sheet_name="delta_0_N_G", engine='openpyxl')
delta_0_N_C = pd.read_excel(fn, sheet_name="delta_0_N_C", engine='openpyxl')
delta_0_E_G = pd.read_excel(fn, sheet_name="delta_0_E_G", engine='openpyxl')
delta_0_E_C = pd.read_excel(fn, sheet_name="delta_0_E_C", engine='openpyxl')

y_0 = pd.read_excel(fn, sheet_name = "y0", engine='openpyxl')
x_0 = pd.read_excel(fn, sheet_name = "x0", engine='openpyxl')

cost = pd.read_excel(fn, sheet_name = "costs", engine='openpyxl')
cost_type_N = np.zeros(len(P_Group))
cost_type_E = np.zeros(len(P_Group))

for s in P_Group:
    if (cost.loc[(cost['p'] == s) & (cost['a'] == "E")].empty == 0):
            cost_type_E[P_Group.index(s)] = cost.loc[(cost['p'] == s) & (cost['a'] == "E")].values[0,3]
    if (cost.loc[(cost['p'] == s) & (cost['a'] == "N")].empty == 0):
            cost_type_N[P_Group.index(s)] = cost.loc[(cost['p'] == s) & (cost['a'] == "N")].values[0,3]

lambda_yll = pd.read_excel(fn, sheet_name = "lambda", engine='openpyxl')

tp_E = np.zeros((len(P_Group), 3, 5)) 

for s in P_Group:
    for start_state in range(3):
        for next_state in range(5):
            tp_E[P_Group.index(s)][start_state][next_state] = pi_y_E.loc[(pi_y_E['p'] == s)  & (pi_y_E['s'] == states[start_state]) & (pi_y_E['sbar'] == states[next_state])].values[0,4]

tp_N = np.zeros((len(P_Group), 3, 5)) 

for s in P_Group:
    for start_state in range(3):
        for next_state in range(5):
            tp_N[P_Group.index(s)][start_state][next_state] = pi_y_N.loc[(pi_y_N['p'] == s)  & (pi_y_N['s'] == states[start_state]) & (pi_y_N['sbar'] == states[next_state])].values[0,4]

tp_0_E = np.zeros((len(P_Group), 3, 5)) 
for s in P_Group:
    for start_state in range(3):
        for next_state in range(5):
            tp_0_E[P_Group.index(s)][start_state][next_state] = pi_y_0_E.loc[(pi_y_0_E['p'] == s)  & (pi_y_0_E['s'] == states[start_state]) & (pi_y_0_E['sbar'] == states[next_state])].values[0,4]

tp_0_N = np.zeros((len(P_Group), 3, 5)) 
for s in P_Group:
    for start_state in range(3):
        for next_state in range(5):
            tp_0_N[P_Group.index(s)][start_state][next_state] = pi_y_0_N.loc[(pi_y_0_N['p'] == s)  & (pi_y_0_N['s'] == states[start_state]) & (pi_y_0_N['sbar'] == states[next_state])].values[0,4]

delta_0_E_0 = np.zeros(len(P_Group))
delta_0_E_2 = np.zeros(len(P_Group))
delta_0_N_0 = np.zeros(len(P_Group))
delta_0_N_2 = np.zeros(len(P_Group))

x_0_s = np.zeros(len(P_Group))
yll = np.zeros(len(P_Group))

phi_E = np.zeros((T+1, len(P_Group)))
phi_N = np.zeros((T+1, len(P_Group)))
non_frail_prop = np.zeros((T+1, len(P_Group)))
non_frail_prop_N = np.zeros((T+1, len(P_Group)))

beta_0_N_C = np.zeros(len(P_Group))
beta_0_N_G = np.zeros(len(P_Group))
beta_0_N_G_Star = np.zeros(len(P_Group))
beta_0_E_C = np.zeros(len(P_Group))
beta_0_E_G = np.zeros(len(P_Group))
beta_0_E_G_Star = np.zeros(len(P_Group))

for p in P_Group:
    delta_0_E_0[P_Group.index(p)] = delta_0_E_G.loc[delta_0_E_G['p'] == p].values[0,1]
    delta_0_E_2[P_Group.index(p)] = delta_0_E_C.loc[delta_0_E_C['p'] == p].values[0,1]
    delta_0_N_0[P_Group.index(p)] = delta_0_N_G.loc[delta_0_N_G['p'] == p].values[0,1]
    delta_0_N_2[P_Group.index(p)] = delta_0_N_C.loc[delta_0_N_C['p'] == p].values[0,1]

    yll[P_Group.index(p)] = lambda_yll.loc[lambda_yll['p'] == p].values[0,1]

    beta_0_N_C[P_Group.index(p)] = delta_0_N_2[P_Group.index(p)]*(tp_0_N[P_Group.index(p)][2][3] + tp_0_N[P_Group.index(p)][2][4]) + 0.5*(tp_0_N[P_Group.index(p)][2][0] + tp_0_N[P_Group.index(p)][2][1] + tp_0_N[P_Group.index(p)][2][2])
    beta_0_N_G[P_Group.index(p)] = delta_0_N_0[P_Group.index(p)]*(tp_0_N[P_Group.index(p)][0][3] + tp_0_N[P_Group.index(p)][0][4]) + 0.5*(tp_0_N[P_Group.index(p)][0][0] + tp_0_N[P_Group.index(p)][0][1] + tp_0_N[P_Group.index(p)][0][2])
    beta_0_N_G_Star[P_Group.index(p)] = delta_0_N_0[P_Group.index(p)]*(tp_0_N[P_Group.index(p)][1][3] + tp_0_N[P_Group.index(p)][1][4]) + 0.5*(tp_0_N[P_Group.index(p)][1][0] + tp_0_N[P_Group.index(p)][1][1] + tp_0_N[P_Group.index(p)][1][2])    
    beta_0_E_C[P_Group.index(p)] = delta_0_E_2[P_Group.index(p)]*(tp_0_E[P_Group.index(p)][2][3] + tp_0_E[P_Group.index(p)][2][4]) + 0.5*(tp_0_E[P_Group.index(p)][2][0] + tp_0_E[P_Group.index(p)][2][1] + tp_0_E[P_Group.index(p)][2][2])
    beta_0_E_G[P_Group.index(p)] = delta_0_E_0[P_Group.index(p)]*(tp_0_E[P_Group.index(p)][0][3] + tp_0_E[P_Group.index(p)][0][4]) + 0.5*(tp_0_E[P_Group.index(p)][0][0] + tp_0_E[P_Group.index(p)][0][1] + tp_0_E[P_Group.index(p)][0][2])
    beta_0_E_G_Star[P_Group.index(p)] = delta_0_E_0[P_Group.index(p)]*(tp_0_E[P_Group.index(p)][1][3] + tp_0_E[P_Group.index(p)][1][4]) + 0.5*(tp_0_E[P_Group.index(p)][1][0] + tp_0_E[P_Group.index(p)][1][1] + tp_0_E[P_Group.index(p)][1][2])

    for t in range(0, T+1):

        phi_E[t][P_Group.index(p)] = phi_e.loc[t,p]
        phi_N[t][P_Group.index(p)] = phi_n.loc[t,p]
        non_frail_prop[t][P_Group.index(p)] = 1 - frail_E_prop[p].loc[frail_E_prop["t"] == t].values[0]
        non_frail_prop_N[t][P_Group.index(p)] = 1 - frail_N_prop[p].loc[frail_N_prop["t"] == t].values[0]

###################################
####### UNCOMMENT HERE, reducing emergency admissions by 34% for all groups except COVID #######
###################################
#        if p in ["COVID_AGE1", "COVID_AGE2", "COVID_AGE3"]:
#            phi_E[t][P_Group.index(p)] = phi_e.loc[t,p]
#        else:
#            phi_E[t][P_Group.index(p)] = 0.66*phi_e.loc[t,p]
###################################
        
    if (x_0.loc[(x_0['p'] == p) & (x_0['a'] == "N")].empty == 1):
        x_0_s[P_Group.index(p)] = 0

    else:
        x_0_s[P_Group.index(p)] = x_0.loc[(x_0['p'] == p) & (x_0['a'] == "N")].values[0,2]


def evolution(state, ICD_type, adm_type):
    tp = np.zeros(5)
    if (adm_type == "E"):
        tp = tp_E[P_Group.index(ICD_type)][state]        
    else:
        tp = tp_N[P_Group.index(ICD_type)][state] 
    transition = np.random.multinomial(1, tp, 1)
    temp_state = np.flatnonzero(transition == 1)[0] 
    return temp_state

def evolution_half_week(state, ICD_type, adm_type):
    tp = np.zeros(5)  
    if (adm_type == "E"):
        tp = tp_0_E[P_Group.index(ICD_type)][state]  

    else:
        tp = tp_0_N[P_Group.index(ICD_type)][state]              

    transition = np.random.multinomial(1, tp, 1)
    temp_state = np.flatnonzero(transition == 1)[0] 
    return temp_state

def resource_use(current_state):
    res_use = 0
    if ((current_state == 0) | (current_state == 1)):
        res_use = delta[0]
    if (current_state == 2):
        res_use = delta[2]
    return res_use

def generate_patients_y0(y_0):
    hospitalized_new = []
    for index, row in y_0.iterrows():
        adm_type = row['a']
        ICD_type = row['p']
        state_alpha = row['s']
        num = row['y0']
        if (state_alpha == "G"):
            state = 0
        if (state_alpha == "C"):
            state = 2
        if (state_alpha == "G_STAR"):
            state = 1
        for i in range(num):
            hospitalized_new.append(Patient(ICD_type, 0, adm_type, state))
    return hospitalized_new

#outputs
T = 77
resource_availability = np.array([ xi for j in range (T+1)])  
YLL_type_time = [ [0 for i in range(len(P_Group))] for j in range (T+2)]
cost_type_time = [ [0 for i in range(len(P_Group))] for j in range (T+1)]
Admitted_E_type_time = [ [0 for i in range(len(P_Group))] for j in range (T+1)]
Admitted_N_type_time = [ [0 for i in range(len(P_Group))] for j in range (T+1)]
Waiting_type_time = [ [0 for i in range(len(P_Group))] for j in range (T+2)]
Admission_denials = [ [0 for i in range(len(P_Group))] for j in range (T+1)]
G_Star_beds = np.array([0 for j in range (T+1)]) 
E_C_beds_type_time = [ [0 for i in range(len(P_Group))] for j in range (T+1)]
E_G_beds_type_time = [ [0 for i in range(len(P_Group))] for j in range (T+1)]
E_G_Star_beds_type_time = [ [0 for i in range(len(P_Group))] for j in range (T+1)]
N_C_beds_type_time = [ [0 for i in range(len(P_Group))] for j in range (T+1)]
N_G_beds_type_time = [ [0 for i in range(len(P_Group))] for j in range (T+1)]
N_G_Star_beds_type_time = [ [0 for i in range(len(P_Group))] for j in range (T+1)]


for s in P_Group:
    Waiting_type_time[0][P_Group.index(s)] = x_0_s[P_Group.index(s)]

def main(T):
    hospitalized = [] 
    hospitalized_half_week = [] #patients that entered in the middle of the week
    Waiting_C = [[] for i in range(len(P_Group))] 
    Waiting_G = [[] for i in range(len(P_Group))] 

    for t in range(0, T+ 1):
        print("t = ", t)
        resource_availability[t] = xi 
        hospitalized_this_week = []

        #evolution of patients in hospital from last week
        for patient in hospitalized:
            new_state = evolution(patient.state, patient.ICD_type, patient.adm_type) 

            if ((new_state == 3) | (new_state == 4)):
                if (new_state == 4):
                    YLL_type_time[t][P_Group.index(patient.ICD_type)] += yll[P_Group.index(patient.ICD_type)]

            else:
                patient.state = new_state
                resource_availability[t] -= resource_use(new_state) #resource utilization in current week
                hospitalized_this_week.append(patient)

                if (patient.adm_type == "E"):
                    if (new_state == 0):
                        E_G_beds_type_time[t][P_Group.index(patient.ICD_type)] += 1
                    elif (new_state == 1):
                        E_G_Star_beds_type_time[t][P_Group.index(patient.ICD_type)] += 1
                    else:
                        E_C_beds_type_time[t][P_Group.index(patient.ICD_type)] += 1

                else:
                    if (new_state == 0):
                        N_G_beds_type_time[t][P_Group.index(patient.ICD_type)] += 1
                    elif (new_state == 1):
                        N_G_Star_beds_type_time[t][P_Group.index(patient.ICD_type)] += 1
                    else:
                        N_C_beds_type_time[t][P_Group.index(patient.ICD_type)] += 1

        hospitalized = hospitalized_this_week 

        for patient in hospitalized_half_week:
            new_state = evolution_half_week(patient.state, patient.ICD_type, patient.adm_type)
            
            if ((new_state == 3) | (new_state == 4)):
                if (new_state == 4):
                    YLL_type_time[t][P_Group.index(patient.ICD_type)] += yll[P_Group.index(patient.ICD_type)]

            else:
                patient.state = new_state
                hospitalized.append(patient)
                resource_availability[t] -= resource_use(new_state) #resource utilization in current week

                if (patient.adm_type == "E"):
                    if (new_state == 0):
                        E_G_beds_type_time[t][P_Group.index(patient.ICD_type)] += 1
                    elif (new_state == 1):
                        E_G_Star_beds_type_time[t][P_Group.index(patient.ICD_type)] += 1
                    else:
                        E_C_beds_type_time[t][P_Group.index(patient.ICD_type)] += 1

                else:
                    if (new_state == 0):
                        N_G_beds_type_time[t][P_Group.index(patient.ICD_type)] += 1
                    elif (new_state == 1):
                        N_G_Star_beds_type_time[t][P_Group.index(patient.ICD_type)] += 1
                    else:
                        N_C_beds_type_time[t][P_Group.index(patient.ICD_type)] += 1

        ## resource shortage in CC 

        if (resource_availability[t][1] < 0):#implies all patients above cannot evolve to CC
            print("CC is full after evolution at time", t)
            excess = abs(resource_availability[t][1]) #number of patients to be moved from CC to G_Star
            hospitalized_subset_requiring_CC = [c for c in hospitalized if c.state == 2]
            temp_subset = sample(hospitalized_subset_requiring_CC, int(excess)) #sampling people randomly who go to G*

            for p in temp_subset:
                  resource_availability[t] += resource_use(2) #release CC resources
                  p.state = 1 #set state as G_Star
                  resource_availability[t] -= resource_use(1) #use G_Star resources
                  G_Star_beds[t] += 1

                  if (p.adm_type == "E"):
                      E_G_Star_beds_type_time[t][P_Group.index(p.ICD_type)] += 1
                      E_C_beds_type_time[t][P_Group.index(p.ICD_type)] -= 1

                  else:
                      N_G_Star_beds_type_time[t][P_Group.index(p.ICD_type)] += 1
                      N_C_beds_type_time[t][P_Group.index(p.ICD_type)] -= 1

        ## resource shortage in GA

        if (resource_availability[t][0] < 0):#implies all patients above cannot evolve to GA
            print("Not enough beds in GA to serve hospitalized patients")
            break

            

#adding patients in y0 to hospitalized

        if (t == 0):
            hospitalized_new = generate_patients_y0(y_0)
            for p in hospitalized_new:
                resource_availability[t] -= resource_use(p.state)
                if (p.adm_type == "E"):
                    if (p.state == 0):
                        E_G_beds_type_time[t][P_Group.index(p.ICD_type)] += 1
                    elif (p.state == 1):
                        E_G_Star_beds_type_time[t][P_Group.index(p.ICD_type)] += 1
                    else:
                        E_C_beds_type_time[t][P_Group.index(p.ICD_type)] += 1

                else:
                    if (p.state == 0):
                        N_G_beds_type_time[t][P_Group.index(p.ICD_type)] += 1
                    elif (p.state == 1):
                        N_G_Star_beds_type_time[t][P_Group.index(p.ICD_type)] += 1
                    else:
                        N_C_beds_type_time[t][P_Group.index(p.ICD_type)] += 1
            hospitalized.extend(hospitalized_new)

#### at half week ####
        hospitalized_half_week = []    
        #emergency inflow
        inflow_E_C = []
        inflow_E_G = []          

        for s in P_Group:
            #total inflow = new inflow + waiting electives turning into emergencies #update waiting_type_time
            inflow_E = phi_E[t][P_Group.index(s)] + Waiting_type_time[t][P_Group.index(s)]*pi_x[P_Group.index(s)]
            
            inflow_E_C.append(math.ceil(pi_z_E[s][t]*inflow_E)) #requiring CC
            inflow_E_G.append(math.ceil((1- pi_z_E[s][t])*inflow_E)) #requiring GA

            # is enough resources available? #     
        if (np.sum(np.multiply(beta_0_E_C, inflow_E_C)) <= resource_availability[t][1]):
            for s in P_Group:
              #starting in CC  
                for i in range(1, inflow_E_C[P_Group.index(s)] + 1):
                    hospitalized_half_week.append(Patient(s, t, "E", 2))
                    resource_availability[t][1] -= beta_0_E_C[P_Group.index(s)]#patient is in CC
                    E_C_beds_type_time[t][P_Group.index(s)] += beta_0_E_C[P_Group.index(s)]
                    Admitted_E_type_time[t][P_Group.index(s)] += 1

         #when resources are short, use uniform sampling across all patients seeking emergency to determine who goes to CC, the rest go to G*
        else: 
            if t in T_policy:
                emergency_inflow = []
                emergency_inflow_frail = []

                for s in P_Group:
                  for i in range(1, math.ceil(inflow_E_C[P_Group.index(s)]*non_frail_prop[t][P_Group.index(s)]) + 1): #non-frail patients go to CC
                        emergency_inflow.append(Patient(s, t, "E", 2))

                  for i in range(1, math.ceil(inflow_E_C[P_Group.index(s)]*(1 - non_frail_prop[t][P_Group.index(s)])) + 1): # these are frail patients, they go to G*
                        emergency_inflow_frail.append(Patient(s, t, "E", 2))  

                while ((emergency_inflow != []) & (resource_availability[t][1] > 0)):
                    pick = random.randrange(len(emergency_inflow))
                    resource_availability[t][1] -= beta_0_E_C[P_Group.index(emergency_inflow[pick].ICD_type)]
                    E_C_beds_type_time[t][P_Group.index(emergency_inflow[pick].ICD_type)] += beta_0_E_C[P_Group.index(emergency_inflow[pick].ICD_type)]
                    hospitalized_half_week.append(emergency_inflow[pick])
                    Admitted_E_type_time[t][P_Group.index(emergency_inflow[pick].ICD_type)] += 1
                    del emergency_inflow[pick]

                emergency_inflow_no_CC = emergency_inflow #these patients go to G*                

                while ((emergency_inflow_no_CC != []) & (resource_availability[t][0] > 0)):
                    pick = random.randrange(len(emergency_inflow_no_CC))
                    resource_availability[t][0] -= beta_0_E_G_Star[P_Group.index(emergency_inflow_no_CC[pick].ICD_type)]
                    E_G_Star_beds_type_time[t][P_Group.index(emergency_inflow_no_CC[pick].ICD_type)] += beta_0_E_G_Star[P_Group.index(emergency_inflow_no_CC[pick].ICD_type)]
                    emergency_inflow_no_CC[pick].state = 1 #change state to G*
                    hospitalized_half_week.append(emergency_inflow_no_CC[pick])
                    Admitted_E_type_time[t][P_Group.index(emergency_inflow_no_CC[pick].ICD_type)] += 1
                    G_Star_beds[t] += beta_0_E_G_Star[P_Group.index(emergency_inflow_no_CC[pick].ICD_type)]
                    del emergency_inflow_no_CC[pick]

                emergency_inflow_no_G_Star = emergency_inflow_no_CC #these patients die

                for i in emergency_inflow_no_G_Star:
                    i.state = 4
                    YLL_type_time[t][P_Group.index(i.ICD_type)] += yll[P_Group.index(i.ICD_type)] #update YLL
                    Admission_denials[t][P_Group.index(i.ICD_type)] += 1
                
                if (resource_availability[t][1] > 0): # if resources available in CC after non-frail patients have been assigned
                    while ((emergency_inflow_frail != []) & (resource_availability[t][1] > 0)):
                        pick = random.randrange(len(emergency_inflow_frail))
                        resource_availability[t][1] -= beta_0_E_C[P_Group.index(emergency_inflow_frail[pick].ICD_type)]
                        E_C_beds_type_time[t][P_Group.index(emergency_inflow_frail[pick].ICD_type)] += beta_0_E_C[P_Group.index(emergency_inflow_frail[pick].ICD_type)]
                        hospitalized_half_week.append(emergency_inflow_frail[pick])
                        Admitted_E_type_time[t][P_Group.index(emergency_inflow_frail[pick].ICD_type)] += 1
                        del emergency_inflow_frail[pick]

                    emergency_inflow_no_CC_frail = emergency_inflow_frail #these patients go to G*

                    while ((emergency_inflow_no_CC_frail != []) & (resource_availability[t][0] > 0)):
                        pick = random.randrange(len(emergency_inflow_no_CC_frail))
                        resource_availability[t][0] -= beta_0_E_G_Star[P_Group.index(emergency_inflow_no_CC_frail[pick].ICD_type)]
                        E_G_Star_beds_type_time[t][P_Group.index(emergency_inflow_no_CC_frail[pick].ICD_type)] += beta_0_E_G_Star[P_Group.index(emergency_inflow_no_CC_frail[pick].ICD_type)]
                        emergency_inflow_no_CC_frail[pick].state = 1
                        hospitalized_half_week.append(emergency_inflow_no_CC_frail[pick])
                        Admitted_E_type_time[t][P_Group.index(emergency_inflow_no_CC_frail[pick].ICD_type)] += 1
                        G_Star_beds[t] += beta_0_E_G_Star[P_Group.index(emergency_inflow_no_CC_frail[pick].ICD_type)]
                        del emergency_inflow_no_CC_frail[pick]

                    emergency_inflow_no_G_Star_frail = emergency_inflow_no_CC_frail

                    for i in emergency_inflow_no_G_Star_frail:
                        i.state = 4
                        YLL_type_time[t][P_Group.index(i.ICD_type)] += yll[P_Group.index(i.ICD_type)] #update YLL
                        Admission_denials[t][P_Group.index(i.ICD_type)] += 1
                        
                else: #frail patients go to G* since CC is full
                    while ((emergency_inflow_frail != []) & (resource_availability[t][0] > 0)):
                        pick = random.randrange(len(emergency_inflow_frail))
                        resource_availability[t][0] -= beta_0_E_G_Star[P_Group.index(emergency_inflow_frail[pick].ICD_type)]
                        E_G_Star_beds_type_time[t][P_Group.index(emergency_inflow_frail[pick].ICD_type)] += beta_0_E_G_Star[P_Group.index(emergency_inflow_frail[pick].ICD_type)]
                        emergency_inflow_frail[pick].state = 1
                        hospitalized_half_week.append(emergency_inflow_frail[pick])
                        Admitted_E_type_time[t][P_Group.index(emergency_inflow_frail[pick].ICD_type)] += 1
                        G_Star_beds[t] += beta_0_E_G_Star[P_Group.index(emergency_inflow_frail[pick].ICD_type)]
                        del emergency_inflow_frail[pick]

                    emergency_inflow_frail_no_G_Star = emergency_inflow_frail #those who could not be accommodated in G* go to G

                    for i in emergency_inflow_frail_no_G_Star:
                        i.state = 4
                        YLL_type_time[t][P_Group.index(i.ICD_type)] += yll[P_Group.index(i.ICD_type)] #update YLL
                        Admission_denials[t][P_Group.index(i.ICD_type)] += 1 

            else: #when policy is OFF
              emergency_inflow = [] 
              for s in P_Group:
                  for i in range(1, inflow_E_C[P_Group.index(s)] + 1): # 
                        emergency_inflow.append(Patient(s, t, "E", 2)) #people requiring CC 

              while ((emergency_inflow != []) & (resource_availability[t][1] > 0)):
                    pick = random.randrange(len(emergency_inflow))
                    resource_availability[t][1] -= beta_0_E_C[P_Group.index(emergency_inflow[pick].ICD_type)]
                    E_C_beds_type_time[t][P_Group.index(emergency_inflow[pick].ICD_type)] += beta_0_E_C[P_Group.index(emergency_inflow[pick].ICD_type)]
                    hospitalized_half_week.append(emergency_inflow[pick])
                    Admitted_E_type_time[t][P_Group.index(emergency_inflow[pick].ICD_type)] += 1
                    del emergency_inflow[pick]

              emergency_inflow_no_CC = emergency_inflow

              while ((emergency_inflow_no_CC != []) & (resource_availability[t][0] > 0)):
                        pick = random.randrange(len(emergency_inflow_no_CC))
                        resource_availability[t][0] -= beta_0_E_G_Star[P_Group.index(emergency_inflow_no_CC[pick].ICD_type)]
                        E_G_Star_beds_type_time[t][P_Group.index(emergency_inflow_no_CC[pick].ICD_type)] += beta_0_E_G_Star[P_Group.index(emergency_inflow_no_CC[pick].ICD_type)]
                        emergency_inflow_no_CC[pick].state = 1
                        hospitalized_half_week.append(emergency_inflow_no_CC[pick])
                        Admitted_E_type_time[t][P_Group.index(emergency_inflow_no_CC[pick].ICD_type)] += 1
                        G_Star_beds[t] += beta_0_E_G_Star[P_Group.index(emergency_inflow_no_CC[pick].ICD_type)]
                        del emergency_inflow_no_CC[pick]

              emergency_inflow_no_GA = emergency_inflow_no_CC

              for i in emergency_inflow_no_GA:
                        i.state = 4
                        YLL_type_time[t][P_Group.index(i.ICD_type)] += yll[P_Group.index(i.ICD_type)] #update YLL
                        Admission_denials[t][P_Group.index(i.ICD_type)] += 1
                        
        #starting in GA  
        if (np.sum(np.multiply(beta_0_E_G, inflow_E_G)) <= resource_availability[t][0]):
            for s in P_Group:
                for i in range(1, inflow_E_G[P_Group.index(s)] + 1):
                    hospitalized_half_week.append(Patient(s, t, "E", 0)) #hospitalized in G
                    resource_availability[t][0] -= beta_0_E_G[P_Group.index(s)]
                    E_G_beds_type_time[t][P_Group.index(s)] += beta_0_E_G[P_Group.index(s)]
                    Admitted_E_type_time[t][P_Group.index(s)] += 1

         ## if no space in G, emergency patients die             
        else:
            emergency_inflow = []

            for s in P_Group:
              for i in range(1, inflow_E_G[P_Group.index(s)] + 1): # 
                  emergency_inflow.append(Patient(s, t, "E", 0)) #people requiring GA 

            while ((emergency_inflow != []) & (resource_availability[t][0] > 0)):
                    pick = random.randrange(len(emergency_inflow))
                    resource_availability[t][0] -= beta_0_E_G[P_Group.index(emergency_inflow[pick].ICD_type)]
                    E_G_beds_type_time[t][P_Group.index(emergency_inflow[pick].ICD_type)] += beta_0_E_G[P_Group.index(emergency_inflow[pick].ICD_type)]
                    hospitalized_half_week.append(emergency_inflow[pick])
                    Admitted_E_type_time[t][P_Group.index(emergency_inflow[pick].ICD_type)] += 1
                    del emergency_inflow[pick]

            emergency_inflow_no_GA = emergency_inflow #people not admitted to G, they die

            for i in emergency_inflow_no_GA:
                  i.state = 4  #update state to D
                  YLL_type_time[t][P_Group.index(i.ICD_type)] += yll[P_Group.index(i.ICD_type)] #update YLL
                  Admission_denials[t][P_Group.index(i.ICD_type)] += 1
                  
        for s in P_Group:
            cost_type_time[t][P_Group.index(s)] += cost_type_E[P_Group.index(s)]*Admitted_E_type_time[t][P_Group.index(s)]

        #electives
        Waiting_C = np.zeros(len(P_Group))
        Waiting_G = np.zeros(len(P_Group))
        inflow_N_C = np.zeros(len(P_Group))
        inflow_N_G = np.zeros(len(P_Group))

        for s in P_Group:
            inflow_N = phi_N[t][P_Group.index(s)] + Waiting_type_time[t][P_Group.index(s)]*(1 - pi_x[P_Group.index(s)]) #mutliply (1-pi_x)
            inflow_N_C[P_Group.index(s)] = math.ceil(pi_z_N[s][t]*inflow_N)
            inflow_N_G[P_Group.index(s)] = math.ceil((1 - pi_z_N[s][t])*inflow_N)

            Waiting_C[P_Group.index(s)] += inflow_N_C[P_Group.index(s)]
            Waiting_G[P_Group.index(s)] += inflow_N_G[P_Group.index(s)]

            #all elective patients go to waiting list first
        if t in T_policy: #update number of waiting patients
###################################
####### UNCOMMENT HERE, policy 1,2: 0% admitted #######
###################################
#            for s in P_Group:
#                Waiting_type_time[t+1][P_Group.index(s)] = Waiting_G[P_Group.index(s)] + Waiting_C[P_Group.index(s)]
###################################
###################################
####### UNCOMMENT HERE, policy 3,4: x% admitted, x>0 #######
###################################
            threshold_to_admit = 0.25 #update x% here
            
            Waiting_C_non_frail = np.zeros(len(P_Group))
            Waiting_C_frail = np.zeros(len(P_Group))
            
            for s in P_Group: 
                Waiting_C_non_frail[P_Group.index(s)] = Waiting_C[P_Group.index(s)]*non_frail_prop_N[t][P_Group.index(s)]
                Waiting_C_frail[P_Group.index(s)] = Waiting_C[P_Group.index(s)]*(1 - non_frail_prop_N[t][P_Group.index(s)])
            #priority to non-frail patients first    
            if (resource_availability[t][1] > 0):
                num_to_admit_C_non_frail = np.zeros(len(P_Group))
                factor_N_C = np.sum(np.multiply(beta_0_N_C, Waiting_C_non_frail))
                for s in P_Group:
                    if beta_0_N_C[P_Group.index(s)] == 0:
                        num_to_admit_C_non_frail[P_Group.index(s)] = 0
                    else:
                        available_resource = resource_availability[t][1]
                        num_to_admit_C_non_frail[P_Group.index(s)] = math.floor(min(Waiting_C_non_frail[P_Group.index(s)], np.multiply(np.divide(Waiting_C_non_frail[P_Group.index(s)], factor_N_C), available_resource))*threshold_to_admit)

                for s in P_Group:    
                    for i in range(int(num_to_admit_C_non_frail[P_Group.index(s)])):
                        hospitalized_half_week.append(Patient(s, t, "N", 2))
                        resource_availability[t][1] -= beta_0_N_C[P_Group.index(s)]
                        N_C_beds_type_time[t][P_Group.index(s)] += beta_0_N_C[P_Group.index(s)]

                    Admitted_N_type_time[t][P_Group.index(s)] += num_to_admit_C_non_frail[P_Group.index(s)]
                    temp = Waiting_C_non_frail[P_Group.index(s)] - num_to_admit_C_non_frail[P_Group.index(s)]
                    Waiting_C_non_frail[P_Group.index(s)] = temp
                    
            #frail patients if there is space available after admitting non-frail patients
            if (resource_availability[t][1] > 0):
                num_to_admit_C_frail = np.zeros(len(P_Group))
                factor_N_C = np.sum(np.multiply(beta_0_N_C, Waiting_C_frail))
                for s in P_Group:
                    if beta_0_N_C[P_Group.index(s)] == 0:
                        num_to_admit_C_frail[P_Group.index(s)] = 0
                    else:
                        available_resource = resource_availability[t][1]
                        num_to_admit_C_frail[P_Group.index(s)] = math.floor(min(Waiting_C_frail[P_Group.index(s)], np.multiply(np.divide(Waiting_C_frail[P_Group.index(s)], factor_N_C), available_resource))*threshold_to_admit)

                for s in P_Group:    
                    for i in range(int(num_to_admit_C_frail[P_Group.index(s)])):
                        hospitalized_half_week.append(Patient(s, t, "N", 2))
                        resource_availability[t][1] -= beta_0_N_C[P_Group.index(s)]
                        N_C_beds_type_time[t][P_Group.index(s)] += beta_0_N_C[P_Group.index(s)]
                    Admitted_N_type_time[t][P_Group.index(s)] += num_to_admit_C_frail[P_Group.index(s)]
                    temp = Waiting_C_frail[P_Group.index(s)] - num_to_admit_C_frail[P_Group.index(s)]
                    Waiting_C_frail[P_Group.index(s)] = temp
            
            for  s in P_Group:        
                Waiting_C[P_Group.index(s)] = Waiting_C_non_frail[P_Group.index(s)] + Waiting_C_frail[P_Group.index(s)]

            if (resource_availability[t][0] > 0):
                num_to_admit_G = np.zeros(len(P_Group))
                factor_N_G = np.sum(np.multiply(beta_0_N_G, Waiting_G))
                for s in P_Group:
                    if beta_0_N_G[P_Group.index(s)] == 0:
                        num_to_admit_G[P_Group.index(s)] = 0
                    else:
                        available_resource = resource_availability[t][0]
                        num_to_admit_G[P_Group.index(s)] = math.floor(min(Waiting_G[P_Group.index(s)], np.multiply(np.divide(Waiting_G[P_Group.index(s)], factor_N_G), available_resource))*threshold_to_admit)

                for s in P_Group:
                    #admission to GA in FIFO 
                    for i in range(int(num_to_admit_G[P_Group.index(s)])):
                        hospitalized_half_week.append(Patient(s, t, "N", 0))
                        resource_availability[t][0] -= beta_0_N_G[P_Group.index(s)]
                        N_G_beds_type_time[t][P_Group.index(s)] += beta_0_N_G[P_Group.index(s)]
                    Admitted_N_type_time[t][P_Group.index(s)] += num_to_admit_G[P_Group.index(s)]
                    temp = Waiting_G[P_Group.index(s)] - num_to_admit_G[P_Group.index(s)]
                    Waiting_G[P_Group.index(s)] = temp
               
            for s in P_Group:        
                cost_type_time[t][P_Group.index(s)] += cost_type_N[P_Group.index(s)]*Admitted_N_type_time[t][P_Group.index(s)]
                Waiting_type_time[t+1][P_Group.index(s)] = Waiting_G[P_Group.index(s)]+ Waiting_C[P_Group.index(s)]  
###threshold policy ends here####

#when government policy is OFF, we admit patients in FIFO
        if t not in T_policy: 
        #FIFO rule
        #finding weighted admissions from each groups
        #starting from C
            if (resource_availability[t][1] > 0): 
                if (np.sum(np.multiply(beta_0_N_C, inflow_N_C)) <= resource_availability[t][1]): #enough resources for all patients
                    for s in P_Group: 
                        for i in range(1, int(inflow_N_C[P_Group.index(s)]) + 1):
                            hospitalized_half_week.append(Patient(s, t, "N", 2))
                            resource_availability[t][1] -= beta_0_N_C[P_Group.index(s)]#patient is in CC
                            N_C_beds_type_time[t][P_Group.index(s)] += beta_0_N_C[P_Group.index(s)]
                            Admitted_N_type_time[t][P_Group.index(s)] += 1
                        Waiting_C[P_Group.index(s)] = 0

                else:
                    num_to_admit_C = np.zeros(len(P_Group))                    
                    factor_N_C = np.sum(np.multiply(beta_0_N_C, Waiting_C))                    
                    for s in P_Group:
                        if beta_0_N_C[P_Group.index(s)] == 0:
                            num_to_admit_C[P_Group.index(s)] = 0
                        else:
                            available_resource = resource_availability[t][1]
                            num_to_admit_C[P_Group.index(s)] = math.floor(np.multiply(np.divide(Waiting_C[P_Group.index(s)], factor_N_C), available_resource))

                    for s in P_Group:    
                        for i in range(int(num_to_admit_C[P_Group.index(s)])):
                            hospitalized_half_week.append(Patient(s, t, "N", 2))
                            resource_availability[t][1] -= beta_0_N_C[P_Group.index(s)]
                            N_C_beds_type_time[t][P_Group.index(s)] += beta_0_N_C[P_Group.index(s)]        
                        Admitted_N_type_time[t][P_Group.index(s)] += num_to_admit_C[P_Group.index(s)]
                        temp = Waiting_C[P_Group.index(s)] - num_to_admit_C[P_Group.index(s)]
                        Waiting_C[P_Group.index(s)] = temp

            #starting in GA  
            if (resource_availability[t][0] > 0):
                if (np.sum(np.multiply(beta_0_N_G, inflow_N_G)) <= resource_availability[t][0]):
                    for s in P_Group:
                        for i in range(1, int(inflow_N_G[P_Group.index(s)]) + 1):
                            hospitalized_half_week.append(Patient(s, t, "N", 0))  
                            resource_availability[t][0] -= beta_0_N_G[P_Group.index(s)]#patient is in GA
                            N_G_beds_type_time[t][P_Group.index(s)] += beta_0_N_G[P_Group.index(s)]
                            Admitted_N_type_time[t][P_Group.index(s)] += 1
                        Waiting_G[P_Group.index(s)] = 0

                else:     
                    num_to_admit_G = np.zeros(len(P_Group))                   
                    factor_N_G = np.sum(np.multiply(beta_0_N_G, Waiting_G))
                    for s in P_Group:
                        if beta_0_N_G[P_Group.index(s)] == 0:
                            num_to_admit_G[P_Group.index(s)] = 0
                        else:
                            available_resource = resource_availability[t][0]
                            num_to_admit_G[P_Group.index(s)] = math.floor(np.multiply(np.divide(Waiting_G[P_Group.index(s)], factor_N_G), available_resource))
                        
                    for s in P_Group:
                        #admission to GA in FIFO 
                        for i in range(int(num_to_admit_G[P_Group.index(s)])):
                            hospitalized_half_week.append(Patient(s, t, "N", 0))
                            resource_availability[t][0] -= beta_0_N_G[P_Group.index(s)]
                            N_G_beds_type_time[t][P_Group.index(s)] += beta_0_N_G[P_Group.index(s)]

                        Admitted_N_type_time[t][P_Group.index(s)] += num_to_admit_G[P_Group.index(s)]
                        temp = Waiting_G[P_Group.index(s)] - num_to_admit_G[P_Group.index(s)]
                        Waiting_G[P_Group.index(s)] = temp

            for s in P_Group:        
                cost_type_time[t][P_Group.index(s)] += cost_type_N[P_Group.index(s)]*Admitted_N_type_time[t][P_Group.index(s)]
                Waiting_type_time[t+1][P_Group.index(s)] = Waiting_G[P_Group.index(s)]+ Waiting_C[P_Group.index(s)]  
                
#last week evolution for accounting for YLL 
    print("final accounting of YLL")
    for patient in hospitalized:
            new_state = evolution(patient.state, patient.ICD_type, patient.adm_type) 

            if (new_state == 4):
                YLL_type_time[t+1][P_Group.index(patient.ICD_type)] += yll[P_Group.index(patient.ICD_type)]

    for patient in hospitalized_half_week:
            new_state = evolution_half_week(patient.state, patient.ICD_type, patient.adm_type)
            
            if (new_state == 4):
                YLL_type_time[t+1][P_Group.index(patient.ICD_type)] += yll[P_Group.index(patient.ICD_type)]

main(52) 

#writing output files
output_list = ["Admitted_E", "Admitted_N", "cost", "YLL", "Waiting", "Admission_denials", "N_G_beds", "N_C_beds", "N_G_Star", "E_G_beds", "E_C_beds", "E_G_Star_beds"]
outputs = [Admitted_E_type_time, Admitted_N_type_time, cost_type_time, YLL_type_time, Waiting_type_time, Admission_denials, N_G_beds_type_time, N_C_beds_type_time, N_G_Star_beds_type_time, E_G_beds_type_time, E_C_beds_type_time, E_G_Star_beds_type_time]#, Admitted_N_C_type_time, Admitted_N_G_type_time]#, Denials_C_type_time, Denials_G_type_time, Waiting_C_type_time, Waiting_G_type_time]
cols = P_Group

i = 0
writer = pd.ExcelWriter('../output/G_output.xlsx')
for o in outputs:
    test = pd.DataFrame(o, columns = cols)
    test.to_excel(writer, output_list[i])
    i += 1

test1 = pd.DataFrame(resource_availability, columns = ["G_Beds", "C_Beds"])            
test1.to_excel(writer, 'idle_resources')
test2 = pd.DataFrame(G_Star_beds)                              
test2.to_excel(writer, 'G_Star_beds')

writer.save()         
