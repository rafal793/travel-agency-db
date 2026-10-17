# Travel Agency Database

Relational database project for a travel agency that organizes guided trips.

Built for **Microsoft SQL Server (T-SQL)**.

## What this project covers

- people, employees, guides, and tourists
- routes, route points, and planned trips
- ticket sales, payments, and reviews
- trip groups and participants
- guide languages and equipment rentals
- history of guide statuses and route prices

It also includes:

- **10 views** for reports and day-to-day checks
- **2 functions** (free seats, current ticket price)
- **5 stored procedures** (booking, status change, trip start, add route, close price)
- **5 triggers** for business rules (seat limit, paid ticket protection, license check, and more)



## Project structure

```text
.
├── README.md                  
├── schema.sql                 # full SQL script
└── project_description.pdf    
```



## How to run

1. Open Microsoft SQL Server.
2. Create an empty database (optional), for example:

```sql
CREATE DATABASE TravelAgency;
GO
USE TravelAgency;
GO
```

3. Run the whole file `schema.sql`.

The script:

- drops old objects if they exist
- creates tables, views, functions, procedures, and triggers
- inserts sample data
- runs a few example queries at the end



## Main design ideas

- Shared base table `Persons` for employees, guides, and tourists
- Separation of stable data and data that changes over time
- History tables for guide statuses and ticket prices
- Business rules enforced in the database (procedures + triggers)



## Documentation

See `project_description.pdf` for project assumptions, entity list, views, procedures, triggers, and example queries.
