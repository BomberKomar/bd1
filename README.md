# bd1
docker run -d --name bd1_db -p 5432:5432 -e POSTGRES_PASSWORD=postgres postgres
psql -h localhost -U postgres < bd1/lab1.sql
in psql: \i bd1/lab1.sql
