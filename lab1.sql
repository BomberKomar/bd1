CREATE DATABASE lab1;

\c lab1;

CREATE TABLE "Patients" (
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

CREATE TABLE "Appointments" (
  "id" serial PRIMARY KEY,
  "patient_id" int NOT NULL,
  "doctor_id" int NOT NULL,
  "appointment_time" timestamp NOT NULL,
  "status" text NOT NULL
);

CREATE TABLE "Doctors" (
  "id" serial PRIMARY KEY,
  "first_name" text NOT NULL,
  "last_name" text NOT NULL,
  "specialization_id" int NOT NULL,
  "employment_date" timestamp NOT NULL,
  "office_address_id" int
);

CREATE TABLE "Specializations" (
  "id" serial PRIMARY KEY,
  "name" text UNIQUE NOT NULL
);

CREATE TABLE "Prescriptions" (
  "id" serial PRIMARY KEY,
  "patient_id" int NOT NULL,
  "doctor_id" int NOT NULL,
  "medication_id" int NOT NULL,
  "dosage" text NOT NULL,
  "duration" text NOT NULL,
  "issue_date" timestamp NOT NULL
);

CREATE TABLE "Medications" (
  "id" serial PRIMARY KEY,
  "name" text UNIQUE NOT NULL,
  "description" text
);

CREATE TABLE "Addresses" (
  "id" serial PRIMARY KEY,
  "country_id" int NOT NULL,
  "city" text NOT NULL,
  "street" text NOT NULL,
  "zip_code" text NOT NULL
);

CREATE TABLE "Countries" (
  "id" serial PRIMARY KEY,
  "name" text UNIQUE NOT NULL
);

CREATE TABLE "MedicalRecords" (
  "id" serial PRIMARY KEY,
  "patient_id" int NOT NULL,
  "record_text" text NOT NULL,
  "creation_date" timestamp NOT NULL DEFAULT 'now()'
);

CREATE TABLE "BillingAccounts" (
  "id" serial PRIMARY KEY,
  "patient_id" int NOT NULL,
  "balance" real NOT NULL,
  "last_payment_date" timestamp
);

CREATE TABLE "Payments" (
  "id" serial PRIMARY KEY,
  "billing_account_id" int NOT NULL,
  "amount" real NOT NULL,
  "payment_date" timestamp NOT NULL,
  "method" text NOT NULL
);

CREATE TABLE "InsurancePolicies" (
  "id" serial PRIMARY KEY,
  "patient_id" int NOT NULL,
  "provider" text NOT NULL,
  "policy_number" text NOT NULL,
  "start_date" timestamp NOT NULL,
  "end_date" timestamp
);

CREATE TABLE "LaboratoryTests" (
  "id" serial PRIMARY KEY,
  "patient_id" int NOT NULL,
  "test_type" text NOT NULL,
  "requested_by_doctor_id" int NOT NULL,
  "result" text,
  "test_date" timestamp NOT NULL
);

CREATE TABLE "HospitalRooms" (
  "id" serial PRIMARY KEY,
  "room_number" text NOT NULL,
  "type" text NOT NULL,
  "status" text NOT NULL
);

CREATE TABLE "Hospitalizations" (
  "id" serial PRIMARY KEY,
  "patient_id" int NOT NULL,
  "room_id" int NOT NULL,
  "admission_date" timestamp NOT NULL,
  "discharge_date" timestamp
);

ALTER TABLE "Patients" ADD FOREIGN KEY ("residential_address_id") REFERENCES "Addresses" ("id");

ALTER TABLE "Appointments" ADD FOREIGN KEY ("patient_id") REFERENCES "Patients" ("id");

ALTER TABLE "Appointments" ADD FOREIGN KEY ("doctor_id") REFERENCES "Doctors" ("id");

ALTER TABLE "Doctors" ADD FOREIGN KEY ("specialization_id") REFERENCES "Specializations" ("id");

ALTER TABLE "Doctors" ADD FOREIGN KEY ("office_address_id") REFERENCES "Addresses" ("id");

ALTER TABLE "Prescriptions" ADD FOREIGN KEY ("patient_id") REFERENCES "Patients" ("id");

ALTER TABLE "Prescriptions" ADD FOREIGN KEY ("doctor_id") REFERENCES "Doctors" ("id");

ALTER TABLE "Prescriptions" ADD FOREIGN KEY ("medication_id") REFERENCES "Medications" ("id");

ALTER TABLE "Addresses" ADD FOREIGN KEY ("country_id") REFERENCES "Countries" ("id");

ALTER TABLE "MedicalRecords" ADD FOREIGN KEY ("patient_id") REFERENCES "Patients" ("id");

ALTER TABLE "BillingAccounts" ADD FOREIGN KEY ("patient_id") REFERENCES "Patients" ("id");

ALTER TABLE "Payments" ADD FOREIGN KEY ("billing_account_id") REFERENCES "BillingAccounts" ("id");

ALTER TABLE "InsurancePolicies" ADD FOREIGN KEY ("patient_id") REFERENCES "Patients" ("id");

ALTER TABLE "LaboratoryTests" ADD FOREIGN KEY ("patient_id") REFERENCES "Patients" ("id");

ALTER TABLE "LaboratoryTests" ADD FOREIGN KEY ("requested_by_doctor_id") REFERENCES "Doctors" ("id");

ALTER TABLE "Hospitalizations" ADD FOREIGN KEY ("patient_id") REFERENCES "Patients" ("id");

ALTER TABLE "Hospitalizations" ADD FOREIGN KEY ("room_id") REFERENCES "HospitalRooms" ("id");




CREATE FUNCTION find_doctor_specialization(doctor_id_arg INT) RETURNS TEXT
LANGUAGE SQL AS $$
SELECT name FROM Specializations WHERE id = (
    SELECT specialization_id FROM Doctors WHERE id = doctor_id_arg
);
$$;

CREATE PROCEDURE discharge_patients_from_room(room_id_arg INT)
LANGUAGE SQL AS $$
UPDATE Hospitalizations SET discharge_date = NOW() WHERE room_id = room_id_arg AND discharge_date IS NULL;
$$;

CREATE FUNCTION set_medical_records_updated_at_trigger() RETURNS trigger
LANGUAGE plpgsql AS
$$
BEGIN
   NEW.updated_at := current_timestamp;
   RETURN NEW;
END;
$$;
CREATE TRIGGER medical_records_before_update_trigger BEFORE UPDATE ON MedicalRecords FOR EACH ROW EXECUTE PROCEDURE set_medical_records_updated_at_trigger();

CREATE FUNCTION calculate_total_payments(patient_id_arg INT) RETURNS REAL
LANGUAGE SQL AS $$
SELECT SUM(p.amount) FROM Payments AS p 
INNER JOIN BillingAccounts AS ba ON p.billing_account_id = ba.id 
WHERE ba.patient_id = patient_id_arg;
$$;

CREATE FUNCTION get_current_medications(patient_id_arg INT) RETURNS TABLE(medication_name TEXT, dosage TEXT, duration TEXT)
LANGUAGE SQL AS $$
SELECT m.name, p.dosage, p.duration FROM Prescriptions AS p 
INNER JOIN Medications AS m ON p.medication_id = m.id 
WHERE p.patient_id = patient_id_arg AND p.issue_date > (NOW() - INTERVAL '1 month');
$$;

CREATE PROCEDURE cancel_appointments_for_doctor(doctor_id_arg INT)
LANGUAGE SQL AS $$
UPDATE Appointments SET status = 'cancelled' WHERE doctor_id = doctor_id_arg AND appointment_time > NOW();
$$;

CREATE FUNCTION find_next_available_appointment(doctor_id_arg INT) RETURNS TIMESTAMP
LANGUAGE SQL AS $$
SELECT appointment_time FROM Appointments 
WHERE doctor_id = doctor_id_arg AND status = 'scheduled' AND appointment_time > NOW() 
ORDER BY appointment_time ASC LIMIT 1;
$$;

CREATE FUNCTION update_last_payment_date_trigger() RETURNS trigger
LANGUAGE plpgsql AS
$$
BEGIN
   UPDATE BillingAccounts SET last_payment_date = NEW.payment_date WHERE id = NEW.billing_account_id;
   RETURN NEW;
END;
$$;
CREATE TRIGGER payments_after_insert_trigger AFTER INSERT ON Payments FOR EACH ROW EXECUTE PROCEDURE update_last_payment_date_trigger();

CREATE FUNCTION list_appointments_for_patient(patient_id_arg INT) RETURNS TABLE(appointment_id INT, doctor_id INT, appointment_time TIMESTAMP, status TEXT)
LANGUAGE SQL AS $$
SELECT id, doctor_id, appointment_time, status FROM Appointments WHERE patient_id = patient_id_arg ORDER BY appointment_time;
$$;

CREATE PROCEDURE update_patient_address(patient_id_arg INT, new_address_id_arg INT)
LANGUAGE SQL AS $$
UPDATE Patients SET residential_address_id = new_address_id_arg WHERE id = patient_id_arg;
$$;
