CREATE DATABASE lab1;

\c lab1;

CREATE TABLE "patients" (
  "id" serial PRIMARY KEY,
  "first_name" text NOT NULL,
  "last_name" text NOT NULL,
  "middle_name" text,
  "date_of_birth" date NOT NULL,
  "gender" text NOT NULL,
  "residential_address_id" int NOT NULL,
  "registration_date" timestamp NOT NULL DEFAULT 'now()',
  "medical_record_number" text UNIQUE NOT NULL
);

CREATE TABLE "appointments" (
  "id" serial PRIMARY KEY,
  "patient_id" int NOT NULL,
  "doctor_id" int NOT NULL,
  "appointment_time" timestamp NOT NULL,
  "status" text NOT NULL
);

CREATE TABLE "doctors" (
  "id" serial PRIMARY KEY,
  "first_name" text NOT NULL,
  "last_name" text NOT NULL,
  "specialization_id" int NOT NULL,
  "employment_date" timestamp NOT NULL,
  "office_address_id" int
);

CREATE TABLE "specializations" (
  "id" serial PRIMARY KEY,
  "name" text UNIQUE NOT NULL
);

CREATE TABLE "prescriptions" (
  "id" serial PRIMARY KEY,
  "patient_id" int NOT NULL,
  "doctor_id" int NOT NULL,
  "medication_id" int NOT NULL,
  "dosage" text NOT NULL,
  "duration" text NOT NULL,
  "issue_date" timestamp NOT NULL
);

CREATE TABLE "medications" (
  "id" serial PRIMARY KEY,
  "name" text UNIQUE NOT NULL,
  "description" text
);

CREATE TABLE "addresses" (
  "id" serial PRIMARY KEY,
  "country_id" int NOT NULL,
  "city" text NOT NULL,
  "street" text NOT NULL,
  "zip_code" text NOT NULL
);

CREATE TABLE "countries" (
  "id" serial PRIMARY KEY,
  "name" text UNIQUE NOT NULL
);

CREATE TABLE "medicalRecords" (
  "id" serial PRIMARY KEY,
  "patient_id" int NOT NULL,
  "record_text" text NOT NULL,
  "creation_date" timestamp NOT NULL DEFAULT 'now()',
  "updated_at" timestamp
);

CREATE TABLE "billingAccounts" (
  "id" serial PRIMARY KEY,
  "patient_id" int NOT NULL,
  "balance" real NOT NULL,
  "last_payment_date" timestamp
);

CREATE TABLE "payments" (
  "id" serial PRIMARY KEY,
  "billing_account_id" int NOT NULL,
  "amount" real NOT NULL,
  "payment_date" timestamp NOT NULL,
  "method" text NOT NULL
);

CREATE TABLE "insurancePolicies" (
  "id" serial PRIMARY KEY,
  "patient_id" int NOT NULL,
  "provider" text NOT NULL,
  "policy_number" text NOT NULL,
  "start_date" timestamp NOT NULL,
  "end_date" timestamp
);

CREATE TABLE "laboratoryTests" (
  "id" serial PRIMARY KEY,
  "patient_id" int NOT NULL,
  "test_type" text NOT NULL,
  "requested_by_doctor_id" int NOT NULL,
  "result" text,
  "test_date" timestamp NOT NULL
);

CREATE TABLE "hospitalRooms" (
  "id" serial PRIMARY KEY,
  "room_number" text NOT NULL,
  "type" text NOT NULL,
  "status" text NOT NULL
);

CREATE TABLE "hospitalizations" (
  "id" serial PRIMARY KEY,
  "patient_id" int NOT NULL,
  "room_id" int NOT NULL,
  "admission_date" timestamp NOT NULL,
  "discharge_date" timestamp
);

ALTER TABLE "patients" ADD FOREIGN KEY ("residential_address_id") REFERENCES "addresses" ("id");

ALTER TABLE "appointments" ADD FOREIGN KEY ("patient_id") REFERENCES "patients" ("id");

ALTER TABLE "appointments" ADD FOREIGN KEY ("doctor_id") REFERENCES "doctors" ("id");

ALTER TABLE "doctors" ADD FOREIGN KEY ("specialization_id") REFERENCES "specializations" ("id");

ALTER TABLE "doctors" ADD FOREIGN KEY ("office_address_id") REFERENCES "addresses" ("id");

ALTER TABLE "prescriptions" ADD FOREIGN KEY ("patient_id") REFERENCES "patients" ("id");

ALTER TABLE "prescriptions" ADD FOREIGN KEY ("doctor_id") REFERENCES "doctors" ("id");

ALTER TABLE "prescriptions" ADD FOREIGN KEY ("medication_id") REFERENCES "medications" ("id");

ALTER TABLE "addresses" ADD FOREIGN KEY ("country_id") REFERENCES "countries" ("id");

ALTER TABLE "medicalRecords" ADD FOREIGN KEY ("patient_id") REFERENCES "patients" ("id");

ALTER TABLE "billingAccounts" ADD FOREIGN KEY ("patient_id") REFERENCES "patients" ("id");

ALTER TABLE "payments" ADD FOREIGN KEY ("billing_account_id") REFERENCES "billingAccounts" ("id");

ALTER TABLE "insurancePolicies" ADD FOREIGN KEY ("patient_id") REFERENCES "patients" ("id");

ALTER TABLE "laboratoryTests" ADD FOREIGN KEY ("patient_id") REFERENCES "patients" ("id");

ALTER TABLE "laboratoryTests" ADD FOREIGN KEY ("requested_by_doctor_id") REFERENCES "doctors" ("id");

ALTER TABLE "hospitalizations" ADD FOREIGN KEY ("patient_id") REFERENCES "patients" ("id");

ALTER TABLE "hospitalizations" ADD FOREIGN KEY ("room_id") REFERENCES "hospitalRooms" ("id");




CREATE FUNCTION find_doctor_specialization(doctor_id_arg INT) RETURNS TEXT
LANGUAGE SQL AS $$
SELECT specializations.name FROM specializations WHERE id = (
    SELECT specialization_id FROM doctors WHERE id = doctor_id_arg
);
$$;

CREATE PROCEDURE discharge_patients_from_room(room_id_arg INT)
LANGUAGE SQL AS $$
UPDATE hospitalizations SET discharge_date = NOW() WHERE room_id = room_id_arg AND discharge_date IS NULL;
$$;

CREATE FUNCTION set_medical_records_updated_at_trigger() RETURNS trigger
LANGUAGE plpgsql AS
$$
BEGIN
   NEW.updated_at := current_timestamp;
   RETURN NEW;
END;
$$;
CREATE TRIGGER medical_records_before_update_trigger BEFORE UPDATE ON "medicalRecords" FOR EACH ROW EXECUTE PROCEDURE set_medical_records_updated_at_trigger();

CREATE FUNCTION calculate_total_payments(patient_id_arg INT) RETURNS REAL
LANGUAGE SQL AS $$
SELECT SUM(p.amount) FROM payments AS p 
INNER JOIN "billingAccounts" AS ba ON p.billing_account_id = ba.id 
WHERE ba.patient_id = patient_id_arg;
$$;

CREATE FUNCTION get_current_medications(patient_id_arg INT) RETURNS TABLE(medication_name TEXT, dosage TEXT, duration TEXT)
LANGUAGE SQL AS $$
SELECT m.name, p.dosage, p.duration FROM prescriptions AS p 
INNER JOIN medications AS m ON p.medication_id = m.id 
WHERE p.patient_id = patient_id_arg AND p.issue_date > (NOW() - INTERVAL '1 month');
$$;

CREATE PROCEDURE cancel_appointments_for_doctor(doctor_id_arg INT)
LANGUAGE SQL AS $$
UPDATE appointments SET status = 'cancelled' WHERE doctor_id = doctor_id_arg AND appointment_time > NOW();
$$;

CREATE FUNCTION find_next_available_appointment(doctor_id_arg INT) RETURNS TIMESTAMP
LANGUAGE SQL AS $$
SELECT appointment_time FROM appointments 
WHERE doctor_id = doctor_id_arg AND status = 'scheduled' AND appointment_time > NOW() 
ORDER BY appointment_time ASC LIMIT 1;
$$;

CREATE FUNCTION update_last_payment_date_trigger() RETURNS trigger
LANGUAGE plpgsql AS
$$
BEGIN
   UPDATE "billingAccounts" SET last_payment_date = NEW.payment_date WHERE id = NEW.billing_account_id;
   RETURN NEW;
END;
$$;
CREATE TRIGGER payments_after_insert_trigger AFTER INSERT ON payments FOR EACH ROW EXECUTE PROCEDURE update_last_payment_date_trigger();

CREATE FUNCTION list_appointments_for_patient(patient_id_arg INT) RETURNS TABLE(appointment_id INT, doctor_id INT, appointment_time TIMESTAMP, status TEXT)
LANGUAGE SQL AS $$
SELECT id, doctor_id, appointment_time, status FROM appointments WHERE patient_id = patient_id_arg ORDER BY appointment_time;
$$;

CREATE PROCEDURE update_patient_address(patient_id_arg INT, new_address_id_arg INT)
LANGUAGE SQL AS $$
UPDATE patients SET residential_address_id = new_address_id_arg WHERE id = patient_id_arg;
$$;

CREATE FUNCTION get_insurance_policy(patient_id_arg INT) RETURNS TABLE(provider TEXT, policy_number TEXT, start_date TIMESTAMP, end_date TIMESTAMP)
LANGUAGE SQL AS $$
SELECT provider, policy_number, start_date, end_date FROM "insurancePolicies" WHERE patient_id = patient_id_arg;
$$;

CREATE PROCEDURE record_lab_test_result(test_id_arg INT, result_text TEXT)
LANGUAGE SQL AS $$
UPDATE "laboratoryTests" SET result = result_text WHERE id = test_id_arg;
$$;

INSERT INTO specializations(id, name) VALUES (1, 'surgeon');
INSERT INTO specializations(id, name) VALUES (2, 'nurse');
INSERT INTO doctors(id, first_name, last_name,specialization_id, employment_date) VALUES (1, 'Nazar', 'Vasyliev', 1, '2022-10-10 11:30:30');
INSERT INTO doctors(id, first_name, last_name,specialization_id, employment_date) VALUES (2, 'Nazar2', 'Vasyliev2', 1, '2023-10-10 11:30:30');
INSERT INTO doctors(id, first_name, last_name,specialization_id, employment_date) VALUES (3, 'Nazar3', 'Vasyliev3', 2, '2022-10-11 11:30:30');
INSERT INTO countries (id, name) VALUES (1, 'United States');
INSERT INTO countries (id, name) VALUES (2, 'United Kingdom');
INSERT INTO addresses (id, country_id, city, street, zip_code) VALUES (1, 1, 'New York', '123 Main St', '10001');
INSERT INTO addresses (id, country_id, city, street, zip_code) VALUES (2, 2, 'London', '456 Side St', 'N1 5AA');
INSERT INTO patients (id, first_name, last_name, date_of_birth, gender, residential_address_id, medical_record_number) VALUES (1, 'John', 'Doe', '1980-01-01', 'Male', 1, 'MRN12345');
INSERT INTO patients (id, first_name, last_name, date_of_birth, gender, residential_address_id, medical_record_number) VALUES (2, 'Jane', 'Smith', '1990-02-02', 'Female', 2, 'MRN54321');
INSERT INTO medications (id, name, description) VALUES (1, 'MedicationA', 'Description of MedicationA');
INSERT INTO medications (id, name, description) VALUES (2, 'MedicationB', 'Description of MedicationB');
INSERT INTO prescriptions (id, patient_id, doctor_id, medication_id, dosage, duration, issue_date) VALUES (1, 1, 1, 1, '10mg', '30 days', NOW());
INSERT INTO prescriptions (id, patient_id, doctor_id, medication_id, dosage, duration, issue_date) VALUES (2, 2, 2, 2, '20mg', '60 days', NOW());
INSERT INTO appointments (id, patient_id, doctor_id, appointment_time, status) VALUES (1, 1, 1, '2023-12-01 10:00:00', 'Scheduled');
INSERT INTO appointments (id, patient_id, doctor_id, appointment_time, status) VALUES (2, 2, 2, '2023-12-02 11:00:00', 'Scheduled');
INSERT INTO "billingAccounts" (id, patient_id, balance, last_payment_date) VALUES (1, 1, 100.00, NOW());
INSERT INTO "billingAccounts" (id, patient_id, balance, last_payment_date) VALUES (2, 2, 200.00, NOW());
INSERT INTO payments (id, billing_account_id, amount, payment_date, method) VALUES (1, 1, 50.00, NOW(), 'Credit Card');
INSERT INTO payments (id, billing_account_id, amount, payment_date, method) VALUES (2, 2, 75.00, NOW(), 'Debit Card');
INSERT INTO "insurancePolicies" (id, patient_id, provider, policy_number, start_date, end_date) VALUES (1, 1, 'Insurance Co A', 'POLICY123', '2023-01-01', '2024-01-01');
INSERT INTO "insurancePolicies" (id, patient_id, provider, policy_number, start_date, end_date) VALUES (2, 2, 'Insurance Co B', 'POLICY456', '2023-02-01', '2024-02-01');
INSERT INTO "laboratoryTests" (id, patient_id, test_type, requested_by_doctor_id, test_date) VALUES (1, 1, 'Blood Test', 1, NOW());
INSERT INTO "laboratoryTests" (id, patient_id, test_type, requested_by_doctor_id, test_date) VALUES (2, 2, 'X-Ray', 2, NOW());
INSERT INTO "hospitalRooms" (id, room_number, type, status) VALUES (1, '101', 'Standard', 'Available');
INSERT INTO "hospitalRooms" (id, room_number, type, status) VALUES (2, '102', 'Deluxe', 'Occupied');
INSERT INTO hospitalizations (id, patient_id, room_id, admission_date, discharge_date) VALUES (1, 1, 1, NOW(), NULL);
INSERT INTO hospitalizations (id, patient_id, room_id, admission_date, discharge_date) VALUES (2, 2, 2, NOW(), NULL);
INSERT INTO "medicalRecords" (id, patient_id, record_text, creation_date) VALUES (1, 1, 'Patient has a history of allergies.', NOW());
INSERT INTO "medicalRecords" (id, patient_id, record_text, creation_date) VALUES (2, 1, 'Follow-up required for previous consultation.', NOW());
INSERT INTO "medicalRecords" (id, patient_id, record_text, creation_date) VALUES (3, 2, 'Patient undergoing treatment for hypertension.', NOW());
