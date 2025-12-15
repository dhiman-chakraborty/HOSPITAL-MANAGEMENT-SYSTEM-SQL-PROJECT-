select * from department;
select * from doctor;
select * from patient;
select * from room;
select * from appointment;
select * from admission;
select * from treatment;
select * from medication;
select * from prescription;
select * from lab_test;
select * from lab_result;
select * from invoice;
select * from invoice_line;
------------------------------------------

--1. Patients count by age group
SELECT 
     CASE
	 WHEN EXTRACT(YEAR FROM AGE(dob)) <=20 THEN '0-20 Yr'
	 WHEN EXTRACT(YEAR FROM AGE(dob)) BETWEEN 21 AND 40 THEN '20-40 Yr' 
	 WHEN EXTRACT(YEAR FROM AGE(dob)) BETWEEN 41 AND 60 THEN '40-60 Yr'
	 ELSE '61+ Yr' END AS age_group,
	 COUNT(*)
FROM patient
GROUP BY age_group
ORDER BY age_group;

--2.Monthly revenue (invoice totals) for last 12 months
SELECT EXTRACT(MONTH FROM invoice_date) AS month_num,
       TO_CHAR(invoice_date,'month') AS month,
       SUM(total_amount) AS revenue
FROM invoice
WHERE invoice_date >= DATE_TRUNC('month',invoice_date) - INTERVAL '12 months'
GROUP BY month,month_num
ORDER BY month_num;

--3.Top 10 doctors by number of appointments in past 6 months
SELECT d.doctor_id,CONCAT(d.first_name,' ',d.last_name) AS name,
       COUNT(a.*) AS no_of_appointments
FROM doctor d
LEFT JOIN appointment a USING (doctor_id) 
GROUP BY d.doctor_id,CONCAT(d.first_name,' ',d.last_name)
ORDER BY no_of_appointments DESC, d.doctor_id ASC
LIMIT 10;

--4.Average length of stay (days) by department (based on admitting doctor’s dept)
SELECT d.dept_id,d.name,
       AVG(COALESCE(a.discharge_date,CURRENT_DATE)-a.admit_date) AS avg_stay
FROM department d
LEFT JOIN doctor dc USING (dept_id)
JOIN admission a USING (doctor_id)
GROUP BY d.dept_id,d.name
ORDER BY 1;

--5.Patients with more than 3 visits (appointments + admissions) in past year
WITH app AS(
SELECT p.patient_id,CONCAT_WS(' ',p.first_name,p.last_name) AS name,
       COUNT(a.*) no_of_appoinments
FROM patient p
LEFT JOIN appointment a USING (patient_id)
WHERE a.appt_datetime >= DATE_TRUNC('year',CURRENT_DATE) - INTERVAL'1 YEAR' AND a.appt_datetime <= DATE_TRUNC('year',CURRENT_DATE)
GROUP BY p.patient_id,CONCAT_WS(' ',p.first_name,p.last_name)
),
add AS(
SELECT p.patient_id,CONCAT_WS(' ',p.first_name,p.last_name) AS name,
       COUNT(ad.*) no_of_admission
FROM patient p
LEFT JOIN admission ad USING (patient_id)
WHERE ad.admit_date >= DATE_TRUNC('year',CURRENT_DATE) - INTERVAL'1 YEAR' AND ad.admit_date <= DATE_TRUNC('year',CURRENT_DATE)
GROUP BY p.patient_id,CONCAT_WS(' ',p.first_name,p.last_name)
)
SELECT p.patient_id,CONCAT_WS(' ',p.first_name,p.last_name) AS name,
        COALESCE(app.no_of_appoinments,0) AS no_of_appointments,
	    COALESCE(add.no_of_admission,0) AS no_of_admissions,
		COALESCE(app.no_of_appoinments,0)+COALESCE(add.no_of_admission,0) AS total_visit
FROM patient p
LEFT JOIN app USING (patient_id)
LEFT JOIN add USING (patient_id)
WHERE COALESCE(app.no_of_appoinments,0)+COALESCE(add.no_of_admission,0)>=3
ORDER BY 1;

--6.Latest appointment for each patient(Upcoming 30 days)
SELECT patient_id, appointment_id, appt_datetime, reason, status
FROM appointment
WHERE appt_datetime >= CURRENT_DATE + INTERVAL '30 DAYS'
ORDER BY appt_datetime;

--7.Monthly count of patients (by registration = earliest appointment/admission date)
WITH app AS (
SELECT TO_CHAR(appt_datetime,'mm-yyyy') AS month_year,
       COUNT(*) AS total_appointments
FROM appointment
GROUP BY 1
),
adm AS (
SELECT TO_CHAR(admit_date,'mm-yyyy') AS month_year,
       COUNT(*) AS total_admissions
FROM admission
GROUP BY 1
)
SELECT app.month_year,
       app.total_appointments + adm.total_admissions AS total_patients
FROM app
JOIN adm USING (month_year)
ORDER BY app.month_year;

--8.Top 20 most common treatments (by description)
SELECT description, COUNT(*) AS patients
FROM treatment
GROUP BY 1
ORDER BY patients DESC;

--9.Total invoice amount and lines per patient (showing patients with largest bills)
WITH bill AS(
SELECT patient_id,
       SUM(total_amount) AS bill_amount
FROM invoice
GROUP BY 1
),
inl AS(
SELECT i.patient_id,
       COUNT(il.*) AS no_of_invoice_line
FROM invoice i
JOIN invoice_line il USING (invoice_id)
GROUP BY 1
)
SELECT p.patient_id,CONCAT_WS(' ',p.first_name,p.last_name) AS patient_name,
       COALESCE(bill.bill_amount,0) AS total_billing_amount,
	   COALESCE(inl.no_of_invoice_line,0) AS no_of_invoice_line
FROM patient p
LEFT JOIN bill USING (patient_id)
LEFT JOIN inl USING (patient_id)
ORDER BY total_billing_amount DESC
LIMIT 50;

--10.Invoice line breakdown for a given invoice (example invoice_id = 123)
SELECT i.invoice_id,
       i.patient_id,
	   CONCAT_WS(' ',p.first_name,p.last_name) AS patient_name,
	   i.invoice_date,
	   i.total_amount,
	   i.paid_amount,
	   i.status,
	   i.total_amount - i.paid_amount AS remain_amount
FROM invoice i
JOIN patient p USING (patient_id)
WHERE i.invoice_id=123;

--11.Doctors ranked by average patient satisfaction proxy — using completed appointments count and canceled ratio
SELECT d.doctor_id,CONCAT_WS(' ',d.first_name,d.last_name) AS doctor_name,
       COALESCE(COUNT(a.*) FILTER(WHERE a.status='Completed'),0) AS completed_appointments,
	   COALESCE(COUNT(a.*) FILTER(WHERE a.status='Cancelled'),0) AS cancelled_appointments,
	   COALESCE(COUNT(a.*) FILTER(WHERE a.status='Cancelled'),0)/COALESCE(COUNT(a.*) FILTER(WHERE a.status='Completed'),0)::numeric AS cancellation_ratio
FROM doctor d
LEFT JOIN appointment a USING (doctor_id)
GROUP BY d.doctor_id,doctor_name
ORDER BY 1;
     
--12.Patients with outstanding balance (due > 0) and total due amount
SELECT p.patient_id,CONCAT_WS(' ',p.first_name,p.last_name) AS doctor_name,
       COALESCE(SUM(i.total_amount-i.paid_amount),0) AS total_due
FROM patient p
LEFT JOIN invoice i USING (patient_id)
GROUP BY p.patient_id,doctor_name
ORDER BY total_due DESC;

--13.Average cost per admission (including treatments performed during that admission)
WITH add_treat AS(
SELECT a.admission_id,COALESCE(SUM(t.unit_cost),0) AS total_cost
FROM admission a
LEFT JOIN treatment t USING (admission_id)
GROUP BY 1
ORDER BY 1
)
SELECT AVG(total_cost) AS avg_admission_cost
FROM add_treat;

--14.Most frequently prescribed medication names (top 25)
SELECT m.med_id,m.name,
       COUNT(p.*) AS no_of_order
FROM medication m
JOIN prescription p USING (med_id)
GROUP BY 1
ORDER BY no_of_order DESC
LIMIT 25;

--15.Use window function to show each doctor’s total appointments and rank within department
WITH app AS (
SELECT doctor_id,
       COUNT(*) AS total_app
FROM appointment
GROUP BY 1
)
SELECT d.doctor_id,
       CONCAT_WS(' ',d.first_name,d.last_name) AS doctor_name,
	   d.dept_id,
	   app.total_app,
	   RANK() OVER(PARTITION BY d.dept_id ORDER BY app.total_app DESC) AS dc_rank
FROM doctor d
JOIN app USING (doctor_id);

--16.List admissions without discharge (current inpatients admitted in 3 month) with room and days admitted
SELECT *,
       CURRENT_DATE::DATE - admit_date::DATE AS days_admitted
FROM admission
WHERE admit_date>= CURRENT_DATE - INTERVAL'3 months' AND status='Admitted';

--17.Find patients who have never had an invoice (possible missed billing)
SELECT p.patient_id,CONCAT_WS(' ',p.first_name,p.last_name) AS patient_name
FROM patient p
LEFT JOIN invoice i USING (patient_id)
GROUP BY 1
HAVING COUNT(i.*)=0;

--18.Correlated subquery — latest invoice amount per patient
SELECT DISTINCT ON (p.patient_id)
p.patient_id,p.first_name||' '||p.last_name AS patient_name,
       i.invoice_date AS last_invoice_date,
	   i.total_amount
FROM patient p
LEFT JOIN invoice i USING (patient_id)
ORDER BY 1;

--19.Patients with most different doctors seen in last year
SELECT p.patient_id,p.first_name||' '||p.last_name AS patient_name,
       COUNT(DISTINCT a.doctor_id) AS dist_dr
FROM patient p
LEFT JOIN appointment a USING (patient_id)
WHERE a.appt_datetime>=DATE_TRUNC('year',CURRENT_DATE) - INTERVAL'1 year' AND a.appt_datetime<DATE_TRUNC('year',CURRENT_DATE)
GROUP BY 1;

--20.List lab tests ordered more than X times (X=1000)
SELECT l.lab_test_id,l.test_code,
       COUNT(lr.*) AS no_of_lab_tests
FROM lab_test l
LEFT JOIN lab_result lr USING (lab_test_id)
GROUP BY 1
HAVING COUNT(lr.*)>=1000
ORDER BY 1;

--21.Latest lab result per patient
SELECT p.patient_id,p.first_name||' '||p.last_name AS patient_name,
       lr.lab_result_id,
	   lr.lab_test_id,
	   lr.sample_taken::DATE,
	   lr.result_value,
	   lr.units,
	   lr.result_date::DATE
FROM patient p
JOIN lab_result lr USING (patient_id)
ORDER BY 1;

--22.Identify no-show rate per doctor in past 6 months
SELECT d.doctor_id,d.first_name||' '||d.last_name AS doctor_name,
       COUNT(a.*) FILTER(WHERE a.status='No-Show') AS no_show,
	   COUNT(a.*) AS total_app,
       COUNT(a.*) FILTER(WHERE a.status='No-Show')/COUNT(a.*)::Numeric AS no_show_rate
FROM doctor d
LEFT JOIN appointment a USING (doctor_id)
WHERE a.appt_datetime>=CURRENT_DATE - INTERVAL '6 month'
GROUP BY 1
ORDER BY 1;

--23.Find gaps between appointments for each doctor — using lead() to detect > 7 days gap
WITH app AS(
SELECT doctor_id,
       appt_datetime::DATE,
       LEAD(appt_datetime) OVER(PARTITION BY doctor_id ORDER BY appt_datetime ASC)::DATE AS next_appt_date
FROM appointment
)
SELECT d.doctor_id,d.first_name||' '||d.last_name AS doctor_name,
       app.appt_datetime::DATE,
	   app.next_appt_date::DATE,
	   app.next_appt_date::DATE - app.appt_datetime::DATE AS gaps_between
FROM doctor d
LEFT JOIN app USING (doctor_id)
WHERE app.next_appt_date::DATE - app.appt_datetime::DATE>7
ORDER BY 1;

--24.Find avg gaps between appointments for each doctor
WITH app AS(
SELECT doctor_id,
       appt_datetime::DATE,
       LEAD(appt_datetime) OVER(PARTITION BY doctor_id ORDER BY appt_datetime ASC)::DATE AS next_appt_date
FROM appointment
)
SELECT d.doctor_id,d.first_name||' '||d.last_name AS doctor_name,
	   ROUND(AVG(app.next_appt_date::DATE - app.appt_datetime::DATE),1) AS avg_gaps_between
FROM doctor d
LEFT JOIN app USING (doctor_id)
GROUP BY 1
ORDER BY 1;

--25.Find patients readmitted within 30 days of discharge
WITH ad AS(
SELECT patient_id, admit_date::DATE, discharge_date::DATE,
       LEAD(admit_date) OVER(PARTITION BY patient_id ORDER BY admit_date ASC)::DATE next_admit_date
FROM admission
WHERE discharge_date IS NOT NULL
)
SELECT p.patient_id,p.first_name||' '||p.last_name AS patient_name,
       ad.admit_date::DATE,
	   ad.discharge_date::DATE,
       ad.next_admit_date::DATE,
	   ad.next_admit_date::DATE - ad.discharge_date::DATE AS gaps_between_next_admit
FROM patient p
JOIN ad USING (patient_id)
WHERE next_admit_date IS NOT NULL AND ad.next_admit_date::DATE - ad.discharge_date::DATE<30
ORDER BY 1;

--26.Create a pivot-like daily appointment counts per department for last 7 days (dept names as rows)
WITH dep AS(
SELECT d.dept_id,d.name,
	   COUNT(a.*) FILTER(WHERE appt_datetime::DATE=CURRENT_DATE::DATE - INTERVAL '6 days') AS d0,
	   COUNT(a.*) FILTER(WHERE appt_datetime::DATE=CURRENT_DATE::DATE - INTERVAL '5 days') AS d1,
	   COUNT(a.*) FILTER(WHERE appt_datetime::DATE=CURRENT_DATE::DATE - INTERVAL '4 days') AS d2,
	   COUNT(a.*) FILTER(WHERE appt_datetime::DATE=CURRENT_DATE::DATE - INTERVAL '3 days') AS d3,
	   COUNT(a.*) FILTER(WHERE appt_datetime::DATE=CURRENT_DATE::DATE - INTERVAL '2 days') AS d4,
	   COUNT(a.*) FILTER(WHERE appt_datetime::DATE=CURRENT_DATE::DATE - INTERVAL '1 days') AS d5,
	   COUNT(a.*) FILTER(WHERE appt_datetime::DATE=CURRENT_DATE::DATE ) AS d6
FROM department d
LEFT JOIN doctor dr USING (dept_id)
JOIN appointment a USING (doctor_id)
GROUP BY 1
ORDER BY 1
)
SELECT d.dept_id,d.name,
       dep.d0,dep.d1,dep.d2,dep.d3,dep.d4,dep.d5,dep.d6,
	   dep.d0+dep.d1+dep.d2+dep.d3+dep.d4+dep.d5+dep.d6 AS total_appt
FROM department d
JOIN dep USING (dept_id)
ORDER BY 1;

--27.Average number of prescriptions per patient (for patients with at least one Rx)
WITH prs AS (
SELECT p.patient_id,p.first_name||' '||p.last_name AS patient_name,
       COUNT(pr.*) AS no_of_prescription
FROM patient p
JOIN prescription pr USING (patient_id)
GROUP BY 1
ORDER BY 1
)
SELECT AVG(no_of_prescription) AS avg_no_of_prescription
FROM prs;

--28.Patients with most expensive single admission (top 20)
WITH trt AS(
SELECT admission_id,
       SUM(unit_cost) AS total_treatment_cost
FROM treatment
GROUP BY 1
ORDER BY 1
)
SELECT p.patient_id,p.first_name||' '||p.last_name AS patient_name,
       trt.admission_id,
	   trt.total_treatment_cost
FROM patient p
JOIN admission USING (patient_id)
JOIN trt USING (admission_id)
ORDER BY trt.total_treatment_cost DESC
LIMIT 20;

--29.For each patient show total billed this year and last year side-by-side using conditional aggregation
SELECT p.patient_id,p.first_name||' '||p.last_name AS patient_name,
       COALESCE(SUM(i.total_amount) FILTER(WHERE EXTRACT(YEAR FROM i.invoice_date)=2024),0) AS previous_year_bill,
	   COALESCE(SUM(i.total_amount) FILTER(WHERE EXTRACT(YEAR FROM i.invoice_date)=2025),0) AS current_year_bill
FROM patient p
LEFT JOIN invoice i USING (patient_id)
GROUP BY 1
ORDER BY 1;

--30.Use string_agg to return doctor profile with recent 5 appointments 
SELECT 
    d.doctor_id,
    d.first_name || ' ' || d.last_name AS doctor_name,
    STRING_AGG(a.patient_id::text, ',' ORDER BY a.appt_datetime DESC) AS recent_appointments
FROM doctor d
LEFT JOIN LATERAL (
      SELECT a.patient_id, a.appt_datetime
      FROM appointment a
      WHERE a.doctor_id = d.doctor_id
      ORDER BY a.appt_datetime DESC
      LIMIT 5
) a ON TRUE
GROUP BY d.doctor_id, doctor_name
ORDER BY d.doctor_id;

--31.Find duplicate patients by same name + DOB (possible duplicates)
SELECT first_name||' '||last_name AS patient_name,
	   dob,
	   COUNT(*) AS cnt
FROM patient
GROUP BY 1,2
HAVING  COUNT(*)>1
ORDER BY cnt DESC;

--32.Find doctors with zero appointments in past year (possibly inactive)
SELECT 
    d.doctor_id,
    d.first_name || ' ' || d.last_name AS doctor_name,
	EXTRACT(YEAR FROM a.appt_datetime) AS year,
	COUNT(a.*) AS no_of_appt
FROM doctor d
LEFT JOIN appointment a USING (doctor_id)
GROUP BY 1,2,3
HAVING EXTRACT(YEAR FROM a.appt_datetime)=2024 AND COUNT(a.*)=0
ORDER BY 1;

--33.Count total bed occupancy today (rooms with an admitted patient)
SELECT r.ward,r.room_id,
       COUNT(ad.*) FILTER(WHERE ad.status='Admitted') AS admitted_bed
FROM room r
LEFT JOIN admission ad USING (room_id)
GROUP BY 1,2
HAVING COUNT(ad.*) FILTER(WHERE ad.status='Admitted')>=1
ORDER BY 1;

--35.How many beds available in ICU today by room
WITH bed AS(
WITH ads AS(
SELECT r.ward,r.room_id,
       COUNT(ad.*) FILTER(WHERE ad.status='Admitted') AS admitted_bed
FROM room r
LEFT JOIN admission ad USING (room_id)
GROUP BY 1,2
HAVING COUNT(ad.*) FILTER(WHERE ad.status='Admitted')>=1
ORDER BY 1
)
SELECT r.ward,r.room_id,
       ads.admitted_bed,
	   r.bed_count,
	   r.bed_count - ads.admitted_bed AS bed_available
FROM room r
LEFT JOIN ads USING (room_id)
WHERE r.ward='ICU'
)
SELECT SUM(bed_available)
FROM bed
WHERE bed_available>0;

--36.Average invoice line value grouped by item_desc (top 10 expensive line types)
SELECT item_desc,
       ROUND(AVG(unit_price),2) AS avg_value
FROM invoice_line
GROUP BY 1
ORDER BY 2 DESC;

--37.Patients who had both X-ray and Surgery within same admission (identify complex cases)
SELECT DISTINCT a.admission_id,
       p.patient_id, 
	   p.first_name||' '|| p.last_name AS patient_name
FROM admission a
JOIN patient p USING (patient_id)
JOIN treatment ts ON ts.admission_id=a.admission_id 
                  AND ts.description ILIKE '%X-Ray%' 
JOIN treatment tx ON tx.admission_id=a.admission_id 
                  AND tx.description ILIKE '%Surgery%' 
ORDER BY 2;

--38.Patients who received a specific lab test (e.g., 'LT-102') and their most recent result
WITH lr AS (
SELECT patient_id, lab_test_id, result_value, units,
       MAX(result_date) AS result_date
FROM lab_result
GROUP BY 1,2,3,4
ORDER BY 1
)
SELECT p.patient_id, 
	   p.first_name||' '|| p.last_name AS patient_name,
	   lr.lab_test_id, l.test_code, lr.result_value, lr.units,
	   lr.result_date
FROM patient p
JOIN lr USING (patient_id)
JOIN lab_test l USING (lab_test_id)
WHERE l.test_code = 'LT-102'
ORDER BY lr.result_date DESC;

--39.Patients with prescriptions active today
SELECT p.patient_id, 
	   p.first_name||' '|| p.last_name AS patient_name,
	   pr.med_id,pr.dosage,pr.freq,pr.notes
FROM patient p
JOIN prescription pr USING (patient_id)
WHERE CURRENT_DATE BETWEEN pr.start_date AND pr.end_date 
ORDER BY 1;

--40.Top 10 patients by average invoice amount (only patients with >=2 invoices)
SELECT p.patient_id, 
	   p.first_name||' '|| p.last_name AS patient_name,
	   ROUND(AVG(i.total_amount),2) AS avg_inv_amount,
	   COUNT(i.*) AS no_invoice
FROM patient p
JOIN invoice i USING (patient_id)
GROUP BY 1
HAVING COUNT(i.*)>=2
ORDER BY 3 DESC
LIMIT 10;

--41.For each room, last admission end date (show room utilization recency)
SELECT room_id,
       MAX(discharge_date) AS last_discharge,
	   CURRENT_DATE - MAX(discharge_date::DATE)||' '||'days' AS room_empty
FROM admission
WHERE status='Discharged'
GROUP BY 1
ORDER BY 1;

--42.Find appointment time slots most used (hour of day)
SELECT 
      CASE
      WHEN EXTRACT(HOUR FROM appt_datetime) BETWEEN 0 AND 6 THEN '12AM-6AM'
	  WHEN EXTRACT(HOUR FROM appt_datetime) BETWEEN 7 AND 12 THEN '7AM-12PM'
	  WHEN EXTRACT(HOUR FROM appt_datetime) BETWEEN 13 AND 18 THEN '1PM-6PM'
	  ELSE '7PM-12AM' END AS daily_hour,
	  COUNT(*) AS patient_cnt
FROM appointment
GROUP BY 1
ORDER BY 2 DESC;

--43.Create a patient risk score (simple example) using CTEs and CASEs — high if >65 or multiple admissions
WITH pg AS(
SELECT patient_id,
       first_name||' '||last_name AS patient_name,
	   EXTRACT(YEAR FROM AGE(CURRENT_DATE,dob)) AS age 
FROM patient
),
ad AS(
SELECT patient_id,
       COUNT(*) AS add_cnt
FROM admission
GROUP BY 1
)
SELECT pg.patient_id, pg.patient_name, pg.age,
       ad.add_cnt,
	   CASE
	   WHEN pg.age>=65 AND ad.add_cnt>=2 THEN 'Very High'
	    WHEN pg.age>=65 OR ad.add_cnt>=2 THEN 'High'
	   WHEN pg.age BETWEEN 45 AND 64 OR ad.add_cnt>=2 THEN 'Medium'
	   ELSE 'Normal' END AS risK_label
FROM pg
JOIN ad USING (patient_id);





	   

	   






