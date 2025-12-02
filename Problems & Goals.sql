
-------  SECTION 1: PATIENTS & CONDITION ANALYSIS 

------------------------------------------------
-- Question 1: WHAT IS THE MOST COMMON DISEASES?
------------------------------------------------

 -- PROBLEM STATEMENT:
	--  Identify the most common diseases among patients to prioritize
	--  healthcare interventions and understand disease burden.

 -- GOAL:
    -- To determine which diseases affect the most patients,
    -- helping to guide decision-making for healthcare planning, prevention strategies, and resource distribution.

-- Frequency count of each disease
SELECT 
    Medical_Condition, 
    COUNT(*) AS Total_Common_Diseases
FROM PatientsData_healthecare_clean
GROUP BY Medical_Condition
ORDER BY Total_Common_Diseases DESC;
 

-------------------------------------------------------------------------
-- Question 2: WHAT IS THE IMPACT OF DISEASE ACROSS DIFFERENT AGE GROUPS?
-------------------------------------------------------------------------

 -- PROBLEM STATEMENT:
	 -- Determine which age groups are most affected by each medical condition
	 -- to improve disease prevention and age-targeted treatment strategies.

 -- GOAL:
    -- Relationship between age and medical conditions in order to identify the most affected age groups 
    -- and support the development of targeted prevention and treatment strategies.

-- Add a new column for age grouping
ALTER TABLE Patients_healthecare_clean
ADD Age_Group VARCHAR(10);

-- Assign age group categories based on patient age
UPDATE Patients_healthecare_clean
SET Age_Group = CASE 
        WHEN Age BETWEEN 13 AND 17 THEN '13-17'
        WHEN Age BETWEEN 18 AND 35 THEN '18-35'
        WHEN Age BETWEEN 36 AND 55 THEN '36-55'
        WHEN Age BETWEEN 56 AND 75 THEN '56-75'
        WHEN Age BETWEEN 76 AND 80 THEN '76-80'
        ELSE '80+'
    END;

-- Verify age group assignments
SELECT DISTINCT Age, Age_Group
FROM Patients_healthecare_clean
ORDER BY Age;


-- Determine which age groups are most affected by each disease
WITH AgeDiseaseCounts AS (
    SELECT 
        PD.Medical_Condition,           -- Disease name
        P.Age_Group,                    -- Age group of patient
        COUNT(*) AS patient_count,      -- Number of patients in this age group
        DENSE_RANK() OVER (             -- Window function: It assigns a ranking (rn) within each disease, ordering the age groups by number of patients in descending order.
            PARTITION BY PD.Medical_Condition
            ORDER BY COUNT(*) DESC
        ) AS rn                         -- age group for each disease = largest number of patients in that disease’s category.
    FROM Patients_healthecare_clean P
    JOIN PatientsData_healthecare_clean PD
        ON P.P_ID = PD.P_ID
    GROUP BY PD.Medical_Condition, P.Age_Group
)
SELECT 
    Medical_Condition, 
    Age_Group AS Most_Affected_Age_Group, 
    patient_count
FROM AgeDiseaseCounts
WHERE rn = 1                             -- The age group with the most patients for a disease gets rn = 1
ORDER BY Medical_Condition;              -- The next most affected age group gets rn = 2


-------------------------------------------------------------------------------------
-- Question 3: HOW ARE DIFFERENT DISEASES DISTRIBUTED BETWEEN MALE & FEMALE PATIENTS? 
-------------------------------------------------------------------------------------

 -- PROBLEM STATEMENT:
    -- Assess whether certain diseases disproportionately affect males or females.

 -- GOAL:
    -- Disease patterns by gender to identify whether certain conditions affect males or females more


SELECT 
    PD.Medical_Condition, 
    P.Gender,
    COUNT(*) AS Patient_Count
FROM Patients_healthecare_clean P
JOIN PatientsData_healthecare_clean PD
    ON P.P_ID = PD.P_ID
GROUP BY PD.Medical_Condition, P.Gender
ORDER BY PD.Medical_Condition, Patient_Count DESC;


-----------------------------------------------------------------
-- Question 4: HOW DO TEST RESULTS VARY BY DISEASE OR MEDICATION?
-----------------------------------------------------------------
    
    -- PROBLEM STATEMENT:
       -- Determine how patients lab test results (Normal, Abnormal, Inconclusive) 
       -- vary by medical condition and medication to identify patterns.

    -- GOAL:
       -- Monitor treatments and test outcomes to improve patient care, 
       -- medication effectiveness, and early treatment for abnormal results.

-- Aggregate test results per disease       -- VARY BY DISEASE
SELECT 
    Medical_Condition,
    Test_Results,
    COUNT(*) AS Result_Count
FROM PatientsData_healthecare_clean
GROUP BY Medical_Condition, Test_Results
ORDER BY Medical_Condition, Result_Count DESC;

-- Aggregate test results per medication    -- VARY BY MEDICATION
SELECT 
    Medication,
    Test_Results,
    COUNT(*) AS Result_Count
FROM PatientsData_healthecare_clean
GROUP BY Medication, Test_Results
ORDER BY Medication, Result_Count DESC;

---------------------------------------------------------------------------

---------------------
-- ADD SEASON COLUMN
---------------------

ALTER TABLE PatientsData_healthecare_clean
ADD Season VARCHAR(10);

UPDATE PatientsData_healthecare_clean
SET Season = CASE
				WHEN MONTH(Date_of_Admission) IN (12, 1, 2) THEN 'Winter' 
				WHEN MONTH(Date_of_Admission) IN (3, 4, 5) THEN 'Spring' 
				WHEN MONTH(Date_of_Admission) IN (6, 7, 8) THEN 'Summer' 
				WHEN MONTH(Date_of_Admission) IN (9, 10, 11) THEN 'Fall'
END;
---------------------------------------------------------------------------


------- SECTION 2: Hospital & Doctor inisghts

----------------------------------------------------------------
-- Question 5: WHICH HOSPITALS HAVE THE HIGHEST PATIENTS INTAKE?
----------------------------------------------------------------
  
  -- PROBLEM STATEMENT:
       -- Identify which hospitals have the highest number of patients.
       -- Understanding patient distribution helps hospitals manage resources efficiently.

   -- GOAL:
      -- Allocate hospital resources, optimize staffing, and plan healthcare services efficiently at high-volume hospitals.
      -- To determine which hospitals receive the most patients, enabling better resource management and efficient hospital planning.

SELECT P.H_ID, H.Hospital, COUNT(P.P_ID) AS PatientCount  
FROM PatientsData_healthecare_clean P 
JOIN Hospital_healthecare_clean H
ON H.H_id = P.H_ID
GROUP BY P.H_ID, H.Hospital
HAVING COUNT(P_ID) > 1
ORDER BY PatientCount DESC;  


--------------------------------------------------------------------------------
-- Question 6: WHAT IS THE AVERAGE BILLING AMOUNT FOR PATIENTS AT EACH HOSPITAL? 
--------------------------------------------------------------------------------

 -- Problem Statement:
   -- Determine the average billing amount for patients at each hospital to understand cost patterns 
   -- and financial workload across healthcare facilities.

 -- Goal:
    -- Find the average patient charges, helping hospitals manage finances, 
    -- plan budgets, and identify areas for cost optimization.

SELECT P.H_ID,H.Hospital,ROUND(AVG(P.Billing_Amount),2) AS AVG_Billing_Amount
FROM PatientsData_healthecare_clean P 
JOIN Hospital_healthecare_clean H
ON P.H_ID = H.H_id
GROUP BY P.H_ID,H.Hospital


--------------------------------------------------------------------------------------------------
-- Question 7: HOW DOES A DOCTOR'S PERFORMANCE VARY BASED ON PATIENT VOLUME OR TREATMENT OUTCOMES?
--------------------------------------------------------------------------------------------------
  -- Problem Statement:
     -- The objective is to assess each doctor's performance by analyzing their patient volume 
     -- and corresponding treatment outcomes based on test results. 

  -- Goal:
     -- To calculate a consistent, numeric success rate for every doctor by quantifying 
     -- their treatment outcomes and patient volume.
WITH DoctorPerformance AS (
    SELECT 
        D_ID,
        COUNT(DISTINCT P_ID) AS Total_patients,          -- Count how many unique patients each doctor treated
        SUM(CASE WHEN Test_Results = 'Normal' THEN 1 ELSE 0 END) AS Normal_results,        
        SUM(CASE WHEN Test_Results = 'Abnormal' THEN 1 ELSE 0 END) AS Abnormal_results,     
        SUM(CASE WHEN Test_Results = 'Inconclusive' THEN 1 ELSE 0 END) AS Inconclusive_results,
      
        AVG(DATEDIFF(day, [Date_of_Admission], [Discharge_Date])) AS AVG_Treatment_Days      -- Calculate the average treatment duration
    FROM PatientsData_healthecare_clean
    GROUP BY D_ID    -- Grouping by doctor ensures we calculate per doctor
)
-- CASE: Count how many of the doctor's patients had each type of test result
-- CASE: Each CASE checks the Test_Results column and adds 1 if the condition matches, else adds 0.
SELECT 
    D_ID,
    Total_patients,         -- Number of patients treated
    Normal_results,         -- Patients with normal (successful) outcomes
    Abnormal_results,       -- Patients with abnormal test results
    Inconclusive_results,   -- Patients whose results were inconclusive
 
    CAST(100.0 * Normal_results / NULLIF(Total_patients, 0) AS DECIMAL(5,2)) AS Normal_result_rate_percentage,
                                     -- Calculate the percentage of patients who had normal (successful) test results.
                                     -- NULLIF prevents division by zero in case a doctor has zero patients.
    AVG_Treatment_Days               -- Average number of treatment days per doctor (from the CTE)
FROM DoctorPerformance
ORDER BY Normal_result_rate_percentage DESC, Total_patients DESC;   -- Sort doctors so the best performers (highest success rate) appear first.
-- If two doctors have the same success rate, the one with more patients comes first.



--------------------------------------------------------------------------------
-- Question 8: WHICH MEDICAL CONDITIONS DOES EACH DOCTOR TREAT MOST FREQUENTLY?
--------------------------------------------------------------------------------

 -- Problem Statement:
    -- Determine which medical conditions are most commonly treated by each doctor 
    -- to understand their areas of expertise and patient care focus.

 -- Goal:
    -- To identify the most frequently treated medical conditions for each doctor, 
    -- helping hospitals recognize doctor specializations, and improve healthcare delivery.

SELECT D.Doctor, Medical_Condition, COUNT(P_ID) AS PatientCount
FROM PatientsData_healthecare_clean P
JOIN Doctor_healthecare_clean D
ON P.D_ID = D.D_ID
GROUP BY D.Doctor, Medical_Condition
HAVING COUNT(P_ID) > 1
ORDER BY PatientCount DESC;


--------------------------------------------------------------------------------
-- Question 9: WHAT IS THE COMMON ADMISSION TYPE PER HOSPITAL?
--------------------------------------------------------------------------------
  -- Problem Statement:
     -- Determine the most frequent admission type for each hospital to understand 
     -- patient flow patterns and hospital service utilization. 
     -- This can help in identifying which admission types are most common per hospital 
     -- and guide resource allocation, staffing, and operational planning.

  -- Goal:
     -- To identify the top admission type per hospital based on historical data,
     -- allowing hospital administrators to prioritize resources, 
     -- optimize scheduling, and plan for seasonal or recurring trends in admissions.

SELECT H_ID, Admission_Type, admission_count
FROM (
    SELECT 
        H_ID,
        Admission_Type,
        COUNT(*) AS admission_count,    -- counts how many admissions of that type occurred at the hospital
        ROW_NUMBER() OVER (
            PARTITION BY H_ID           -- Start a new ranking for each hospital
            ORDER BY COUNT(*) DESC      -- Rank by number of admissions, descending
        ) AS rn
    FROM PatientsData_healthecare_clean
    GROUP BY H_ID, Admission_Type     -- Aggregate by hospital and admission type
) AS ranked
WHERE rn = 1;                         -- Only pick the top admission type per hospital



------- SECTION 3: Financial & Insurance Analysis

---------------------------------------------------------------
-- Question 10: WHAT IS THE AVERAGE TREATMENT COST PER DISEASE?
---------------------------------------------------------------

  -- Problem Statement:
     -- Determine the average treatment cost associated with each disease 
     -- to analyze cost variations and identify which medical conditions 
     -- require higher financial resources for patient care.

  -- Goal:
     -- To calculate and compare the average treatment cost per disease, 
     -- helping hospitals optimize budgeting, evaluate cost-effectiveness, 
     -- and improve financial planning for different medical conditions.


SELECT Medical_Condition, ROUND(AVG(Billing_Amount),2) AS AVG_Billing_Amount
FROM PatientsData_healthecare_clean 
GROUP BY Medical_Condition


------------------------------------------------------------------------------------------------------------------------
-- Question 11: HOW DO INSURANCE PROVIDERS COMPARE IN TERMS OF THE NUMBER OF PATIENTS THEY COVER & TOTAL TREATMENT COST?
------------------------------------------------------------------------------------------------------------------------

 -- Problem Statement:
    -- Compare insurance providers based on the number of patients covered 
    -- and the total and average treatment costs billed.

 -- Goal:
    -- To identify the most utilized and cost-effective insurance providers, 
    -- helping assess provider performance and cost distribution.


SELECT 
    Insurance_Provider,                              -- Name of the insurance provider
    COUNT(P_ID) AS No_Of_Patients,                   -- Total number of patients covered by each provider
    ROUND(SUM(Billing_Amount),2) AS Total_Billing    -- Total cost billed under each insurance provider
FROM PatientsData_healthecare_clean
GROUP BY Insurance_Provider;  


---------------------------------------------------------------------------------------------------
-- Update the Billing_Amount column to be positive
SELECT Billing_Amount
FROM PatientsData_healthecare_clean
WHERE Billing_Amount < 0;

BEGIN TRANSACTION

UPDATE PatientsData_healthecare_clean
SET Billing_Amount = ABS(Billing_Amount);

COMMIT TRANSACTION
---------------------------------------------------------------------------------------------------


------------------------------------------------------------------------
-- Question 12: WHAT ARE TOTAL HOSPITAL BILLING AMOUNS PER MONTH & YEAR?
------------------------------------------------------------------------

  -- Problem Statement:
     -- Determine the total hospital billing amounts per month and per year 
     -- to understand how spending changes over time and identify trends in hospital revenue.

  -- Goal:
     -- To track monthly and yearly billing totals, monitor spending patterns, 
     -- and provide insights for financial planning, budgeting, and resource allocation.


-- Total hospital billing amounts per Month
SELECT           
    MONTH(Date_of_Admission) AS Month,                -- Month of admission
    ROUND(SUM(Billing_Amount),2) AS Total_Billing,    -- Total billing for that month
    COUNT(*) AS Patient_Count                         -- Number of admissions in that month
FROM PatientsData_healthecare_clean
GROUP BY MONTH(Date_of_Admission)
ORDER BY Total_Billing DESC;                                      


-- Total hospital billing amounts per year
SELECT 
    YEAR(Date_of_Admission) AS Year,                  -- Year of admission
    ROUND(SUM(Billing_Amount),2) AS Total_Billing,             -- Total billing for that year
    COUNT(*) AS Patient_Count                         -- Number of admissions in that year
FROM PatientsData_healthecare_clean
GROUP BY YEAR(Date_of_Admission)
ORDER BY Total_Billing DESC;                                             



------- SECTION 4: Administrative Patterns

-----------------------------------------------------------------------
-- Question 13: year-over-year change in case volume
-----------------------------------------------------------------------
 
 -- Problem Statement:
     -- Analyze how the number of patient admissions changes from year to year 
     -- Determine whether admissions are increasing, decreasing, or stable over time.

  -- Goal:
     -- To calculate year-over-year (YoY) changes in admissions both in absolute 
     -- numbers and percentages, providing insights for hospital planning, and resource allocation.

WITH YearlyAdmissions AS (
    -- Step 1: Count total admissions per year
    SELECT 
        YEAR(Date_of_Admission) AS Admission_Year,  	-- Extract year from admission date
        COUNT(*) AS Total_Admissions               		-- Total admissions in that year
    FROM PatientsData_healthecare_clean
    GROUP BY YEAR(Date_of_Admission)
)

SELECT
    Admission_Year,
    Total_Admissions,
    
    -- Step 2: Get the previous year's admissions using LAG()
    -- LAG(column) returns the value of 'column' from the previous row based on ORDER BY
    -- ISNULL(..., 0) replaces NULL (for the first year) with 0
    ISNULL(LAG(Total_Admissions) OVER (ORDER BY Admission_Year), 0) AS Prev_Year_Admissions,  
   
   -- Step 3: Calculate YoY change (Current year - Previous year)
    Total_Admissions - ISNULL(LAG(Total_Admissions) OVER (ORDER BY Admission_Year), 0) AS YoY_Change,  
  
    -- Step 4: Calculate YoY percent change ((Current year - previous yaer) * 100 / previous year)
    -- CAST as DECIMAL(5,2)
  CAST(
        CASE 
            WHEN ISNULL(LAG(Total_Admissions) OVER (ORDER BY Admission_Year), 0) = 0 THEN 0
            ELSE (Total_Admissions - LAG(Total_Admissions) OVER (ORDER BY Admission_Year)) 
                 * 100.0 / CAST(LAG(Total_Admissions) OVER (ORDER BY Admission_Year) AS DECIMAL(10,2))
        END AS DECIMAL(5,2)
    ) AS YoY_Percent_Change
FROM YearlyAdmissions
ORDER BY Admission_Year;




