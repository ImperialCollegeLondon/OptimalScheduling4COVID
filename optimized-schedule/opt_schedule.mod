# -------------------------------------------------------------------------------------------------------------------------	
#	OR4COVID
#	Model file
# -------------------------------------------------------------------------------------------------------------------------		


###############
###  SETS  ####
###############

param T; # number of time periods (weeks) 
set TIMES := 0 .. T; # Assumptions: 1) t refers to beginning of week t = end of week t-1; 2) New inflows and admission decisions are taken in the middle of each week
set RESOURCES;
set PATIENT_GROUPS; # code: ICD##_AGE# (e.g. ICD02_AGE3)
set ADMISSION_TYPES; # elective (N) or emergency (E)
set SEVERITY_STATES; # Recovered (H), G&A (G), G&A if denied CC (G_STAR), Critical/ICU (C), Dead (D)
set FRAILTY; # frail (F), or non-frail (NF)
set BUNDLE_51_PATIENT_GROUPS_AGE1; # Ps belonging only to emergency bundle ICD_51_AGE1
set BUNDLE_51_PATIENT_GROUPS_AGE2; # Ps belonging only to emergency bundle ICD_51_AGE2
set BUNDLE_51_PATIENT_GROUPS_AGE3; # Ps belonging only to emergency bundle ICD_51_AGE3
set BUNDLE_50_PATIENT_GROUPS_AGE1; # Ps belonging only to elective bundle ICD_50_AGE1
set BUNDLE_50_PATIENT_GROUPS_AGE2; # Ps belonging only to elective bundle ICD_50_AGE2
set BUNDLE_50_PATIENT_GROUPS_AGE3; # Ps belonging only to elective bundle ICD_50_AGE3


####################
###  PARAMETERS  ###
####################
param phi {TIMES, PATIENT_GROUPS, ADMISSION_TYPES, FRAILTY} default 0; # New patients inflows during week t
param phi_1 {TIMES, PATIENT_GROUPS, ADMISSION_TYPES} default 0; # epi1 New patients inflows during week t
param phi_2 {TIMES, PATIENT_GROUPS, ADMISSION_TYPES} default 0; # epi2 New patients inflows during week t
param phi_3 {TIMES, PATIENT_GROUPS, ADMISSION_TYPES} default 0; # epi3 New patients inflows during week t
param phi_4 {TIMES, PATIENT_GROUPS, ADMISSION_TYPES} default 0; # epi4 New patients inflows during week t
param pi_w {PATIENT_GROUPS} default 0; # probability of waiting patients to become emergencies
param pi_z {TIMES, PATIENT_GROUPS, SEVERITY_STATES, ADMISSION_TYPES} default 0; # Probability of being admitted to G&A or CC. pi_z = 0 for G_STAR. 
param pi_y {p in PATIENT_GROUPS, s in SEVERITY_STATES, s1 in SEVERITY_STATES, a in ADMISSION_TYPES} default 0; # pi_y at week 1.5. This parameter applies to patients staying longer than 3.5 days. Probability of changing severity states once in hospital
param pi_0 {p in PATIENT_GROUPS, s in SEVERITY_STATES, s1 in SEVERITY_STATES, a in ADMISSION_TYPES} default 0; # pi_y at week 0.5. This parameter applies to patients staying less than 3.5 days. Probability of changing severity states in the first 3.5 days
param delta {SEVERITY_STATES, RESOURCES} default 0; # Patient resource requirements (0 for H and D). This parameter applies to patients staying longer than 3.5 days.
param delta_0 {PATIENT_GROUPS, SEVERITY_STATES, RESOURCES, ADMISSION_TYPES} default 0.5; # Patient resource requirements (0 for H and D) in the first 3.5 days. This parameter applies to patients staying less than 3.5 days. Unless explicitly declared, it is set to 0.5 (i.e. half-week resource consumption, for patients staying more >= 3.5 days)
param xi {RESOURCES}; # Availability of resources
param xi_add {RESOURCES}; # Availability of additional resources
param lambda {PATIENT_GROUPS}; # Years of life lost
param lambda2 {PATIENT_GROUPS}; # Years of life lost (scenario A - just used for post-computation)
param theta {TIMES, PATIENT_GROUPS} default 0; # Proportion of people transferring out of ICD_50 into ICD_1,4,5,15 at time t;
param cost {PATIENT_GROUPS, ADMISSION_TYPES} default 0; # average cost per patient group. Cost is 0 if no inflow for that group
param pi_f {TIMES, PATIENT_GROUPS, ADMISSION_TYPES} default 0; # proportion of frail patients per each time and patient group

# Parameters to initialize model
param w0 {PATIENT_GROUPS} default 0; # (remove default 0?) Patients waiting at the beginning of the planning horizon
param y0 {PATIENT_GROUPS, SEVERITY_STATES, ADMISSION_TYPES} default 0; # Patients already hosptialized at the beginning of the planning horizon (0 for H, D and G_STAR)

param deactivate_inf_waiting default 0; # set as 1 for deactivating infinitely waiting patients (in best case scenarios), else 0


###################
###  VARIABLES  ###
###################
var w {TIMES, PATIENT_GROUPS, FRAILTY} >= 0; # Total waiting patients at the beginning of week t
var z {TIMES, PATIENT_GROUPS, ADMISSION_TYPES, FRAILTY} >= 0; # patients admitted to hospital in week t
var z_prime {TIMES, PATIENT_GROUPS, SEVERITY_STATES, ADMISSION_TYPES, FRAILTY} >= 0; # patients admitted to G, G_STAR, C, D in week t
var x {TIMES, PATIENT_GROUPS, SEVERITY_STATES, SEVERITY_STATES, ADMISSION_TYPES, FRAILTY} >= 0;  # transfers across severity states for hospitalised patients (weekly transitions)
var x_prime {TIMES, PATIENT_GROUPS, SEVERITY_STATES, SEVERITY_STATES, ADMISSION_TYPES, FRAILTY} >= 0;  # transfers across severity states for hospitalised patients (first 3.5 days)
var y {TIMES, PATIENT_GROUPS, SEVERITY_STATES, ADMISSION_TYPES, FRAILTY} >= 0; # Total number of patients for each severity state at the beginning of week t
var YearsofLifeLost >= 0; # Years of Life Lost
var TotalCost >= 0; # Calculation of total cost

# Slack variables
var slack {TIMES, RESOURCES} >= 0;
var TotalSlack >= 0;
var bin_var {TIMES} binary;
# var bin_frail {TIMES} binary;


#####################
###  CONSTRAINTS  ###
#####################

# Initialization:
subject to initialize_w_f {p in PATIENT_GROUPS}:
	w [0,p,"F"] = w0 [p] * pi_f [0,p,"N"];

subject to initialize_w_nf {p in PATIENT_GROUPS}:
	w [0,p,"NF"] = w0 [p] * (1 - pi_f [0,p,"N"]);

subject to initialize_y_f {p in PATIENT_GROUPS, s in SEVERITY_STATES, a in ADMISSION_TYPES}:
	y [0,p,s,a,"F"] = y0 [p,s,a] * pi_f [0,p,a];
	
subject to initialize_y_nf {p in PATIENT_GROUPS, s in SEVERITY_STATES, a in ADMISSION_TYPES}:
	y [0,p,s,a,"NF"] = y0 [p,s,a] * (1 - pi_f [0,p,a]);

subject to yll:
	YearsofLifeLost = sum {t in TIMES, p in PATIENT_GROUPS, a in ADMISSION_TYPES, f in FRAILTY} (lambda [p] * (y [t,p,"D",a,f] + z_prime [t,p,"D",a,f]));

subject to totalcost:
	TotalCost = sum {t in TIMES, p in PATIENT_GROUPS, a in ADMISSION_TYPES, f in FRAILTY} (cost [p,a] * z [t,p,a,f]);

subject to total_slack:
	TotalSlack = sum {t in TIMES, r in RESOURCES} slack [t,r];
	
#subject to no_waiting_OR {t in TIMES : t <> T and t >= 25}:
#	sum{p in PATIENT_GROUPS, f in FRAILTY} w [t+1,p,f] <= 10000000*(1 -  bin_var[t] + (1 - deactivate_inf_waiting));

#subject to no_slack_OR  {t in TIMES : t <> T and t >= 25}:
#	 sum{r in RESOURCES} slack[t, r] <= 10000000*(bin_var[t] + (1 - deactivate_inf_waiting));
	
# No Slack in CC
#subject to slack_cc {t in TIMES, r in RESOURCES}:
#	slack [t,r] <= 0;

# Either frail in CC or non-frail in G_STAR
#subject to frail_CC_1 {t in TIMES, f in {"F"}, s in {"C"}}:
#	sum {p in PATIENT_GROUPS, a in ADMISSION_TYPES} (z_prime [t,p,s,a,f] + sum {s1 in {"G", "G_STAR","C"}} (x_prime [t,p,s1,s,a,f] + x [t,p,s1,s,a,f])) <= 10000 * bin_frail[t];

#subject to frail_CC_2 {t in TIMES, f in {"NF"}, s in {"G_STAR"}}:
#	sum {p in PATIENT_GROUPS, a in ADMISSION_TYPES} (z_prime [t,p,s,a,f] + sum {s1 in {"G", "G_STAR","C"}} (x_prime [t,p,s1,s,a,f] + x [t,p,s1,s,a,f])) <= 10000 * (1-bin_frail[t]);
	
subject to waiting_patients {t in TIMES, p in PATIENT_GROUPS, f in FRAILTY: t <> T}:
	w [t+1,p,f] = phi_1 [t,p,"N"] * pi_f [t,p,"N"] + w[t,p,f] * (1 - pi_w[p]) - z[t,p,"N",f];
	
subject to admitted_emergencies {t in TIMES, p in PATIENT_GROUPS diff {"ICD51_AGE1", "ICD51_AGE2", "ICD51_AGE3", "BUNDLE_50_PATIENT_GROUPS_AGE1", "BUNDLE_50_PATIENT_GROUPS_AGE2", "BUNDLE_50_PATIENT_GROUPS_AGE3"}, f in FRAILTY}:
	z [t,p,"E",f] + z_prime [t,p,"D","E",f] = phi_1 [t,p,"E"] * pi_f [t,p,"E"] + w[t,p,f] * pi_w[p];
	
# Some patients might be denied CC upon admission. In this case, they are admitted to G*
subject to admission_cc {t in TIMES, p in PATIENT_GROUPS, a in ADMISSION_TYPES, f in FRAILTY}:
	z_prime [t,p,"C",a,f] + z_prime [t,p,"G_STAR",a,f] = z [t,p,a,f] * pi_z [t,p,"C",a];
	
# All patients needing G&A are admitted to G&A. If denied, we assume they die
subject to admission_ga {t in TIMES, p in PATIENT_GROUPS, a in ADMISSION_TYPES, f in FRAILTY}:
	z_prime [t,p,"G",a,f] = z [t,p,a,f] * pi_z [t,p,"G",a];

subject to hospitalized_patients {t in TIMES, p in PATIENT_GROUPS, s in SEVERITY_STATES, a in ADMISSION_TYPES, f in FRAILTY: t <> T}:
	y [t+1,p,s,a,f] = sum {s1 in SEVERITY_STATES diff {"H", "D"}} (x [t,p,s1,s,a,f] + x_prime [t,p,s1,s,a,f]);

# Transitions (first 3.5 days) for all patients excluding admission to CC and G_STAR
subject to hospital_transitions_1_halfweek {t in TIMES, p in PATIENT_GROUPS, s1 in SEVERITY_STATES, s in SEVERITY_STATES, a in ADMISSION_TYPES, f in FRAILTY: t <> T && s1 in {"G", "G_STAR","C"} && s in {"G", "H", "D"}}:
	x_prime [t,p,s1,s,a,f] = pi_0 [p,s1,s,a] * z_prime [t,p,s1,a,f];

# Transition (first 3.5 days) from CC to G_STAR: patients might need to leave CC when overflowing capacity
subject to hospital_transitions_2_halfweek {t in TIMES, p in PATIENT_GROUPS, a in ADMISSION_TYPES, f in FRAILTY}:
	x_prime [t,p,"C","C",a,f] + x_prime [t,p,"C","G_STAR",a,f] = pi_0 [p,"C","C",a] * z_prime [t,p,"C",a,f];

# Transitions (first 3.5 days) of patients to CC and G_STAR: patients needing CC are admitted if possible; else, they transition to G_STAR
subject to hospital_transitions_3_halfweek {t in TIMES, p in PATIENT_GROUPS, a in ADMISSION_TYPES, f in FRAILTY: t <> T}:
	x_prime [t,p,"G","C",a,f] + x_prime [t,p,"G","G_STAR",a,f] = pi_0 [p,"G","C",a] * z_prime [t,p,"G",a,f];
	
# Transitions (first 3.5 days) of patients to CC and G_STAR: patients in G_STAR transferred to CC if there is capacity; else, they remain in G_STAR
subject to hospital_transitions_4_halfweek {t in TIMES, p in PATIENT_GROUPS, a in ADMISSION_TYPES, f in FRAILTY: t <> T}:
	x_prime [t,p,"G_STAR","C",a,f] + x_prime [t,p,"G_STAR","G_STAR",a,f] = pi_0 [p,"G_STAR","C",a] * z_prime [t,p,"G_STAR",a,f];

# Transitions (weekly) for all patients excluding admission to CC and G_STAR
subject to hospital_transitions_1 {t in TIMES, p in PATIENT_GROUPS, s1 in SEVERITY_STATES, s in SEVERITY_STATES, a in ADMISSION_TYPES, f in FRAILTY: t <> T && s1 in {"G", "G_STAR","C"} && s in {"G", "H", "D"}}:
	x [t,p,s1,s,a,f] = pi_y [p,s1,s,a] * y[t,p,s1,a,f];
	
# Transition (weekly) from CC to G_STAR: patients might need to leave CC when overflowing capacity
subject to hospital_transitions_2 {t in TIMES, p in PATIENT_GROUPS, a in ADMISSION_TYPES, f in FRAILTY}:
	x [t,p,"C","C",a,f] + x [t,p,"C","G_STAR",a,f] = pi_y [p,"C","C",a] * y[t,p,"C",a,f];

# Transitions (weekly) of patients to CC and G_STAR: patients needing CC are admitted if possible; else, they transition to G_STAR
subject to hospital_transitions_3 {t in TIMES, p in PATIENT_GROUPS, a in ADMISSION_TYPES, f in FRAILTY: t <> T}:
	x [t,p,"G","C",a,f] + x [t,p,"G","G_STAR",a,f] = pi_y [p,"G","C",a] * y[t,p,"G",a,f];
	
# Transitions (weekly) of patients to CC and G_STAR: patients in G_STAR transferred to CC if there is capacity; else, they remain in G_STAR
subject to hospital_transitions_4 {t in TIMES, p in PATIENT_GROUPS, a in ADMISSION_TYPES, f in FRAILTY: t <> T}:
	x [t,p,"G_STAR","C",a,f] + x [t,p,"G_STAR","G_STAR",a,f] = pi_y [p,"G_STAR","C",a] * y[t,p,"G_STAR",a,f];

# Resource constraints + slack (the first part, with delta_0, accounts for the resource consumption by patients staying in hospital less than 3.5 days)
subject to resource_availability {t in TIMES, r in RESOURCES}:
	sum {s in SEVERITY_STATES diff {"H", "D"}, p in PATIENT_GROUPS, a in ADMISSION_TYPES, f in FRAILTY} (delta_0 [p,s,r,a] * (sum {s1 in {"H", "D"}} x_prime [t,p,s,s1,a,f]) + 0.5 * delta [s,r] * (sum {s2 in SEVERITY_STATES diff {"H", "D"}} x_prime [t,p,s,s2,a,f]) + delta [s,r] * y [t,p,s,a,f])  + slack [t,r] = xi [r] + xi_add [r];

## Bundling (should it be deprecated?)
subject to admitted_emergencies_51_AGE1 {t in TIMES, f in FRAILTY}:
	z [t, "ICD51_AGE1","E", f] + z_prime [t,"ICD51_AGE1","D","E", f] = phi_1 [t,"ICD51_AGE1","E"] * pi_f [t,"ICD51_AGE1","E"] + sum {m in BUNDLE_51_PATIENT_GROUPS_AGE1} (w [t,m,f] * pi_w [m]) + w[t, "ICD50_AGE1",f]* pi_w["ICD50_AGE1"]*theta [t, "ICD50_AGE1"]; 

subject to admitted_emergencies_51_AGE2 {t in TIMES, f in FRAILTY}:
	z [t, "ICD51_AGE2","E",f] + z_prime [t,"ICD51_AGE2","D","E",f] = phi_1 [t,"ICD51_AGE2","E"] * pi_f [t,"ICD51_AGE2","E"] + sum {m in BUNDLE_51_PATIENT_GROUPS_AGE2} (w [t,m,f] * pi_w [m]) + w[t, "ICD50_AGE2",f]* pi_w["ICD50_AGE2"]*theta [t, "ICD50_AGE2"]; 

subject to admitted_emergencies_51_AGE3 {t in TIMES, f in FRAILTY}:
	z [t, "ICD51_AGE3","E",f] + z_prime [t,"ICD51_AGE3","D","E",f] = phi_1 [t,"ICD51_AGE3","E"] * pi_f [t,"ICD51_AGE3","E"] + sum {m in BUNDLE_51_PATIENT_GROUPS_AGE3} (w [t,m,f] * pi_w [m]) + w[t, "ICD50_AGE3",f]* pi_w["ICD50_AGE3"]*theta [t, "ICD50_AGE3"]; 

subject to admitted_emergencies_50_AGE1 {t in TIMES, p in BUNDLE_50_PATIENT_GROUPS_AGE1, f in FRAILTY}:
	z [t,p,"E",f] + z_prime [t,p,"D","E",f] = phi_1 [t,p,"E"] * pi_f [t,p,"E"] + w[t,"ICD50_AGE1",f] * pi_w["ICD50_AGE1"] * theta[t, p];

subject to admitted_emergencies_50_AGE2 {t in TIMES, p in BUNDLE_50_PATIENT_GROUPS_AGE2, f in FRAILTY}:
	z [t,p,"E",f] + z_prime [t,p,"D","E",f] = phi_1 [t,p,"E"] * pi_f [t,p,"E"] + w[t,"ICD50_AGE2",f] * pi_w["ICD50_AGE2"] * theta[t, p];
	
subject to admitted_emergencies_50_AGE3 {t in TIMES, p in BUNDLE_50_PATIENT_GROUPS_AGE3, f in FRAILTY}:
	z [t,p,"E",f] + z_prime [t,p,"D","E",f] = phi_1 [t,p,"E"] * pi_f [t,p,"E"] + w[t,"ICD50_AGE3",f] * pi_w["ICD50_AGE3"] * theta[t, p];

/*
##  For Pareto frontier
param Param_Pareto default 0;

subject to Pareto_constraint:
	TotalCost <= Param_Pareto;
*/

# Objective
 minimize obj: YearsofLifeLost;

solve;

## PRINTING OUTPUT FILES ##

# waiting_hospitalised.csv: Waiting (W) vs hospitalised (Y) patients at each timestep

printf "Time\tW\t" > "output/waiting_hospitalised.csv";
for {s in SEVERITY_STATES diff {"H", "D"}, a in ADMISSION_TYPES}{
		printf "y\_%s\_%s\t", s, a >> "output/waiting_hospitalised.csv";
	}
printf "\n" > "output/waiting_hospitalised.csv";	
for {t in TIMES}{
	printf "%.0f\t", t >> "output/waiting_hospitalised.csv";
	printf "%.2f\t", sum {p in PATIENT_GROUPS, f in FRAILTY} w [t,p,f] >> "output/waiting_hospitalised.csv";
	for {s in SEVERITY_STATES diff {"H", "D"}, a in ADMISSION_TYPES}{
		printf "%.2f\t", sum {p in PATIENT_GROUPS, f in FRAILTY} y [t,p,s,a,f] >> "output/waiting_hospitalised.csv";
	}
	printf "\n" >> "output/waiting_hospitalised.csv";
}


# recovered_dead.csv: cumulative dead and recovered patients

printf "Time\t" > "output/recovered_dead.csv";
for {s in SEVERITY_STATES: s in {"H", "D"}}{
		printf "%s\t", s >> "output/recovered_dead.csv";
	}
printf "\n" > "output/recovered_dead.csv";	
for {t in TIMES}{
	printf "%.0f\t", t >> "output/recovered_dead.csv";
	for {s in SEVERITY_STATES: s in {"H", "D"}}{
		printf "%.2f\t", sum {t2 in TIMES, p in PATIENT_GROUPS, a in ADMISSION_TYPES, f in FRAILTY: t2 <= t} (y [t2,p,s,a,f] + z_prime [t2,p,s,a,f]) >> "output/recovered_dead.csv";
	}
	printf "\n" >> "output/recovered_dead.csv";
}


# admitted.csv: admitted patients per each week in G, G_STAR, C

printf "Time\t" > "output/admitted.csv";
for {s in SEVERITY_STATES diff {"H", "D"}, a in ADMISSION_TYPES}{
		printf "z_prime\_%s\_%s\t", s, a >> "output/admitted.csv";
	}
printf "\n" > "output/admitted.csv";
for {t in TIMES}{
	printf "%.0f\t", t >> "output/admitted.csv";
	for {s in SEVERITY_STATES diff {"H", "D"}, a in ADMISSION_TYPES}{
		printf "%.2f\t", sum {p in PATIENT_GROUPS, f in FRAILTY} z_prime [t,p,s,a,f] >> "output/admitted.csv";
	}
	printf "\n" >> "output/admitted.csv";
}


# idle_capacity.csv: unused resources per each week

printf "Time\t" > "output/idle_capacity.csv";
for {r in RESOURCES}{
	printf "%s\t", r >> "output/idle_capacity.csv";
	}
printf "\n" > "output/idle_capacity.csv";
for {t in TIMES}{
	printf "%.0f\t", t >> "output/idle_capacity.csv";
	for {r in RESOURCES}{
		printf "%.2f\t", xi [r] + xi_add [r] - sum {s in SEVERITY_STATES diff {"H", "D"}, p in PATIENT_GROUPS, a in ADMISSION_TYPES, f in FRAILTY} (delta_0 [p,s,r,a] * (sum {s1 in {"H", "D"}} x_prime [t,p,s,s1,a,f]) + 0.5 * delta [s,r] * (sum {s2 in SEVERITY_STATES diff {"H", "D"}} x_prime [t,p,s,s2,a,f]) + delta [s,r] * y [t,p,s,a,f]) >> "output/idle_capacity.csv";
	}
	printf "\n" >> "output/idle_capacity.csv";
}


# admitted_p.csv: admitted patients by patient group

for {p in PATIENT_GROUPS}{
    printf "Time\t" > ("output/admitted_p/admitted_" & p & ".csv");
    for {s in SEVERITY_STATES diff {"H", "D"}, a in ADMISSION_TYPES}{
            printf "z_prime\_%s\_%s\t", s, a >> ("output/admitted_p/admitted_" & p & ".csv");
        }
    printf "\n" >("output/admitted_p/admitted_" & p & ".csv");
    for {t in TIMES}{
        printf "%.0f\t", t >> ("output/admitted_p/admitted_" & p & ".csv");
        for {s in SEVERITY_STATES diff {"H", "D"}, a in ADMISSION_TYPES}{
            printf "%.2f\t", sum {f in FRAILTY} z_prime [t,p,s,a,f] >> ("output/admitted_p/admitted_" & p & ".csv");
        }
        printf "\n" >> ("output/admitted_p/admitted_" & p & ".csv");
    }
} 


# waiting_p.csv: waiting patients by patient group


printf "Time\t" > "output/waiting_p.csv";
for {p in PATIENT_GROUPS}{
	printf "%s\t", p  >> "output/waiting_p.csv";
}
printf "\n" > "output/waiting_p.csv";

for {t in TIMES}{
    printf "%.0f\t", t >> "output/waiting_p.csv";
    for {p in PATIENT_GROUPS, a in ADMISSION_TYPES: a == "N"}{
    	printf "%.2f\t",  sum {f in FRAILTY} w [t,p,f] >> "output/waiting_p.csv"; 
    }  
    printf "\n" >> "output/waiting_p.csv";
}


# resource_util.csv: total bed utilization per week (note that G_BEDS includes G_STAR here)

printf "Time\t" > "output/resource_util.csv";
for {r in {"G_BEDS"}}{
		printf "%s_Slack\t", r >> "output/resource_util.csv";
		}
printf "C_BEDS\tG_STAR\t" >> "output/resource_util.csv";

printf "\n" > "output/resource_util.csv";
for {t in TIMES}{
	printf "%.0f\t", t >> "output/resource_util.csv";
	for {r in {"G_BEDS", "C_BEDS"}}{
		printf "%.2f\t", sum {s in SEVERITY_STATES diff {"H", "D"}, p in PATIENT_GROUPS, a in ADMISSION_TYPES, f in FRAILTY} (delta_0 [p,s,r,a] * (sum {s1 in {"H", "D"}} x_prime [t,p,s,s1,a,f]) + 0.5 * delta [s,r] * (sum {s2 in SEVERITY_STATES diff {"H", "D"}} x_prime [t,p,s,s2,a,f]) + delta [s,r] * y [t,p,s,a,f]) >> "output/resource_util.csv";

}
	for {r in {"G_BEDS"}}{
		for {s in {"G_STAR"}}{
			printf "%.2f\t", sum {p in PATIENT_GROUPS, a in ADMISSION_TYPES, f in FRAILTY} (delta_0 [p,s,r,a] * (sum {s1 in {"H", "D"}} x_prime [t,p,s,s1,a,f]) + 0.5 * delta [s,r] * (sum {s2 in SEVERITY_STATES diff {"H", "D"}} x_prime [t,p,s,s2,a,f]) + delta [s,r] * y [t,p,s,a,f]) >> "output/resource_util.csv";
		}
	}
	printf "\n" >> "output/resource_util.csv";
}


# bed_utilization_s.csv: bed utilization by patient groups in G, C, G_STAR. Large patient groups (>X% of units total population) are plotted individually, all others are grouped. Does not account for patients disappearing in less than 3.5 days

for {s in SEVERITY_STATES diff {"H", "D"}}{
	printf "Time\t" >  ("output/bed_utilization_" & s & ".csv");
	
	for {a in ADMISSION_TYPES, p in PATIENT_GROUPS: sum {t2 in TIMES, f in FRAILTY, r in {"G_BEDS", "C_BEDS"}: t2 <= 52} (delta_0 [p,s,r,a] * (sum {s1 in {"H", "D"}} x_prime [t2,p,s,s1,a,f]) + 0.5 * delta [s,r] * (sum {s2 in SEVERITY_STATES diff {"H", "D"}} x_prime [t2,p,s,s2,a,f]) + delta [s,r] * y [t2,p,s,a,f]) >= 0.00001 * (sum {t3 in TIMES, p2 in PATIENT_GROUPS, a2 in ADMISSION_TYPES, f2 in FRAILTY, r2 in {"G_BEDS", "C_BEDS"}: t3 <= 52} (delta_0 [p2,s,r2,a2] * (sum {s1 in {"H", "D"}} x_prime [t3,p2,s,s1,a2,f2]) + 0.5 * delta [s,r2] * (sum {s2 in SEVERITY_STATES diff {"H", "D"}} x_prime [t3,p2,s,s2,a2,f2]) + delta [s,r2] * y [t3,p2,s,a2,f2]) )}{
		printf "%s_%s\t", p, a >>  ("output/bed_utilization_" & s & ".csv");
	}
	printf "Others\n" >> ("output/bed_utilization_" & s & ".csv");

	for {t in TIMES}{
		printf "%.0f\t", t >> ("output/bed_utilization_" & s & ".csv");
	
		# Large patient groups (>X% of units total population) are plotted individually
		for {a in ADMISSION_TYPES, p in PATIENT_GROUPS: sum {t2 in TIMES, f in FRAILTY, r in {"G_BEDS", "C_BEDS"}: t2 <= 52} (delta_0 [p,s,r,a] * (sum {s1 in {"H", "D"}} x_prime [t2,p,s,s1,a,f]) + 0.5 * delta [s,r] * (sum {s2 in SEVERITY_STATES diff {"H", "D"}} x_prime [t2,p,s,s2,a,f]) + delta [s,r] * y [t2,p,s,a,f]) >= 0.00001 * (sum {t3 in TIMES, p2 in PATIENT_GROUPS, a2 in ADMISSION_TYPES, r2 in {"G_BEDS", "C_BEDS"}, f2 in FRAILTY: t3 <= 52} (delta_0 [p2,s,r2,a2] * (sum {s1 in {"H", "D"}} x_prime [t3,p2,s,s1,a2,f2]) + 0.5 * delta [s,r2] * (sum {s2 in SEVERITY_STATES diff {"H", "D"}} x_prime [t3,p2,s,s2,a2,f2]) + delta [s,r2] * y [t3,p2,s,a2,f2]) )}{
			printf "%.2f\t", sum {f3 in FRAILTY, r3 in {"G_BEDS", "C_BEDS"}} (delta_0 [p,s,r3,a] * (sum {s1 in {"H", "D"}} x_prime [t,p,s,s1,a,f3]) + 0.5 * delta [s,r3] * (sum {s2 in SEVERITY_STATES diff {"H", "D"}} x_prime [t,p,s,s2,a,f3]) + delta [s,r3] * y [t,p,s,a,f3]) >> ("output/bed_utilization_" & s & ".csv");
		}
	
		# sum across all other smaller patient groups
		printf "%.2f", sum {p in PATIENT_GROUPS, a in ADMISSION_TYPES, f in FRAILTY, r3 in {"G_BEDS", "C_BEDS"}: sum {t2 in TIMES, f2 in FRAILTY, r in {"G_BEDS", "C_BEDS"}: t2 <= 52} (delta_0 [p,s,r,a] * (sum {s1 in {"H", "D"}} x_prime [t2,p,s,s1,a,f2]) + 0.5 * delta [s,r] * (sum {s2 in SEVERITY_STATES diff {"H", "D"}} x_prime [t2,p,s,s2,a,f2]) + delta [s,r] * y [t2,p,s,a,f2]) < 0.00001 * (sum {t3 in TIMES, p2 in PATIENT_GROUPS, a2 in ADMISSION_TYPES, f3 in FRAILTY, r2 in {"G_BEDS", "C_BEDS"}: t3 <= 52} (delta_0 [p2,s,r2,a2] * (sum {s1 in {"H", "D"}} x_prime [t3,p2,s,s1,a2,f3]) + 0.5 * delta [s,r2] * (sum {s2 in SEVERITY_STATES diff {"H", "D"}} x_prime [t3,p2,s,s2,a2,f3]) + delta [s,r2] * y [t3,p2,s,a2,f3]) )} (delta_0 [p,s,r3,a] * (sum {s1 in {"H", "D"}} x_prime [t,p,s,s1,a,f]) + 0.5 * delta [s,r3] * (sum {s2 in SEVERITY_STATES diff {"H", "D"}} x_prime [t,p,s,s2,a,f]) + delta [s,r3] * y [t,p,s,a,f]) >> ("output/bed_utilization_" & s & ".csv");
		printf "\n" >> ("output/bed_utilization_" & s & ".csv");
	}
}


# g_star.csv: patients hospitalised in G_STAR (per patient group, per time). Plot only if sum_t > 0

printf "Time\t" >  ("output/g_star.csv");
for {p in PATIENT_GROUPS, a in ADMISSION_TYPES: sum {t2 in TIMES, f in FRAILTY: t2 <= 52} (y[t2,p,"G_STAR",a,f]) > 0}{
		printf "y_%s_%s\t", p, a >> ("output/g_star.csv");
	}
printf "\n" > ("output/g_star.csv");
for {t in TIMES}{
	printf "%.0f\t", t >> ("output/g_star.csv");
	for {p in PATIENT_GROUPS, a in ADMISSION_TYPES: sum {t3 in TIMES, f in FRAILTY: t3 <= 52} (y[t3,p,"G_STAR",a,f]) > 0}{
		printf "%.2f\t", sum {f2 in FRAILTY} y[t,p,"G_STAR",a,f2] >> ("output/g_star.csv"); 
	}
	printf "\n" > ("output/g_star.csv");
}


# CC_denial: hospitalised (y), admissions (z') and transitions (x, x') for G_STAR (only for patient groups for which it happens)

printf "Time\t" >  ("output/CC_denial.csv");
for {p in PATIENT_GROUPS, a in ADMISSION_TYPES: sum {t2 in TIMES, f in FRAILTY: t2 <= 52} (y[t2,p,"G_STAR",a,f] + z_prime[t2,p,"G_STAR",a,f]) > 0}{
		printf "y_GSTAR_%s_%s\t", p,a >> ("output/CC_denial.csv");
		printf "y_C_%s_%s\t", p,a >> ("output/CC_denial.csv");
		printf "z_prime_GSTAR_%s_%s\t", p,a >> ("output/CC_denial.csv");
		printf "z_prime_C_%s_%s\t", p,a >> ("output/CC_denial.csv");
		printf "x_G_GSTAR_%s_%s\t", p,a >> ("output/CC_denial.csv");
		printf "x_G_C_%s_%s\t", p,a >> ("output/CC_denial.csv");
		printf "x_GSTAR_GSTAR_%s_%s\t", p,a >> ("output/CC_denial.csv");
		printf "x_GSTAR_C_%s_%s\t", p,a >> ("output/CC_denial.csv");
		printf "x_C_GSTAR_%s_%s\t", p,a >> ("output/CC_denial.csv");
		printf "x_C_C_%s_%s\t", p,a >> ("output/CC_denial.csv");
		printf "x_prime_G_GSTAR_%s_%s\t", p,a >> ("output/CC_denial.csv");
		printf "x_prime_G_C_%s_%s\t", p,a >> ("output/CC_denial.csv");
		printf "x_prime_GSTAR_GSTAR_%s_%s\t", p,a >> ("output/CC_denial.csv");
		printf "x_prime_GSTAR_C_%s_%s\t", p,a >> ("output/CC_denial.csv");
		printf "x_prime_C_GSTAR_%s_%s\t", p,a >> ("output/CC_denial.csv");
		printf "x_prime_C_C_%s_%s\t", p,a >> ("output/CC_denial.csv");
	}
printf "\n" > ("output/CC_denial.csv");
for {t in TIMES}{
	printf "%.0f\t", t >> ("output/CC_denial.csv");
	for {p in PATIENT_GROUPS, a in ADMISSION_TYPES: sum {t3 in TIMES, f3 in FRAILTY: t3 <= 52} (y[t3,p,"G_STAR",a,f3] + z_prime[t3,p,"G_STAR",a,f3]) > 0}{
			printf "%.2f\t%.2f\t%.2f\t%.2f\t%.2f\t%.2f\t%.2f\t%.2f\t%.2f\t%.2f\t%.2f\t%.2f\t%.2f\t%.2f\t%.2f\t%.2f\t", sum {f in FRAILTY} y[t,p,"G_STAR",a,f], sum {f in FRAILTY} y[t,p,"C",a,f], sum {f in FRAILTY} z_prime[t,p,"G_STAR",a,f], sum {f in FRAILTY} z_prime[t,p,"C",a,f], sum {f in FRAILTY} x[t, p,"G","G_STAR",a,f], sum {f in FRAILTY} x[t,p,"G","C",a,f], sum {f in FRAILTY} x[t, p,"G_STAR","G_STAR",a,f], sum {f in FRAILTY} x[t, p,"G_STAR","C",a,f], sum {f in FRAILTY} x[t, p,"C","G_STAR",a,f], sum {f in FRAILTY} x[t, p,"C","C",a,f], sum {f in FRAILTY} x_prime[t, p,"G","G_STAR",a,f], sum {f in FRAILTY} x_prime[t,p,"G","C",a,f], sum {f in FRAILTY} x_prime[t, p,"G_STAR","G_STAR",a,f], sum {f in FRAILTY} x_prime[t, p,"G_STAR","C",a,f], sum {f in FRAILTY} x_prime[t, p,"C","G_STAR",a,f], sum {f in FRAILTY} x_prime[t, p,"C","C",a,f] >> ("output/CC_denial.csv");
		}
	printf "\n" > ("output/CC_denial.csv");
}


# inf_waiting.csv: infinitely waiting elective patients. Plot only if sum_t > 0

printf "Time\t" >  ("output/inf_waiting.csv");
for {p in PATIENT_GROUPS: sum {t2 in TIMES, f in FRAILTY: t2 <= 52} z[t2,p,"N",f] <= 0}{
		printf "z_%s\tW_%s\t", p,p >> ("output/inf_waiting.csv");
	}
printf "\n" > ("output/inf_waiting.csv");
for {t in TIMES}{
	printf "%.0f\t", t >> ("output/inf_waiting.csv");
	for {p in PATIENT_GROUPS: sum {t3 in TIMES, f in FRAILTY: t3 <= 52} z[t3,p,"N",f] <= 0}{
		printf "%.2f\t%.2f\t", sum {f2 in FRAILTY} z[t,p,"N",f2], sum {f3 in FRAILTY} w[t,p,f3] >> ("output/inf_waiting.csv");
	}
	printf "\n" > ("output/inf_waiting.csv");
}


# CYM.csv: cost, YLL, mortality per patient group (assuming that all admission denials die, including week 0)

printf "Patient_Group\tCost\tYLL\tDead" > ("output/CYM.csv");
printf "\n" > ("output/CYM.csv");
for {p in PATIENT_GROUPS}{
	printf "%s\t", p >> ("output/CYM.csv");
	printf "%.2f\t", sum {t in TIMES, a in ADMISSION_TYPES, f in FRAILTY: t <= 51} cost [p,a] * z[t,p,a,f] >> ("output/CYM.csv");
	printf "%.2f\t", sum {t in TIMES, a in ADMISSION_TYPES, f in FRAILTY: t <= 51} (lambda [p] * z_prime [t,p,"D",a,f]) + sum {t2 in TIMES, a2 in ADMISSION_TYPES, f2 in FRAILTY: t2 <= 52} (lambda [p] * y [t2,p,"D",a2,f2]) >> ("output/CYM.csv");
	printf "%.2f\t", sum {t in TIMES, a in ADMISSION_TYPES, f in FRAILTY: t <= 51} (z_prime [t,p,"D",a,f]) + sum {t2 in TIMES, a2 in ADMISSION_TYPES, f2 in FRAILTY: t2 <= 52} (y [t2,p,"D",a2,f2]) >> ("output/CYM.csv");
	printf "\n" > ("output/CYM.csv");
}


# CYM_2.csv: cost, YLL, mortality per patient group (assuming that admission denials in week 0 do not die)

printf "Patient_Group\tCost\tYLL\tDead" > ("output/CYM_2.csv");
printf "\n" > ("output/CYM_2.csv");
for {p in PATIENT_GROUPS}{
	printf "%s\t", p >> ("output/CYM_2.csv");
	printf "%.2f\t", sum {t in TIMES, a in ADMISSION_TYPES, f in FRAILTY: t <= 51} cost [p,a] * z[t,p,a,f] >> ("output/CYM_2.csv");
	printf "%.2f\t", sum {t in TIMES, a in ADMISSION_TYPES, f in FRAILTY: t > 0 && t <= 51} (lambda [p] * z_prime [t,p,"D",a,f]) + sum {t2 in TIMES, a2 in ADMISSION_TYPES, f2 in FRAILTY: t2 <= 52} (lambda [p] * y [t2,p,"D",a2,f2]) >> ("output/CYM_2.csv");
	printf "%.2f\t", sum {t in TIMES, a in ADMISSION_TYPES, f in FRAILTY: t > 0 && t <= 51} (z_prime [t,p,"D",a,f]) + sum {t2 in TIMES, a2 in ADMISSION_TYPES, f2 in FRAILTY: t2 <= 52} (y [t2,p,"D",a2,f2]) >> ("output/CYM_2.csv");
	printf "\n" > ("output/CYM_2.csv");
}


# CYM_A.csv: cost, YLL, mortality per patient group (Assuming that emergencies denied care die with the same YLL/admission (of emergency patients, calculated based on scenario O1) of the admitted patients of the same category and age group - lambda2 parameter. Accounting also for the cost of these admissions. Week 0 patients are excluded.)

printf "Patient_Group\tCost\tYLL" > ("output/CYM_A.csv");
printf "\n" > ("output/CYM_A.csv");
for {p in PATIENT_GROUPS}{
	printf "%s\t", p >> ("output/CYM_A.csv");
	printf "%.2f\t", sum {t in TIMES, a in ADMISSION_TYPES, f in FRAILTY: t > 0 && t <= 51} (cost [p,a] * z_prime [t,p,"D",a,f]) + sum {t2 in TIMES, a2 in ADMISSION_TYPES, f2 in FRAILTY: t2 <= 51} (cost [p,a2] * z[t2,p,a2,f2]) >> ("output/CYM_A.csv");
	printf "%.2f\t", sum {t in TIMES, a in ADMISSION_TYPES, f in FRAILTY: t > 0 && t <= 51} (lambda2 [p] * z_prime [t,p,"D",a,f]) + sum {t2 in TIMES, a2 in ADMISSION_TYPES, f2 in FRAILTY: t2 <= 52} (lambda [p] * y [t2,p,"D",a2,f2]) >> ("output/CYM_A.csv");
	printf "\n" > ("output/CYM_A.csv");
}


# CYM_3.csv: cost, YLL, mortality per patient group (assuming that all admission denials do not die)

printf "Patient_Group\tCost\tYLL\tDead" > ("output/CYM_3.csv");
printf "\n" > ("output/CYM_3.csv");
for {p in PATIENT_GROUPS}{
	printf "%s\t", p >> ("output/CYM_3.csv");
	printf "%.2f\t", sum {t in TIMES, a in ADMISSION_TYPES, f in FRAILTY: t <= 51} cost [p,a] * z[t,p,a,f] >> ("output/CYM_3.csv");
	printf "%.2f\t", sum {t2 in TIMES, a2 in ADMISSION_TYPES, f2 in FRAILTY: t2 <= 52} (lambda [p] * y [t2,p,"D",a2,f2]) >> ("output/CYM_3.csv");
	printf "%.2f\t", sum {t2 in TIMES, a2 in ADMISSION_TYPES, f2 in FRAILTY: t2 <= 52} (y [t2,p,"D",a2,f2]) >> ("output/CYM_3.csv");
	printf "\n" > ("output/CYM_3.csv");
}


# YLL.csv: YLL per time per patient group (need to differentiate t=52 as in the CYM output)

printf "Time\t" >  ("output/YLL.csv");
for {p in PATIENT_GROUPS}{
		printf "%s\t", p >> ("output/YLL.csv");
	}
printf "\n" > ("output/YLL.csv");
for {t in TIMES: t <= 51}{
	printf "%.0f\t", t >> ("output/YLL.csv");
	for {p in PATIENT_GROUPS}{
		printf "%.2f\t", sum {a in ADMISSION_TYPES, f in FRAILTY} (lambda [p] * (z_prime [t,p,"D",a,f] + y [t,p,"D",a,f])) >> ("output/YLL.csv");
	}
	printf "\n" > ("output/YLL.csv");
}
for {t in TIMES: t == 52}{
	printf "%.0f\t", t >> ("output/YLL.csv");
	for {p in PATIENT_GROUPS}{
		printf "%.2f\t", sum {a in ADMISSION_TYPES, f in FRAILTY} (lambda [p] * y [t,p,"D",a,f])  >> ("output/YLL.csv");
	}
	printf "\n" > ("output/YLL.csv");
}


# W.csv: waiting per patient group across time
printf "Time\t" >  ("output/W.csv");
for {p in PATIENT_GROUPS}{
		printf "%s\t",p >> ("output/W.csv");
	}
printf "\n" > ("output/W.csv");
for {t in TIMES}{
	printf "%.0f\t", t >> ("output/W.csv");
	for {p in PATIENT_GROUPS}{
		printf "%.2f\t", sum {f in FRAILTY} w [t, p, f] >> ("output/W.csv");
	}
	printf "\n" > ("output/W.csv");
}


# Z_N.csv: admitted electives per patient group across time
printf "Time\t" >  ("output/Z_N.csv");
for {p in PATIENT_GROUPS}{
		printf "%s\t",p >> ("output/Z_N.csv");
	}
printf "\n" > ("output/Z_N.csv");
for {t in TIMES}{
	printf "%.0f\t", t >> ("output/Z_N.csv");
	for {p in PATIENT_GROUPS}{
		printf "%.2f\t", sum {f in FRAILTY} z [t, p, "N", f] >> ("output/Z_N.csv");
	}
	printf "\n" > ("output/Z_N.csv");
}


# Z_E.csv: admitted emergencies per patient group across time
printf "Time\t" >  ("output/Z_E.csv");
for {p in PATIENT_GROUPS}{
		printf "%s\t",p >> ("output/Z_E.csv");
	}
printf "\n" > ("output/Z_E.csv");
for {t in TIMES}{
	printf "%.0f\t", t >> ("output/Z_E.csv");
	for {p in PATIENT_GROUPS}{
		printf "%.2f\t",  sum {f in FRAILTY} z [t, p, "E", f] >> ("output/Z_E.csv");
	}
	printf "\n" > ("output/Z_E.csv");
}


# admission_denial.csv: Values of z_prime_D variable (indicating extra capacity needed in G&A)

printf "Time\t" > "output/admission_denial.csv";
for {p in PATIENT_GROUPS: sum {t2 in TIMES, a2 in ADMISSION_TYPES, f2 in FRAILTY: t2 <= 52} z_prime [t2,p,"D",a2,f2] > 0}{
		printf "z_prime_D_%s\t", p >> "output/admission_denial.csv";
	}
printf "\n" > "output/admission_denial.csv";

for {t in TIMES}{
	printf "%.0f\t", t >> "output/admission_denial.csv";
	for {p in PATIENT_GROUPS: sum {t2 in TIMES, a2 in ADMISSION_TYPES, f2 in FRAILTY: t2 <= 52} z_prime [t2,p,"D",a2, f2] > 0}{
		printf "%.2f\t", sum {a in ADMISSION_TYPES, f in FRAILTY} z_prime [t,p,"D",a, f] >> "output/admission_denial.csv";
	}	
	printf "\n" >> "output/admission_denial.csv";
}

# admissions in CC/GA for electives
printf "Time\t" > ("output/admitted_p_1" & ".csv");
for {p in PATIENT_GROUPS}{
    printf "%s\t", p >> ("output/admitted_p_2"& ".csv");
}
    printf "\n" >("output/admitted_p_1"& ".csv");
    for {t in TIMES}{
        printf "%.0f\t", t >> ("output/admitted_p_1"& ".csv");
        for {p in PATIENT_GROUPS}{
            printf "%.2f\t", sum {f in FRAILTY} z_prime [t,p,"C","N",f] >> ("output/admitted_p_1"& ".csv");
        }
        printf "\n" >> ("output/admitted_p_1"& ".csv");
    }