-- drop existing objects (safe re-run)
DROP TABLE IF EXISTS Reviews, Payments, Rentals, Guide_Languages,
    Group_Members, Trip_Groups, Tickets, Trip_Realizations, Planned_Trips,
    Price_History, Route_Points, Routes, Guide_Status_History,
    Guide_Status_Dictionary, Guides, Employees, Tourists, Persons, Languages, Equipment;
GO

-- tables

CREATE TABLE Persons (
    person_id INT IDENTITY(1,1) PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    pesel CHAR(11) UNIQUE,
    email VARCHAR(100)
);
GO

CREATE TABLE Employees (
    employee_id INT PRIMARY KEY,
    hire_date DATE NOT NULL,
    base_salary DECIMAL(10,2),
    FOREIGN KEY (employee_id) REFERENCES Persons(person_id)
);
GO

CREATE TABLE Guides (
    guide_id INT PRIMARY KEY,
    license_number VARCHAR(20) UNIQUE,
    biography TEXT,
    FOREIGN KEY (guide_id) REFERENCES Employees(employee_id)
);
GO

CREATE TABLE Tourists (
    tourist_id INT PRIMARY KEY,
    country_of_origin VARCHAR(50),
    passport_number VARCHAR(20),
    FOREIGN KEY (tourist_id) REFERENCES Persons(person_id)
);
GO

CREATE TABLE Guide_Status_Dictionary (
    status_id INT PRIMARY KEY,
    status_name VARCHAR(30) -- e.g. available, on trip, on leave, sick
);
GO

CREATE TABLE Guide_Status_History (
    history_id INT IDENTITY(1,1) PRIMARY KEY,
    guide_id INT NOT NULL,
    status_id INT,
    valid_from DATETIME NOT NULL,
    valid_to DATETIME, -- NULL means the status is currently active
    FOREIGN KEY (guide_id) REFERENCES Guides(guide_id),
    FOREIGN KEY (status_id) REFERENCES Guide_Status_Dictionary(status_id)
);
GO

CREATE TABLE Routes (
    route_id INT IDENTITY(1,1) PRIMARY KEY,
    route_name VARCHAR(100) NOT NULL,
    description TEXT,
    difficulty VARCHAR(20),
    estimated_time_min INT
);
GO

CREATE TABLE Route_Points (
    point_id INT IDENTITY(1,1) PRIMARY KEY,
    route_id INT,
    point_name VARCHAR(100),
    point_order INT,
    FOREIGN KEY (route_id) REFERENCES Routes(route_id)
);
GO

CREATE TABLE Price_History (
    price_id INT IDENTITY(1,1) PRIMARY KEY,
    route_id INT,
    ticket_type VARCHAR(20), -- e.g. standard, discount
    price DECIMAL(10,2) NOT NULL,
    valid_from DATE NOT NULL,
    valid_to DATE,
    FOREIGN KEY (route_id) REFERENCES Routes(route_id)
);
GO

CREATE TABLE Planned_Trips (
    trip_id INT IDENTITY(1,1) PRIMARY KEY,
    route_id INT,
    guide_id INT,
    planned_start DATETIME NOT NULL,
    max_people INT DEFAULT 20,
    FOREIGN KEY (route_id) REFERENCES Routes(route_id),
    FOREIGN KEY (guide_id) REFERENCES Guides(guide_id)
);
GO

CREATE TABLE Trip_Groups (
    group_id INT IDENTITY(1,1) PRIMARY KEY,
    trip_id INT,
    group_name VARCHAR(50),
    FOREIGN KEY (trip_id) REFERENCES Planned_Trips(trip_id)
);
GO

CREATE TABLE Group_Members (
    group_id INT,
    tourist_id INT,
    PRIMARY KEY (group_id, tourist_id),
    FOREIGN KEY (group_id) REFERENCES Trip_Groups(group_id),
    FOREIGN KEY (tourist_id) REFERENCES Tourists(tourist_id)
);
GO

CREATE TABLE Trip_Realizations (
    realization_id INT IDENTITY(1,1) PRIMARY KEY,
    trip_id INT,
    actual_start DATETIME,
    actual_end DATETIME,
    guide_notes TEXT,
    FOREIGN KEY (trip_id) REFERENCES Planned_Trips(trip_id)
);
GO

CREATE TABLE Tickets (
    ticket_id INT IDENTITY(1,1) PRIMARY KEY,
    tourist_id INT,
    trip_id INT,
    purchase_date DATETIME DEFAULT GETDATE(),
    final_price DECIMAL(10,2),
    FOREIGN KEY (tourist_id) REFERENCES Tourists(tourist_id),
    FOREIGN KEY (trip_id) REFERENCES Planned_Trips(trip_id)
);
GO

CREATE TABLE Payments (
    payment_id INT IDENTITY(1,1) PRIMARY KEY,
    ticket_id INT,
    payment_method VARCHAR(30),
    payment_status VARCHAR(20),
    FOREIGN KEY (ticket_id) REFERENCES Tickets(ticket_id)
);
GO

CREATE TABLE Languages (
    language_id INT IDENTITY(1,1) PRIMARY KEY,
    language_name VARCHAR(50)
);
GO

CREATE TABLE Guide_Languages (
    guide_id INT,
    language_id INT,
    level VARCHAR(10),
    PRIMARY KEY (guide_id, language_id),
    FOREIGN KEY (guide_id) REFERENCES Guides(guide_id),
    FOREIGN KEY (language_id) REFERENCES Languages(language_id)
);
GO

CREATE TABLE Reviews (
    review_id INT IDENTITY(1,1) PRIMARY KEY,
    ticket_id INT,
    rating INT CHECK (rating BETWEEN 1 AND 5),
    comment TEXT,
    FOREIGN KEY (ticket_id) REFERENCES Tickets(ticket_id)
);
GO

CREATE TABLE Equipment (
    equipment_id INT IDENTITY(1,1) PRIMARY KEY,
    equipment_name VARCHAR(50),
    is_working BIT DEFAULT 1
);
GO

CREATE TABLE Rentals (
    rental_id INT IDENTITY(1,1) PRIMARY KEY,
    equipment_id INT NOT NULL,
    ticket_id INT NOT NULL,
    rental_date DATETIME NOT NULL,
    FOREIGN KEY (equipment_id) REFERENCES Equipment(equipment_id),
    FOREIGN KEY (ticket_id) REFERENCES Tickets(ticket_id)
);
GO

-- views

DROP VIEW IF EXISTS
    v_AvailableGuides,
    v_SalesReport,
    v_GroupComposition,
    v_GuideSkills,
    v_RouteRanking,
    v_StatusLogs,
    v_UpcomingTrips,
    v_TripsInProgress,
    v_RentalStatus,
    v_RouteRevenue;
GO

-- guides who are not currently on an active trip
CREATE VIEW v_AvailableGuides AS
SELECT g.guide_id, p.first_name, p.last_name
FROM Guides g
JOIN Persons p ON g.guide_id = p.person_id
WHERE g.guide_id NOT IN (
    SELECT pt.guide_id
    FROM Planned_Trips pt
    JOIN Trip_Realizations tr ON pt.trip_id = tr.trip_id
    WHERE GETDATE() BETWEEN tr.actual_start AND ISNULL(tr.actual_end, GETDATE())
);
GO

-- ticket sales report
CREATE VIEW v_SalesReport AS
SELECT t.ticket_id, p.first_name, p.last_name, r.route_name, t.final_price, t.purchase_date
FROM Tickets t
JOIN Tourists tur ON t.tourist_id = tur.tourist_id
JOIN Persons p ON tur.tourist_id = p.person_id
JOIN Planned_Trips pt ON t.trip_id = pt.trip_id
JOIN Routes r ON pt.route_id = r.route_id;
GO

-- group members with route name
CREATE VIEW v_GroupComposition AS
SELECT g.group_name, r.route_name, p.first_name, p.last_name
FROM Group_Members gm
JOIN Trip_Groups g ON gm.group_id = g.group_id
JOIN Tourists tur ON gm.tourist_id = tur.tourist_id
JOIN Persons p ON tur.tourist_id = p.person_id
JOIN Planned_Trips pt ON g.trip_id = pt.trip_id
JOIN Routes r ON pt.route_id = r.route_id;
GO

-- guide language skills
CREATE VIEW v_GuideSkills AS
SELECT p.first_name, p.last_name, l.language_name, gl.level
FROM Guide_Languages gl
JOIN Guides g ON gl.guide_id = g.guide_id
JOIN Persons p ON g.guide_id = p.person_id
JOIN Languages l ON gl.language_id = l.language_id;
GO

-- routes ranked by number of sold tickets
CREATE VIEW v_RouteRanking AS
SELECT r.route_name, COUNT(t.ticket_id) AS sold_tickets
FROM Routes r
LEFT JOIN Planned_Trips pt ON r.route_id = pt.route_id
LEFT JOIN Tickets t ON pt.trip_id = t.trip_id
GROUP BY r.route_id, r.route_name;
GO

-- history of guide status changes
CREATE VIEW v_StatusLogs AS
SELECT p.first_name, p.last_name, s.status_name, h.valid_from, h.valid_to
FROM Guide_Status_History h
JOIN Guides g ON h.guide_id = g.guide_id
JOIN Persons p ON g.guide_id = p.person_id
JOIN Guide_Status_Dictionary s ON h.status_id = s.status_id;
GO

-- trips planned in the next 7 days
CREATE VIEW v_UpcomingTrips AS
SELECT pt.trip_id, r.route_name, pt.planned_start,
       (SELECT COUNT(*) FROM Tickets t WHERE t.trip_id = pt.trip_id) AS registered_count
FROM Planned_Trips pt
JOIN Routes r ON pt.route_id = r.route_id
WHERE pt.planned_start BETWEEN GETDATE() AND DATEADD(DAY, 7, GETDATE());
GO

-- trips that are currently in progress
CREATE VIEW v_TripsInProgress AS
SELECT pt.trip_id, r.route_name, p.first_name AS guide_first_name, p.last_name AS guide_last_name,
       tr.actual_start, DATEDIFF(MINUTE, tr.actual_start, GETDATE()) AS duration_min
FROM Trip_Realizations tr
JOIN Planned_Trips pt ON tr.trip_id = pt.trip_id
JOIN Routes r ON pt.route_id = r.route_id
JOIN Guides g ON pt.guide_id = g.guide_id
JOIN Persons p ON g.guide_id = p.person_id
WHERE tr.actual_end IS NULL;
GO

-- current equipment rentals
CREATE VIEW v_RentalStatus AS
SELECT ren.rental_id, e.equipment_name, p.first_name, p.last_name, ren.rental_date
FROM Rentals ren
JOIN Equipment e ON ren.equipment_id = e.equipment_id
JOIN Tickets t ON ren.ticket_id = t.ticket_id
JOIN Tourists tur ON t.tourist_id = tur.tourist_id
JOIN Persons p ON tur.tourist_id = p.person_id;
GO

-- total revenue per route
CREATE VIEW v_RouteRevenue AS
SELECT r.route_name, SUM(t.final_price) AS total_revenue
FROM Routes r
JOIN Planned_Trips pt ON r.route_id = pt.route_id
JOIN Tickets t ON pt.trip_id = t.trip_id
GROUP BY r.route_id, r.route_name;
GO

-- functions

DROP FUNCTION IF EXISTS dbo.fn_FreeSeats;
GO
DROP FUNCTION IF EXISTS dbo.fn_GetCurrentPrice;
GO

-- returns free seats left on a trip
CREATE FUNCTION dbo.fn_FreeSeats (@p_trip_id INT)
RETURNS INT
AS
BEGIN
    DECLARE @v_max INT;
    DECLARE @v_taken INT;

    SELECT @v_max = max_people
    FROM Planned_Trips
    WHERE trip_id = @p_trip_id;

    SELECT @v_taken = COUNT(*)
    FROM Tickets
    WHERE trip_id = @p_trip_id;

    RETURN ISNULL(@v_max, 0) - ISNULL(@v_taken, 0);
END;
GO

-- returns the current ticket price for a route and ticket type
CREATE FUNCTION dbo.fn_GetCurrentPrice (
    @p_route_id INT,
    @p_ticket_type VARCHAR(20)
)
RETURNS DECIMAL(10,2)
AS
BEGIN
    DECLARE @v_price DECIMAL(10,2);

    SELECT TOP 1 @v_price = price
    FROM Price_History
    WHERE route_id = @p_route_id
      AND ticket_type = @p_ticket_type
      AND valid_from <= CAST(GETDATE() AS DATE)
      AND (valid_to IS NULL OR valid_to >= CAST(GETDATE() AS DATE))
    ORDER BY valid_from DESC;

    RETURN ISNULL(@v_price, 0.00);
END;
GO

-- stored procedures

DROP PROCEDURE IF EXISTS
    sp_ReserveTicket,
    sp_StartTrip,
    sp_ChangeGuideStatus,
    sp_AddRoute,
    sp_ClosePrice;
GO

-- reserve a ticket and calculate the final price
CREATE PROCEDURE sp_ReserveTicket
    @p_tourist_id INT,
    @p_trip_id INT,
    @p_ticket_type VARCHAR(20)
AS
BEGIN
    DECLARE @v_route_id INT;
    DECLARE @v_price DECIMAL(10,2);

    SELECT @v_route_id = route_id
    FROM Planned_Trips
    WHERE trip_id = @p_trip_id;

    SET @v_price = dbo.fn_GetCurrentPrice(@v_route_id, @p_ticket_type);

    INSERT INTO Tickets (tourist_id, trip_id, final_price)
    VALUES (@p_tourist_id, @p_trip_id, @v_price);
END;
GO

-- change the current status of a guide
CREATE PROCEDURE sp_ChangeGuideStatus
    @p_guide_id INT,
    @p_new_status INT
AS
BEGIN
    UPDATE Guide_Status_History
    SET valid_to = GETDATE()
    WHERE guide_id = @p_guide_id AND valid_to IS NULL;

    INSERT INTO Guide_Status_History (guide_id, status_id, valid_from)
    VALUES (@p_guide_id, @p_new_status, GETDATE());
END;
GO

-- start a trip and set the guide status to "on trip" (id = 2)
CREATE PROCEDURE sp_StartTrip
    @p_trip_id INT
AS
BEGIN
    DECLARE @v_guide_id INT;

    UPDATE Trip_Realizations
    SET actual_start = GETDATE()
    WHERE trip_id = @p_trip_id;

    SELECT @v_guide_id = guide_id
    FROM Planned_Trips
    WHERE trip_id = @p_trip_id;

    EXEC sp_ChangeGuideStatus @v_guide_id, 2;
END;
GO

-- add a new route and its first point
CREATE PROCEDURE sp_AddRoute
    @p_name VARCHAR(100),
    @p_description TEXT,
    @p_point1 VARCHAR(100)
AS
BEGIN
    DECLARE @v_last_id INT;

    INSERT INTO Routes (route_name, description) VALUES (@p_name, @p_description);
    SET @v_last_id = SCOPE_IDENTITY();

    INSERT INTO Route_Points (route_id, point_name, point_order)
    VALUES (@v_last_id, @p_point1, 1);
END;
GO

-- close the current price for a route and ticket type
CREATE PROCEDURE sp_ClosePrice
    @p_route_id INT,
    @p_type VARCHAR(20)
AS
BEGIN
    UPDATE Price_History
    SET valid_to = CAST(GETDATE() AS DATE)
    WHERE route_id = @p_route_id
      AND ticket_type = @p_type
      AND valid_to IS NULL;
END;
GO


-- triggers

DROP TRIGGER IF EXISTS
    tr_ValidateSeats,
    tr_InitRealization,
    tr_BlockPaidTicketDelete,
    tr_CheckLicense,
    tr_LogStatusChange;
GO

-- block ticket insert when there are no free seats left
CREATE TRIGGER tr_ValidateSeats ON Tickets
AFTER INSERT
AS
BEGIN
    IF EXISTS (
        SELECT 1 FROM inserted i
        WHERE dbo.fn_FreeSeats(i.trip_id) < 0
    )
    BEGIN
        RAISERROR ('No free seats left on this trip!', 16, 1);
        ROLLBACK TRANSACTION;
    END
END;
GO

-- create a realization row for every new planned trip
CREATE TRIGGER tr_InitRealization ON Planned_Trips
AFTER INSERT
AS
BEGIN
    INSERT INTO Trip_Realizations (trip_id)
    SELECT trip_id FROM inserted;
END;
GO

-- do not allow deleting a ticket that is already paid
CREATE TRIGGER tr_BlockPaidTicketDelete ON Tickets
INSTEAD OF DELETE
AS
BEGIN
    IF EXISTS (
        SELECT 1 FROM deleted d
        JOIN Payments p ON d.ticket_id = p.ticket_id
        WHERE p.payment_status = 'Paid'
    )
    BEGIN
        RAISERROR ('You cannot delete a paid ticket!', 16, 1);
    END
    ELSE
    BEGIN
        DELETE FROM Tickets WHERE ticket_id IN (SELECT ticket_id FROM deleted);
    END
END;
GO

-- validate minimum license number length
CREATE TRIGGER tr_CheckLicense ON Guides
AFTER INSERT, UPDATE
AS
BEGIN
    IF EXISTS (SELECT 1 FROM inserted WHERE LEN(license_number) < 5)
    BEGIN
        RAISERROR ('The license number is too short!', 16, 1);
        ROLLBACK TRANSACTION;
    END
END;
GO

-- close the previous active status when a new status row is inserted
CREATE TRIGGER tr_LogStatusChange ON Guide_Status_History
AFTER INSERT
AS
BEGIN
    UPDATE Guide_Status_History
    SET valid_to = GETDATE()
    FROM Guide_Status_History h
    JOIN inserted i ON h.guide_id = i.guide_id
    WHERE h.history_id != i.history_id
      AND h.valid_to IS NULL;
END;
GO


-- sample data

INSERT INTO Persons (first_name, last_name, pesel, email) VALUES
('Jan', 'Kowalski', '85010112345', 'jan.k@agency.com'),
('Anna', 'Nowak', '90020223456', 'a.nowak@agency.com'),
('Piotr', 'Zielinski', '88030334567', 'piotr.z@hmail.com'),
('Marta', 'Wojcik', '92040445678', 'marta.w@hmail.com'),
('Adam', 'Bialy', '95050556789', 'adam.b@hmail.com'),
('Ewa', 'Czarna', '80060667890', 'ewa.c@hmail.com');

INSERT INTO Employees (employee_id, hire_date, base_salary) VALUES
(1, '2020-01-10', 4500.00),
(2, '2021-03-15', 4200.00);

INSERT INTO Guides (guide_id, license_number, biography) VALUES
(1, 'LIC/001/2020', 'Specialist in the Tatra and Beskid mountains.'),
(2, 'LIC/005/2021', 'Passionate about the history of city architecture.');

INSERT INTO Tourists (tourist_id, country_of_origin, passport_number) VALUES
(3, 'Poland', 'ABC123456'),
(4, 'Germany', 'D98765432'),
(5, 'USA', 'P11223344'),
(6, 'Poland', 'G55667788');

INSERT INTO Guide_Status_Dictionary (status_id, status_name) VALUES
(1, 'Available'), (2, 'On trip'), (3, 'On leave'), (4, 'Sick');

INSERT INTO Guide_Status_History (guide_id, status_id, valid_from) VALUES
(1, 1, DATEADD(MONTH, -6, GETDATE())),
(2, 1, DATEADD(MONTH, -6, GETDATE()));

INSERT INTO Routes (route_name, description, difficulty, estimated_time_min) VALUES
('Morskie Oko', 'Classic route to the most famous lake.', 'Easy', 240),
('Old Town at Night', 'A walk through historic city streets.', 'Easy', 120),
('Orla Perc', 'Demanding high-mountain route.', 'Hard', 480);

INSERT INTO Route_Points (route_id, point_name, point_order) VALUES
(1, 'Palenica Bialczanska', 1), (1, 'Wodogrzmoty Mickiewicza', 2), (1, 'Morskie Oko Shelter', 3),
(2, 'Main Square', 1), (2, 'Barbican', 2);

INSERT INTO Price_History (route_id, ticket_type, price, valid_from) VALUES
(1, 'Standard', 50.00, DATEADD(YEAR, -1, CAST(GETDATE() AS DATE))),
(1, 'Discount', 25.00, DATEADD(YEAR, -1, CAST(GETDATE() AS DATE))),
(2, 'Standard', 30.00, DATEADD(YEAR, -1, CAST(GETDATE() AS DATE))),
(3, 'Standard', 150.00, DATEADD(YEAR, -1, CAST(GETDATE() AS DATE)));

-- trigger tr_InitRealization creates Trip_Realizations rows automatically
INSERT INTO Planned_Trips (route_id, guide_id, planned_start, max_people) VALUES
(1, 1, DATEADD(DAY, -1, GETDATE()), 20),
(2, 2, DATEADD(DAY, 2, GETDATE()), 15),
(1, 1, DATEADD(DAY, 4, GETDATE()), 20);

INSERT INTO Trip_Groups (trip_id, group_name) VALUES
(1, 'Highlanders 1'),
(2, 'Night Owls');

INSERT INTO Tickets (tourist_id, trip_id, purchase_date, final_price) VALUES
(3, 1, GETDATE(), 50.00),
(4, 1, GETDATE(), 25.00),
(5, 2, GETDATE(), 30.00),
(6, 2, GETDATE(), 30.00);

INSERT INTO Group_Members (group_id, tourist_id) VALUES
(1, 3), (1, 4), (2, 5), (2, 6);

-- update the row created by the trigger (do not insert a second realization row)
UPDATE Trip_Realizations
SET actual_start = DATEADD(HOUR, -28, GETDATE()),
    actual_end = DATEADD(HOUR, -24, GETDATE())
WHERE trip_id = 1;

INSERT INTO Payments (ticket_id, payment_method, payment_status) VALUES
(1, 'Card', 'Paid'),
(2, 'Cash', 'Paid'),
(3, 'Transfer', 'Pending');

INSERT INTO Languages (language_name) VALUES ('Polish'), ('English'), ('German');

INSERT INTO Guide_Languages (guide_id, language_id, level) VALUES
(1, 1, 'Native'), (1, 2, 'B2'),
(2, 1, 'Native'), (2, 3, 'C1');

INSERT INTO Reviews (ticket_id, rating, comment) VALUES
(1, 5, 'Great route, the guide was very helpful!'),
(2, 4, 'We walked a bit too fast.');

INSERT INTO Equipment (equipment_name, is_working) VALUES
('Audioguide 01', 1), ('Audioguide 02', 1), ('Snowshoes', 1);

INSERT INTO Rentals (equipment_id, ticket_id, rental_date) VALUES
(1, 3, DATEADD(DAY, -1, GETDATE()));
GO

-- example queries

-- free seats on trip 1
SELECT dbo.fn_FreeSeats(1) AS free_seats;

-- upcoming trips
SELECT *
FROM v_UpcomingTrips;

-- route ranking
SELECT *
FROM v_RouteRanking
ORDER BY sold_tickets DESC;

-- guide language skills
SELECT *
FROM v_GuideSkills;

-- revenue per route
SELECT *
FROM v_RouteRevenue;
GO
