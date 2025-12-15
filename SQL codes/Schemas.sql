---------------------------------------------------------
-- 1. DEPARTMENT
---------------------------------------------------------
CREATE TABLE department (
    dept_id INT PRIMARY KEY,
    name VARCHAR(100),
    floor VARCHAR(10),
    phone_ext VARCHAR(10)
);

---------------------------------------------------------
-- 2. DOCTOR
---------------------------------------------------------
CREATE TABLE doctor (
    doctor_id INT PRIMARY KEY,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    dept_id INT,
    specialization VARCHAR(100),
    phone VARCHAR(20),
    email VARCHAR(150),
    hire_date DATE,
    FOREIGN KEY (dept_id) REFERENCES department(dept_id)
);

---------------------------------------------------------
-- 3. PATIENT
---------------------------------------------------------
CREATE TABLE patient (
    patient_id INT PRIMARY KEY,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    gender VARCHAR(10),
    dob DATE,
    phone VARCHAR(20),
    email VARCHAR(150),
    address VARCHAR(255),
    blood_group VARCHAR(10),
    primary_insurance VARCHAR(100)
);

---------------------------------------------------------
-- 4. ROOM
---------------------------------------------------------
CREATE TABLE room (
    room_id INT PRIMARY KEY,
    room_number VARCHAR(20),
    ward VARCHAR(50),
    bed_count INT,
    daily_charge DECIMAL(10,2)
);

---------------------------------------------------------
-- 5. APPOINTMENT
---------------------------------------------------------
CREATE TABLE appointment (
    appointment_id INT PRIMARY KEY,
    patient_id INT,
    doctor_id INT,
    appt_datetime TIMESTAMP,
    reason VARCHAR(255),
    status VARCHAR(50),
    created_at TIMESTAMP,
    FOREIGN KEY (patient_id) REFERENCES patient(patient_id),
    FOREIGN KEY (doctor_id) REFERENCES doctor(doctor_id)
);

---------------------------------------------------------
-- 6. ADMISSION
---------------------------------------------------------
CREATE TABLE admission (
    admission_id INT PRIMARY KEY,
    patient_id INT,
    admit_date TIMESTAMP,
    discharge_date TIMESTAMP,
    doctor_id INT,
    room_id INT,
    admit_reason VARCHAR(255),
    status VARCHAR(50),
    FOREIGN KEY (patient_id) REFERENCES patient(patient_id),
    FOREIGN KEY (doctor_id) REFERENCES doctor(doctor_id),
    FOREIGN KEY (room_id) REFERENCES room(room_id)
);

---------------------------------------------------------
-- 7. TREATMENT
---------------------------------------------------------
CREATE TABLE treatment (
    treatment_id INT PRIMARY KEY,
    admission_id INT,
    appointment_id INT,
    treatment_code VARCHAR(20),
    description VARCHAR(255),
    unit_cost DECIMAL(10,2),
    performed_on TIMESTAMP,
    FOREIGN KEY (admission_id) REFERENCES admission(admission_id),
    FOREIGN KEY (appointment_id) REFERENCES appointment(appointment_id)
);

---------------------------------------------------------
-- 8. MEDICATION
---------------------------------------------------------
CREATE TABLE medication (
    med_id INT PRIMARY KEY,
    name VARCHAR(150),
    form VARCHAR(50),
    strength VARCHAR(50),
    unit_price DECIMAL(10,2)
);

---------------------------------------------------------
-- 9. PRESCRIPTION
---------------------------------------------------------
CREATE TABLE prescription (
    prescription_id INT PRIMARY KEY,
    patient_id INT,
    doctor_id INT,
    med_id INT,
    dosage VARCHAR(100),
    freq VARCHAR(100),
    start_date DATE,
    end_date DATE,
    notes VARCHAR(255),
    FOREIGN KEY (patient_id) REFERENCES patient(patient_id),
    FOREIGN KEY (doctor_id) REFERENCES doctor(doctor_id),
    FOREIGN KEY (med_id) REFERENCES medication(med_id)
);

---------------------------------------------------------
-- 10. LAB TEST
---------------------------------------------------------
CREATE TABLE lab_test (
    lab_test_id INT PRIMARY KEY,
    test_code VARCHAR(30),
    name VARCHAR(150),
    normal_range VARCHAR(100),
    cost DECIMAL(10,2)
);

---------------------------------------------------------
-- 11. LAB RESULT
---------------------------------------------------------
CREATE TABLE lab_result (
    lab_result_id INT PRIMARY KEY,
    patient_id INT,
    lab_test_id INT,
    ordered_by INT,
    sample_taken TIMESTAMP,
    result_value VARCHAR(100),
    units VARCHAR(50),
    result_date TIMESTAMP,
    FOREIGN KEY (patient_id) REFERENCES patient(patient_id),
    FOREIGN KEY (lab_test_id) REFERENCES lab_test(lab_test_id),
    FOREIGN KEY (ordered_by) REFERENCES doctor(doctor_id)
);

---------------------------------------------------------
-- 12. INVOICE
---------------------------------------------------------
CREATE TABLE invoice (
    invoice_id INT PRIMARY KEY,
    patient_id INT,
    invoice_date DATE,
    total_amount DECIMAL(12,2),
    paid_amount DECIMAL(12,2),
    status VARCHAR(50),
    FOREIGN KEY (patient_id) REFERENCES patient(patient_id)
);

---------------------------------------------------------
-- 13. INVOICE LINE
---------------------------------------------------------
CREATE TABLE invoice_line (
    invoice_line_id INT PRIMARY KEY,
    invoice_id INT,
    item_desc VARCHAR(255),
    quantity INT,
    unit_price DECIMAL(10,2),
    FOREIGN KEY (invoice_id) REFERENCES invoice(invoice_id)
);

---------------------------------------------------------

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

