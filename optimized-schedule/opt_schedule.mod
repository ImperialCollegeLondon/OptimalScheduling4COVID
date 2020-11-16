# -------------------------------------------------------------------------------------------------------------------------	
#	OR4COVID
#	Model file
# -------------------------------------------------------------------------------------------------------------------------		


###############
###  SETS  ####
###############

param T; # number of time periods (weeks) 
set TIMES ordered := 0 .. T; # Assumptions: 1) t refers to beginning of week t = end of week t-1; 2) New inflows and admission decisions are taken in the middle of each week
set RESOURCES;
set PATIENT_GROUPS; # code: ICD##_AGE# (e.g. ICD02_AGE3)
set ADMISSION_TYPES; # elective (N) or emergency (E)
set SEVERITY_STATES; # Recovered (H), G&A (G), G&A if denied CC (G_STAR), Critical/ICU (C), Dead (D)
set BUNDLE_51_PATIENT_GROUPS_AGE1; # Ps belonging only to emergency bundle ICD_51_AGE1
set BUNDLE_51_PATIENT_GROUPS_AGE2; # Ps belonging only to emergency bundle ICD_51_AGE2
set BUNDLE_51_PATIENT_GROUPS_AGE3; # Ps belonging only to emergency bundle ICD_51_AGE3
set BUNDLE_50_PATIENT_GROUPS_AGE1; # Ps belonging only to elective bundle ICD_50_AGE1
set BUNDLE_50_PATIENT_GROUPS_AGE2; # Ps belonging only to elective bundle ICD_50_AGE2
set BUNDLE_50_PATIENT_GROUPS_AGE3; # Ps belonging only to elective bundle ICD_50_AGE3


####################
###  PARAMETERS  ###
####################
param phi {TIMES, PATIENT_GROUPS, ADMISSION_TYPES} default 0; # New patients inflows during week t
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
param theta {TIMES, PATIENT_GROUPS} default 0; # Proportion of people transferring out of ICD_50 into ICD_1,4,5,15 at time t;
param cost {PATIENT_GROUPS, ADMISSION_TYPES} default 0; # average cost per patient group. Cost is 0 if no inflow for that group

# Parameters to initialize model
param w0 {PATIENT_GROUPS} default 0; # (remove default 0?) Patients waiting at the beginning of the planning horizon
param y0 {PATIENT_GROUPS, SEVERITY_STATES, ADMISSION_TYPES} default 0; # Patients already hosptialized at the beginning of the planning horizon (0 for H, D and G_STAR)


###################
###  VARIABLES  ###
###################
var w {TIMES, PATIENT_GROUPS} >= 0; # Total waiting patients at the beginning of week t
var z {TIMES, PATIENT_GROUPS, ADMISSION_TYPES} >= 0; # patients admitted to hospital in week t
var z_prime {TIMES, PATIENT_GROUPS, SEVERITY_STATES, ADMISSION_TYPES} >= 0; # patients admitted to G, G_STAR, C, D in week t
var x {TIMES, PATIENT_GROUPS, SEVERITY_STATES, SEVERITY_STATES, ADMISSION_TYPES} >= 0;  # transfers across severity states for hospitalised patients (weekly transitions)
var x_prime {TIMES, PATIENT_GROUPS, SEVERITY_STATES, SEVERITY_STATES, ADMISSION_TYPES} >= 0;  # transfers across severity states for hospitalised patients (first 3.5 days)
var y {TIMES, PATIENT_GROUPS, SEVERITY_STATES, ADMISSION_TYPES} >= 0; # Total number of patients for each severity state at the beginning of week t
var YearsofLifeLost >= 0; # Years of Life Lost
var TotalCost >= 0; # Calculation of total cost

# Slack variables
var slack {TIMES, RESOURCES} >= 0;
var TotalSlack >= 0;


#####################
###  CONSTRAINTS  ###
#####################

subject to initialize_w {p in PATIENT_GROUPS}:
	w [0,p] = w0 [p];

subject to initialize_y {p in PATIENT_GROUPS, s in SEVERITY_STATES, a in ADMISSION_TYPES}:
	y [0,p,s,a] = y0 [p,s,a];

 subject to yll:
	YearsofLifeLost = sum {t in TIMES, p in PATIENT_GROUPS, a in ADMISSION_TYPES} (lambda [p] * (y [t,p,"D",a] + z_prime [t,p,"D",a]));

subject to totalcost:
	TotalCost = sum {t in TIMES, p in PATIENT_GROUPS, a in ADMISSION_TYPES} (cost [p,a] * z [t,p,a]);

subject to total_slack:
	TotalSlack = sum {t in TIMES, r in RESOURCES} slack [t,r];
	
subject to waiting_patients {t in TIMES, p in PATIENT_GROUPS: t <> T}:
	w [next(t), p] = phi [t,p,"N"] + w[t,p] * (1 - pi_w[p]) - z[t,p,"N"];
	
subject to admitted_emergencies {t in TIMES, p in PATIENT_GROUPS diff {"ICD51_AGE1", "ICD51_AGE2", "ICD51_AGE3", "BUNDLE_50_PATIENT_GROUPS_AGE1", "BUNDLE_50_PATIENT_GROUPS_AGE2", "BUNDLE_50_PATIENT_GROUPS_AGE3"}}:
	z [t,p,"E"] + z_prime [t,p,"D","E"] = phi [t,p,"E"] + w[t,p] * pi_w[p];
	
# Some patients might be denied CC upon admission. In this case, they are admitted to G*
subject to admission_cc {t in TIMES, p in PATIENT_GROUPS, a in ADMISSION_TYPES}:
	z_prime [t,p,"C",a] + z_prime [t,p,"G_STAR",a] = z [t,p,a] * pi_z [t,p,"C",a];
	
# All patients needing G&A are admitted to G&A. If denied, we assume they die
subject to admission_ga {t in TIMES, p in PATIENT_GROUPS, a in ADMISSION_TYPES}:
	z_prime [t,p,"G",a] = z [t,p,a] * pi_z [t,p,"G",a];

subject to hospitalized_patients {t in TIMES, p in PATIENT_GROUPS, s in SEVERITY_STATES, a in ADMISSION_TYPES: t <> T}:
	y [next(t),p,s,a] = sum {s1 in SEVERITY_STATES diff {"H", "D"}} (x [t,p,s1,s,a] + x_prime [t,p,s1,s,a]);

# Transitions (first 3.5 days) for all patients excluding admission to CC and G_STAR
subject to hospital_transitions_1_halfweek {t in TIMES, p in PATIENT_GROUPS, s1 in SEVERITY_STATES, s in SEVERITY_STATES, a in ADMISSION_TYPES: t <> T && s1 in {"G", "G_STAR","C"} && s in {"G", "H", "D"}}:
	x_prime [t,p,s1,s,a] = pi_0 [p,s1,s,a] * z_prime [t,p,s1,a];

# Transition (first 3.5 days) from CC to G_STAR: patients might need to leave CC when overflowing capacity
subject to hospital_transitions_2_halfweek {t in TIMES, p in PATIENT_GROUPS, a in ADMISSION_TYPES}:
	x_prime [t,p,"C","C",a] + x_prime [t,p,"C","G_STAR",a] = pi_0 [p,"C","C",a] * z_prime [t,p,"C",a];

# Transitions (first 3.5 days) of patients to CC and G_STAR: patients needing CC are admitted if possible; else, they transition to G_STAR
subject to hospital_transitions_3_halfweek {t in TIMES, p in PATIENT_GROUPS, a in ADMISSION_TYPES: t <> T}:
	x_prime [t,p,"G","C",a] + x_prime [t,p,"G","G_STAR",a] = pi_0 [p,"G","C",a] * z_prime [t,p,"G",a];
	
# Transitions (first 3.5 days) of patients to CC and G_STAR: patients in G_STAR transferred to CC if there is capacity; else, they remain in G_STAR
subject to hospital_transitions_4_halfweek {t in TIMES, p in PATIENT_GROUPS, a in ADMISSION_TYPES: t <> T}:
	x_prime [t,p,"G_STAR","C",a] + x_prime [t,p,"G_STAR","G_STAR",a] = pi_0 [p,"G_STAR","C",a] * z_prime [t,p,"G_STAR",a];

# Transitions (weekly) for all patients excluding admission to CC and G_STAR
subject to hospital_transitions_1 {t in TIMES, p in PATIENT_GROUPS, s1 in SEVERITY_STATES, s in SEVERITY_STATES, a in ADMISSION_TYPES: t <> T && s1 in {"G", "G_STAR","C"} && s in {"G", "H", "D"}}:
	x [t,p,s1,s,a] = pi_y [p,s1,s,a] * y[t,p,s1,a];
	
# Transition (weekly) from CC to G_STAR: patients might need to leave CC when overflowing capacity
subject to hospital_transitions_2 {t in TIMES, p in PATIENT_GROUPS, a in ADMISSION_TYPES}:
	x [t,p,"C","C",a] + x [t,p,"C","G_STAR",a] = pi_y [p,"C","C",a] * y[t,p,"C",a];

# Transitions (weekly) of patients to CC and G_STAR: patients needing CC are admitted if possible; else, they transition to G_STAR
subject to hospital_transitions_3 {t in TIMES, p in PATIENT_GROUPS, a in ADMISSION_TYPES: t <> T}:
	x [t,p,"G","C",a] + x [t,p,"G","G_STAR",a] = pi_y [p,"G","C",a] * y[t,p,"G",a];
	
# Transitions (weekly) of patients to CC and G_STAR: patients in G_STAR transferred to CC if there is capacity; else, they remain in G_STAR
subject to hospital_transitions_4 {t in TIMES, p in PATIENT_GROUPS, a in ADMISSION_TYPES: t <> T}:
	x [t,p,"G_STAR","C",a] + x [t,p,"G_STAR","G_STAR",a] = pi_y [p,"G_STAR","C",a] * y[t,p,"G_STAR",a];

# Resource constraints + slack (the first part, with delta_0, accounts for the resource consumption by patients staying in hospital less than 3.5 days)
subject to resource_availability {t in TIMES, r in RESOURCES}:
	sum {s in SEVERITY_STATES diff {"H", "D"}, p in PATIENT_GROUPS, a in ADMISSION_TYPES} (delta_0 [p,s,r,a] * (sum {s1 in {"H", "D"}} x_prime [t,p,s,s1,a]) + 0.5 * delta [s,r] * (sum {s2 in SEVERITY_STATES diff {"H", "D"}} x_prime [t,p,s,s2,a]) + delta [s,r] * y [t,p,s,a])  + slack [t,r] = xi [r] + xi_add [r];

## Bundling (should it be deprecated?)
subject to admitted_emergencies_51_AGE1 {t in TIMES}:
	z [t, "ICD51_AGE1","E"] + z_prime [t,"ICD51_AGE1","D","E"] = phi [t, "ICD51_AGE1","E"] + sum {m in BUNDLE_51_PATIENT_GROUPS_AGE1} (w [t,m] * pi_w [m]) + w[t, "ICD50_AGE1"]* pi_w["ICD50_AGE1"]*theta [t, "ICD50_AGE1"]; 

subject to admitted_emergencies_51_AGE2 {t in TIMES}:
	z [t, "ICD51_AGE2","E"] + z_prime [t,"ICD51_AGE2","D","E"] = phi [t, "ICD51_AGE2", "E"] + sum {m in BUNDLE_51_PATIENT_GROUPS_AGE2} (w [t,m] * pi_w [m]) + w[t, "ICD50_AGE2"]* pi_w["ICD50_AGE2"]*theta [t, "ICD50_AGE2"]; 

subject to admitted_emergencies_51_AGE3 {t in TIMES}:
	z [t, "ICD51_AGE3","E"] + z_prime [t,"ICD51_AGE3","D","E"] = phi [t, "ICD51_AGE3","E"] + sum {m in BUNDLE_51_PATIENT_GROUPS_AGE3} (w [t,m] * pi_w [m]) + w[t, "ICD50_AGE3"]* pi_w["ICD50_AGE3"]*theta [t, "ICD50_AGE3"]; 

subject to admitted_emergencies_50_AGE1 {t in TIMES, p in BUNDLE_50_PATIENT_GROUPS_AGE1}:
	z [t,p,"E"] + z_prime [t,p,"D","E"] = phi [t,p,"E"] + w[t,"ICD50_AGE1"] * pi_w["ICD50_AGE1"] * theta[t, p];

subject to admitted_emergencies_50_AGE2 {t in TIMES, p in BUNDLE_50_PATIENT_GROUPS_AGE2}:
	z [t,p,"E"] + z_prime [t,p,"D","E"] = phi [t,p,"E"] + w[t,"ICD50_AGE2"] * pi_w["ICD50_AGE2"] * theta[t, p];
	
subject to admitted_emergencies_50_AGE3 {t in TIMES, p in BUNDLE_50_PATIENT_GROUPS_AGE3}:
	z [t,p,"E"] + z_prime [t,p,"D","E"] = phi [t,p,"E"] + w[t,"ICD50_AGE3"] * pi_w["ICD50_AGE3"] * theta[t, p];

# Objective
 minimize obj: YearsofLifeLost;