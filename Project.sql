--Done
CREATE DATABASE NewProject ON PRIMARY
(
	Name ='NewProject_Data',
	FILENAME ='C:\NewProject Database\NewProject.mdf',
	SIZE = 200MB,
	MAXSIZE = 2GB,
	FILEGROWTH = 5MB
)
LOG ON
(
	NAME= 'NewProject_Log',
	FILENAME='C:\NewProject Database\NewProject.ldf',
	SIZE= 100MB,
	MAXSIZE = 1GB,
	FILEGROWTH =5MB
)
go

--Done
CREATE SCHEMA Payment;
GO
CREATE SCHEMA ProjectDetails;
GO
CREATE SCHEMA CustomerDetails;
GO
CREATE SCHEMA HumanResources;
GO

--Done 1
CREATE TABLE CustomerDetails.Clients(
				ClientID INT IDENTITY(2,2) PRIMARY KEY,
				CompanyName VARCHAR(50) NOT NULL,
				ContactPerson VARCHAR(50) NOT NULL,
				Address Varchar(100) not null,
				City VARCHAR (20) NOT NULL,
				State CHAR (50) NOT NULL,
				Zip INT NOT NULL,
				Country CHAR (50),
				PhoneNum VARCHAR (50) NOT NULL,
				CHECK (PhoneNum LIKE '[0-9][0-9]-[0-9][0-9][0-9]-[0-9][0-9][0-9][0-9]-[0-9][0-9][0-9]-[0-9][0-9][0-9]')
); 
GO
SELECT 
    name AS TriggerName,
    OBJECT_NAME(parent_id) AS TableName
FROM 
    sys.triggers
WHERE 
    parent_id = OBJECT_ID('CustomerDetails.Clients');
GO


--Done 2
CREATE TABLE HumanResources.Employee(
				EmployeeID INT IDENTITY(1,1) PRIMARY KEY,
				Title VARCHAR (100),
				CONSTRAINT CHK_Title CHECK (Title IN ('Trainee', 'Team Member', 'Team Leader', 'Project Manager', 'Senior Project Manager')),
				BillingRate INT,
				FirstName VARCHAR (50) NOT NULL,
				LastName VARCHAR (50),
				PhoneNumber VARCHAR (50) NOT NULL,
				CONSTRAINT chk_BillRate CHECK (BillingRate > 0),
				CHECK (PhoneNumber LIKE '[0-9][0-9]-[0-9][0-9][0-9]-[0-9][0-9][0-9][0-9]-[0-9][0-9][0-9]-[0-9][0-9][0-9]')
);
GO
--Done 3
CREATE TABLE ProjectDetails.Projects(
				ProjectID INT IDENTITY(100,2) PRIMARY KEY,
				ProjectName VARCHAR (50) NOT NULL,
				StartDate DATE NOT NULL,
				EndDate DATE NOT NULL,
				BillingEstimate MONEY,
				ClientID INT,
				CONSTRAINT FK_Client FOREIGN KEY (ClientID) REFERENCES CustomerDetails.Clients(ClientID),
				CONSTRAINT CHK_Date CHECK (EndDate > StartDate),
				CONSTRAINT CHK_BillEstimate CHECK (BillingEstimate > 1000))
GO
GO
--Done 5
CREATE TABLE Payment.Payments(
				PaymentID INT IDENTITY(50,2) PRIMARY KEY,
				PaymentAmount INT,
				PaymentDate Date,
				CreditCardNum INT,
				CardHoldersName VARCHAR (50),
				CreditCardExpDate DATE,
				ProjectID INT,
				FOREIGN KEY (ProjectID) REFERENCES ProjectDetails.Projects(ProjectID),
				EndDate Date,
				PaymentDue MONEY,
				PaymentMethodID INT,
				CONSTRAINT FK_PayMethod FOREIGN KEY (PaymentMethodID) REFERENCES Payment.PaymentMethod(PaymentMethodID),
				CONSTRAINT CHK_PayAmount CHECK (PaymentAmount > 0),
				CONSTRAINT CHK_PaymentDate CHECK (PaymentDate >EndDate),
				CONSTRAINT CHK_ExpDate CHECK (CreditCardExpDate > PaymentDate),
				CONSTRAINT CHK_Due CHECK (PaymentDue <= PaymentAmount)
);
GO
--Done 6
CREATE TABLE ProjectDetails.WorkCodes(
				WorkCodeID INT IDENTITY (200,5) PRIMARY KEY,
				Description VARCHAR (100))
GO

--Done 7
CREATE TABLE ProjectDetails.ExpenseDetails(
				ExpenseID INT IDENTITY(300,2) PRIMARY KEY,
				Description VARCHAR (100))
GO
--Done 8
CREATE TABLE ProjectDetails.TimeCards(
				TimeCardID INT IDENTITY (400,5) PRIMARY KEY,
				EmployeeID INT,
				FOREIGN KEY (EmployeeID) REFERENCES HumanResources.Employee(EmployeeID),
				DateIssued DATE,
				DaysWorked INT,
				ProjectID INT,
				WorkCodeID INT,
				FOREIGN KEY (ProjectID) REFERENCES ProjectDetails.Projects(ProjectID),
				BillableHours INT,
				BillingRate INT,
				TotalCost AS(BillableHours * BillingRate),
				FOREIGN KEY (WorkCodeID) REFERENCES ProjectDetails.WorkCodes(WorkCodeID),
				CONSTRAINT CHK_DaysWork CHECK (DaysWorked > 0),
				CONSTRAINT CHK_BillHours CHECK (BillableHours > 0),
				CONSTRAINT CHK_IssueDate CHECK (DateIssued > GETDATE())
				 )
GO
--Done 9
CREATE TABLE ProjectDetails.TimeCardExpense(
				TimeCardExpenseID INT IDENTITY (500,5) PRIMARY KEY,
				FOREIGN KEY(TimeCardID) REFERENCES ProjectDetails.TimeCards(TimeCardID),
				ExpenseDate DATE NOT NULL,
				ProjectID INT,
				ExpenseID INT,
				TimeCardID INT,
				ExpenseAmount MONEY,
				EndDate DATE,
				FOREIGN KEY (ProjectID) REFERENCES ProjectDetails.Projects(ProjectID),
				FOREIGN KEY(ExpenseID) REFERENCES ProjectDetails.ExpenseDetails (ExpenseID),
				CONSTRAINT CHK_ExpenseAm CHECK (ExpenseAmount > 0),
				CONSTRAINT CHK_ExDate CHECK (ExpenseDate > EndDate))
GO
--Trigger for Table 1 phone number column
CREATE TRIGGER trg_ChecksPhoneNumber_Update
ON CustomerDetails.Clients
AFTER UPDATE
AS
BEGIN
    IF EXISTS (
        SELECT 1
        FROM inserted
        WHERE PhoneNum NOT LIKE '[0-9][0-9]-[0-9][0-9][0-9]-[0-9][0-9][0-9][0-9]-[0-9][0-9][0-9]-[0-9][0-9][0-9]'
    )
    BEGIN
        RAISERROR ('Invalid phone number format. Please use XX-XXX-XXXX-XXX-XXX.', 16, 1);
        ROLLBACK;
    END
END;
GO
--Table 5 columns in the payment table
CREATE TRIGGER trg_CheckPayments_Update
ON Payment.Payments
AFTER UPDATE
AS
BEGIN
    IF EXISTS (
        SELECT 1
        FROM inserted
        WHERE PaymentAmount <= 0
           OR PaymentDate <= EndDate
           OR CreditCardExpDate <= PaymentDate
           OR PaymentDue > PaymentAmount
    )
    BEGIN
        RAISERROR ('Constraint violation: Ensure PaymentAmount > 0, PaymentDate > EndDate, CreditCardExpDate > PaymentDate, and PaymentDue <= PaymentAmount.', 16, 1);
        ROLLBACK;
    END
END;
GO

--For table 9 connecting 2 columns from different schemas.
CREATE TRIGGER trg_SetBillingRate_Insert
ON ProjectDetails.TimeCards
AFTER INSERT
AS
BEGIN
    UPDATE tc
    SET tc.BillingRate = e.BillingRate
    FROM ProjectDetails.TimeCards tc
    JOIN inserted i ON tc.TimeCardID = i.TimeCardID
    JOIN HumanResources.Employee e ON i.EmployeeID = e.EmployeeID;
END;
GO
--Done Table 1
INSERT INTO CustomerDetails.Clients 
(CompanyName, ContactPerson, Address, City, State, Zip, Country, PhoneNum)
VALUES
('Tech Solutions', 'John Doe', '1234 Elm Street', 'Springfield', 'IL', 62704, 'USA', '12-345-6789-012-345'),
('Global Enterprises', 'Jane Smith', '5678 Oak Avenue', 'Columbus', 'OH', 43215, 'USA', '23-456-7890-123-456'),
('Creative Works', 'Emily Johnson', '9101 Maple Lane', 'Austin', 'TX', 73301, 'USA', '34-567-8901-234-567'),
('Innovatech', 'Michael Brown', '2345 Birch Road', 'San Francisco', 'CA', 94102, 'USA', '45-678-9012-345-678'),
('Bright Future Co.', 'Sarah Davis', '6789 Pine Street', 'Boston', 'MA', 02108, 'USA', '56-789-0123-456-789'),
('TechnoCore', 'David Wilson', '8901 Cedar Boulevard', 'Chicago', 'IL', 60601, 'USA', '67-890-1234-567-890'),
('NextGen Innovations', 'Olivia Miller', '1234 Walnut Avenue', 'Dallas', 'TX', 75201, 'USA', '78-901-2345-678-901'),
('Visionary Tech', 'James Taylor', '5678 Ash Lane', 'Seattle', 'WA', 98101, 'USA', '89-012-3456-789-012'),
('Pioneer Systems', 'Sophia Anderson', '9101 Chestnut Street', 'Denver', 'CO', 80202, 'USA', '90-123-4567-890-123'),
('Quantum Solutions', 'Isabella Martinez', '2345 Redwood Road', 'Miami', 'FL', 33101, 'USA', '01-234-5678-901-234'),
('Global Solutions Ltd', 'William White', '4567 Elm Avenue', 'London', 'ENG', 56789, 'UK', '23-456-7890-123-456'),
('Tech Minds', 'Charlotte Harris', '6789 Oak Street', 'Manchester', 'ENG', 12345, 'UK', '34-567-8901-234-567'),
('Digital Innovations', 'Henry Clark', '8901 Maple Lane', 'Birmingham', 'ENG', 67890, 'UK', '45-678-9012-345-678'),
('Future Tech', 'Mia Lewis', '1234 Pine Road', 'Liverpool', 'ENG', 23456, 'UK', '56-789-0123-456-789'),
('Smart Systems', 'Noah Walker', '3456 Cedar Street', 'Edinburgh', 'SCT', 34567, 'UK', '67-890-1234-567-890'),
('Global Ventures', 'Emma Hall', '7890 Walnut Lane', 'Glasgow', 'SCT', 45678, 'UK', '78-901-2345-678-901'),
('Technovate', 'Lucas Scott', '1234 Beech Road', 'Toronto', 'ON', 12345, 'CAN', '89-012-3456-789-012'),
('InnoTech', 'Ava Young', '2345 Maple Avenue', 'Vancouver', 'BC', 67890, 'CAN', '90-123-4567-890-123'),
('BrightPath', 'Liam King', '3456 Cedar Lane', 'Montreal', 'QC', 23456, 'CAN', '01-234-5678-901-234'),
('Quantum Leap', 'Olivia Adams', '4567 Oak Street', 'Calgary', 'AB', 34567, 'CAN', '23-456-7890-123-456'),
('NextWave Technologies', 'Mason Gonzalez', '7890 Pine Road', 'Sydney', 'NSW', 2000, 'AUS', '34-567-8901-234-567'),
('Innovative Solutions', 'Lucas Martinez', '2345 Birch Avenue', 'Melbourne', 'VIC', 3000, 'AUS', '45-678-9012-345-678'),
('TechSavvy', 'Sophia Moore', '3456 Redwood Street', 'Brisbane', 'QLD', 4000, 'AUS', '56-789-0123-456-789'),
('Visionary Minds', 'Isabella Thompson', '4567 Elm Lane', 'Perth', 'WA', 6000, 'AUS', '67-890-1234-567-890'),
('Innovatech Japan', 'Yuto Tanaka', '1234 Cedar Road', 'Tokyo', 'TYO', 1000001, 'JPN', '78-901-2345-678-901'),
('Tech Solutions Japan', 'Haruto Sato', '5678 Maple Avenue', 'Osaka', 'OSA', 5300001, 'JPN', '89-012-3456-789-012'),
('Global Innovators', 'Sakura Yamamoto', '9101 Oak Street', 'Kyoto', 'KYT', 6000001, 'JPN', '90-123-4567-890-123'),
('Future Visions', 'Riku Nakamura', '2345 Pine Lane', 'Yokohama', 'YOK', 2200001, 'JPN', '01-234-5678-901-234'),
('Smart Innovations', 'Ethan Lee', '3456 Cedar Road', 'Seoul', 'SEO', 04524, 'KOR', '23-456-7890-123-456'),
('Tech Future', 'Mia Kim', '7890 Oak Avenue', 'Busan', 'BSN', 48058, 'KOR', '34-567-8901-234-567');

GO
SELECT * FROM CustomerDetails.Clients
SELECT * FROM HumanResources.Employee
SELECT * FROM ProjectDetails.Projects
SELECT * FROM Payment.PaymentMethod
SELECT * FROM ProjectDetails.ExpenseDetails
SELECT * FROM Payment.Payments
SELECT * FROM ProjectDetails.WorkCodes
Select * from ProjectDetails.TimeCards
SELECT * FROM ProjectDetails.TimeCardExpense

GO
--Done Table 2
INSERT INTO HumanResources.Employee 
(Title, BillingRate, FirstName, LastName, PhoneNumber)
VALUES
('Trainee', 50, 'Alex', 'Reed', '12-345-6789-012-345'),
('Trainee', 55, 'Ella', 'Cook', '23-456-7890-123-456'),
('Trainee', 52, 'Mia', 'Parker', '34-567-8901-234-567'),
('Trainee', 54, 'Ethan', 'Cooper', '45-678-9012-345-678'),
('Trainee', 53, 'Liam', 'Ward', '56-789-0123-456-789'),
('Team Member', 75, 'Ava', 'Price', '67-890-1234-567-890'),
('Team Member', 78, 'Noah', 'Bell', '78-901-2345-678-901'),
('Team Member', 77, 'Sophia', 'Morgan', '89-012-3456-789-012'),
('Team Member', 76, 'Oliver', 'Fox', '90-123-4567-890-123'),
('Team Member', 80, 'Isabella', 'James', '01-234-5678-901-234'),
('Team Leader', 100, 'Mason', 'White', '23-456-7890-123-456'),
('Team Leader', 105, 'Grace', 'Allen', '34-567-8901-234-567'),
('Team Leader', 102, 'Benjamin', 'Baker', '45-678-9012-345-678'),
('Team Leader', 104, 'Chloe', 'Green', '56-789-0123-456-789'),
('Team Leader', 103, 'Lucas', 'Hall', '67-890-1234-567-890'),
('Project Manager', 120, 'Aiden', 'Adams', '78-901-2345-678-901'),
('Project Manager', 125, 'Emily', 'Norris', '89-012-3456-789-012'),
('Project Manager', 122, 'Zoe', 'Wood', '90-123-4567-890-123'),
('Project Manager', 123, 'James', 'Turner', '01-234-5678-901-234'),
('Project Manager', 128, 'Mia', 'Phillips', '23-456-7890-123-456'),
('Senior Project Manager', 150, 'Henry', 'Reynolds', '34-567-8901-234-567'),
('Senior Project Manager', 155, 'Ella', 'Hunter', '45-678-9012-345-678'),
('Senior Project Manager', 152, 'Oliver', 'Bennett', '56-789-0123-456-789'),
('Senior Project Manager', 154, 'Charlotte', 'Morris', '67-890-1234-567-890'),
('Senior Project Manager', 153, 'Jack', 'Jenkins', '78-901-2345-678-901'),
('Trainee', 50, 'Mason', 'Garcia', '12-345-6789-012-345'),
('Trainee', 55, 'Lily', 'Martinez', '23-456-7890-123-456'),
('Trainee', 52, 'Owen', 'Lopez', '34-567-8901-234-567'),
('Trainee', 54, 'Ava', 'Gonzalez', '45-678-9012-345-678'),
('Trainee', 53, 'Noah', 'Perez', '56-789-0123-456-789'),
('Team Member', 75, 'Sophia', 'Taylor', '67-890-1234-567-890'),
('Team Member', 78, 'James', 'Anderson', '78-901-2345-678-901'),
('Team Member', 77, 'Ella', 'Miller', '89-012-3456-789-012'),
('Team Member', 76, 'Benjamin', 'Jackson', '90-123-4567-890-123'),
('Team Member', 80, 'Isabella', 'White', '01-234-5678-901-234'),
('Team Leader', 100, 'Grace', 'Harris', '23-456-7890-123-456'),
('Team Leader', 105, 'Lucas', 'Clark', '34-567-8901-234-567'),
('Team Leader', 102, 'Liam', 'Walker', '45-678-9012-345-678'),
('Team Leader', 104, 'Emma', 'Hall', '56-789-0123-456-789'),
('Team Leader', 103, 'Jack', 'King', '67-890-1234-567-890');

GO
--Done Table 3
INSERT INTO ProjectDetails.Projects 
(ProjectName, StartDate, EndDate, BillingEstimate, ClientID)
VALUES
('Website Redesign', '2023-01-01', '2023-03-01', 15000.00, 2),
('Mobile App Development', '2023-02-15', '2023-06-15', 25000.00, 4),
('Cloud Migration', '2023-03-10', '2023-05-30', 18000.00, 6),
('Data Analysis Platform', '2023-04-05', '2023-07-20', 22000.00, 8),
('E-commerce Website', '2023-05-01', '2023-08-01', 30000.00, 10),
('CRM Implementation', '2023-06-01', '2023-09-10', 28000.00, 12),
('SEO Optimization', '2023-07-01', '2023-08-15', 12000.00, 14),
('Custom Software Development', '2023-08-01', '2023-12-01', 45000.00, 16),
('IT Infrastructure Upgrade', '2023-09-01', '2023-11-30', 35000.00, 18),
('Cybersecurity Enhancement', '2023-10-01', '2023-12-15', 20000.00, 20),
('AI Integration', '2023-11-01', '2024-02-01', 40000.00, 22),
('Blockchain Implementation', '2023-12-01', '2024-03-01', 38000.00, 24),
('Machine Learning Model', '2024-01-01', '2024-04-01', 27000.00, 26),
('Database Optimization', '2024-02-01', '2024-04-15', 16000.00, 28),
('Cloud-Based ERP System', '2024-03-01', '2024-06-01', 50000.00, 30),
('Virtual Reality App', '2024-04-01', '2024-07-01', 45000.00, 32),
('Customer Portal Development', '2024-05-01', '2024-08-01', 30000.00, 34),
('API Development', '2024-06-01', '2024-07-20', 14000.00, 36),
('Data Warehouse Setup', '2024-07-01', '2024-10-01', 37000.00, 38),
('Predictive Analytics Tool', '2024-08-01', '2024-11-01', 41000.00, 40),
('Supply Chain Management System', '2024-09-01', '2024-12-01', 45000.00, 42),
('HR Management Software', '2024-10-01', '2025-01-01', 33000.00, 44),
('Marketing Automation Platform', '2024-11-01', '2025-02-01', 28000.00, 46),
('E-Learning Platform', '2024-12-01', '2025-03-01', 42000.00, 48),
('IoT Integration', '2025-01-01', '2025-04-01', 46000.00, 50),
('Big Data Analytics', '2025-02-01', '2025-05-01', 49000.00, 52),
('Mobile Payment System', '2025-03-01', '2025-06-01', 35000.00, 54),
('Content Management System', '2025-04-01', '2025-07-01', 30000.00, 56),
('Financial Management Software', '2025-05-01', '2025-08-01', 41000.00, 58),
('Business Intelligence Tool', '2025-06-01', '2025-09-01', 37000.00, 60),
('Augmented Reality App', '2025-07-01', '2025-10-01', 47000.00, 42),
('Customer Data Platform', '2025-08-01', '2025-11-01', 33000.00, 14),
('Inventory Management System', '2025-09-01', '2025-12-01', 29000.00, 36),
('Chatbot Development', '2025-10-01', '2026-01-01', 32000.00, 48),
('Video Streaming Platform', '2025-11-01', '2026-02-01', 50000.00, 10),
('Social Media Integration', '2025-12-01', '2026-03-01', 27000.00, 12),
('Virtual Assistant Tool', '2026-01-01', '2026-04-01', 40000.00, 54),
('Customer Feedback System', '2026-02-01', '2026-05-01', 22000.00, 36),
('Data Security Platform', '2026-03-01', '2026-06-01', 37000.00, 48),
('Collaboration Platform', '2026-04-01', '2026-07-01', 43000.00, 20);

GO
--Done Table 4
INSERT INTO Payment.PaymentMethod (Description)
VALUES
('Credit Card - Visa'),
('Credit Card - MasterCard'),
('Credit Card - American Express'),
('Credit Card - Discover'),
('Debit Card'),
('PayPal'),
('Bank Transfer'),
('Direct Debit'),
('Cryptocurrency - Bitcoin'),
('Cryptocurrency - Ethereum'),
('Cryptocurrency - Litecoin'),
('Cryptocurrency - Ripple'),
('Apple Pay'),
('Google Pay'),
('Samsung Pay'),
('Amazon Pay'),
('Wire Transfer'),
('Cheque'),
('Prepaid Card'),
('Gift Card');
GO

-- Done Table 5
INSERT INTO Payment.Payments 
(PaymentAmount, PaymentDate, CreditCardNum, CardHoldersName, CreditCardExpDate, ProjectID, EndDate, PaymentDue, PaymentMethodID)
VALUES
(1500, '2024-01-15', 12345678, 'Alice Johnson', '2026-01-01', 100, '2023-12-12', 1300.00, 1000),
(2000, '2024-02-20', 23456789, 'Bob Smith', '2025-02-01', 102, '2023-11-01', 1000.00, 1001),
(2500, '2024-03-10', 34567890, 'Carol Williams', '2026-03-01', 104, '2024-01-01', 1500.00, 1002),
(3000, '2024-04-05', 45678901, 'David Brown', '2025-04-01', 106, '2024-01-01', 2500.00, 1003),
(3500, '2024-05-15', 56789012, 'Eva Davis', '2026-05-01', 108, '2024-01-08', 3000.00, 1004),
(1500, '2024-06-10', 67890123, 'Frank Wilson', '2025-06-01', 110, '2024-02-01', 1000.00, 1005),
(2000, '2024-07-15', 78901234, 'Grace Miller', '2026-07-01', 112, '2023-07-01', 1000.00, 1006),
(2500, '2024-08-20', 89012345, 'Henry Taylor', '2025-08-01', 114, '2023-12-01', 1500.00, 1007),
(3000, '2024-09-25', 90123456, 'Ivy Anderson', '2026-09-01', 116, '2024-02-14', 2000.00, 1008),
(3500, '2024-10-30', 01239867, 'Jack Martinez', '2025-10-01', 118, '2023-12-20', 2500.00, 1009),
(1500, '2024-11-15', 12340978, 'Karen White', '2026-11-01', 120, '2024-03-15', 1000.00, 1010),
(2000, '2024-12-20', 23444789, 'Leo Harris', '2025-12-01', 122, '2024-09-11', 1000.00, 1011),
(2500, '2025-01-25', 34500890, 'Mia Clark', '2026-01-01', 124, '2024-01-29', 2000.00, 1012),
(3000, '2025-02-15', 45677901, 'Noah Lewis', '2027-02-01', 126, '2023-12-01', 3000.00, 1013),
(3500, '2025-03-10', 56769012, 'Olivia Walker', '2026-03-01', 128, '2023-12-21', 3000.00, 1014),
(1500, '2025-04-20', 67899123, 'Paul Hall', '2026-04-01', 130, '2024-04-01', 1000.00, 1015),
(2000, '2025-05-15', 78990234, 'Quinn Scott', '2026-05-01', 132, '2024-02-01', 1000.00, 1016),
(2500, '2025-06-25', 89112345, 'Riley Young', '2027-06-01', 134, '2023-10-09', 2000.00, 1017),
(3000, '2025-07-30', 90003456, 'Sam King', '2026-07-01', 136, '2024-07-01', 3000.00, 1018),
(3500, '2025-08-20', 01224567, 'Tina Adams', '2026-08-01', 138, '2024-08-01', 3000.00, 1019),
(1500, '2025-09-15', 12997812, 'Ursula Gonzalez', '2026-09-01', 140, '2024-09-01', 1000.00, 1010),
(2000, '2025-10-20', 23666723, 'Victor Martinez', '2026-10-01', 142, '2023-10-01', 1000.00, 1009),
(2500, '2025-11-15', 34755034, 'Wendy Moore', '2026-11-01', 144, '2024-11-01', 2500.00, 1008),
(3000, '2025-12-10', 45880145, 'Xander Thompson', '2026-12-01', 146, '2023-12-01', 2300.00, 1003),
(3500, '2026-01-20', 56782256, 'Yara Lee', '2027-01-01', 148, '2023-01-01', 3100.00, 1004),
(1500, '2026-02-15', 67890367, 'Zachary Martinez', '2027-02-01', 150, '2024-10-01', 1300.00, 1015),
(2000, '2026-03-20', 78923478, 'Aiden Taylor', '2028-03-01', 152, '2024-03-01', 1400.00, 1016),
(2500, '2026-04-25', 81234589, 'Bella Johnson', '2028-04-01', 154, '2023-11-01', 2100.00, 1017),
(3000, '2026-05-15', 90125690, 'Cameron Brown', '2028-05-01', 156, '2023-05-21', 2000.00, 1018),
(3500, '2026-06-10', 01234501, 'Daisy Davis', '2028-06-01', 158, '2024-05-01', 3200.00, 1019),
(1500, '2026-07-20', 12567812, 'Elijah Wilson', '2027-07-01', 160, '2024-07-19', 1300.00, 1000),
(2000, '2026-08-25', 23456923, 'Fiona Miller', '2028-08-01', 162, '2024-03-19', 1900.00, 1001),
(2500, '2026-09-15', 34589034, 'George Taylor', '2028-09-01', 164, '2024-09-30', 2100.00, 1002),
(3000, '2026-10-20', 45690145, 'Hannah Anderson', '2028-10-01', 166, '2024-10-14', 2800.00, 1003),
(3500, '2026-11-15', 56901256, 'Ian Martinez', '2028-11-01', 168, '2023-11-01', 2600.00, 1004),
(1500, '2026-12-15', 67892367, 'Jasmine Garcia', '2028-12-01', 170, '2023-12-09', 1500.00, 1005),
(2000, '2024-05-20', 78901278, 'Kelsey Martinez', '2027-01-01', 172, '2024-01-01', 2000.00, 1006),
(2500, '2026-02-27', 89234589, 'Liam Rodriguez', '2027-02-01', 174, '2024-02-01', 1700.00, 1007),
(3000, '2025-03-12', 90345690, 'Maya Walker', '2027-03-01', 176, '2023-11-01', 2900.00, 1018),
(3500, '2025-04-09', 01236701, 'Nina Harris', '2027-04-01', 178, '2023-12-21', 3500.00, 1019),
(1500, '2025-05-13', 12345812, 'Oscar Lee', '2027-05-01', 160, '2024-05-12', 1200.00, 1010),
(2000, '2025-06-17', 23678923, 'Paige Perez', '2027-06-01', 122, '2023-12-23', 1900.00, 1011),
(2500, '2025-07-16', 34569034, 'Quincy Rivera', '2027-07-01', 144, '2024-07-15', 2200.00, 1012),
(3000, '2025-08-11', 45678145, 'Riley Cooper', '2027-08-01', 116, '2024-08-07', 2900.00, 1013),
(3500, '2025-09-21', 12569012, 'Samantha Sanders', '2027-09-01', 158, '2023-09-01', 3100.00, 1015);

GO
-- DoneTable 6
INSERT INTO ProjectDetails.WorkCodes (Description)
VALUES
    ('Coding'),
    ('Testing'),
    ('Design'),
    ('Documentation'),
    ('Meetings'),
    ('Debugging'),
    ('Deployment'),
    ('Requirements Gathering'),
    ('Refactoring'),
    ('Cleanup Services'),
    ('UI/UX'),
    ('Clothing'),
    ('Integration'),
    ('Performance Tuning'),
    ('Security Audits'),
    ('Training Sessions'),
    ('Data Migration'),
    ('Feature Development'),
    ('Snacks Making'),
    ('Project Planning'),
    ('User Support'),
    ('Infrastructure Setup'),
    ('Release Management'),
    ('Quality Assurance'),
    ('Technical Writing'),
    ('DevOps'),
    ('Automated Testing'),
    ('Legacy System Maintenance'),
    ('Code Cleanup'),
    ('Emergency Hotfixes'),
    ('Innovation'),
    ('User Experience Research'),
    ('Data Analysis'),
    ('Agile Ceremonies');
	GO
--Done Table 7
INSERT INTO ProjectDetails.ExpenseDetails (Description)
VALUES
    ('Office Supplies'),
    ('Travel Expenses'),
    ('Software Licenses'),
    ('Marketing Campaigns'),
    ('Equipment Maintenance'),
    ('Consulting Fees'),
    ('Training Costs'),
    ('Utilities'),
    ('Rent'),
    ('Employee Benefits'),
    ('Advertising Costs'),
    ('Web Hosting Fees'),
    ('Printing Services'),
    ('Conference Fees'),
    ('Insurance Premiums'),
    ('Professional Memberships'),
    ('Shipping and Freight'),
    ('Meal Reimbursements'),
    ('Telecommunications'),
    ('Office Furniture'),
    ('Repair Services'),
    ('Subscriptions'),
    ('Tax Payments'),
    ('Client Entertainment'),
    ('Research Expenses'),
    ('Charitable Donations'),
    ('Legal Fees'),
    ('Office Cleaning'),
    ('Travel Insurance'),
    ('Employee Wellness Programs'),
    ('Coffee Supplies'),
    ('Parking Fees'),
    ('Promotional Items');
GO
--Done Table 8
INSERT INTO ProjectDetails.TimeCards (EmployeeID, DateIssued, DaysWorked, ProjectID, WorkCodeID, BillableHours, BillingRate)
VALUES
(1, '2024-12-12', 5, 100, 200, 50, 50),
(2, '2024-12-14', 3, 102, 205, 55, 60),
(3, '2024-12-16', 4, 104, 210, 52, 55),
(4, '2024-12-17', 2, 106, 215, 54, 70),
(5, '2024-12-19', 5, 108, 220, 53, 65),
(6, '2024-12-20', 3, 110, 225, 78, 75),
(7, '2024-12-22', 4, 112, 230, 75, 80),
(8, '2024-12-23', 2, 114, 235, 77, 55),
(9, '2024-12-25', 5, 116, 240, 76, 60),
(10, '2024-12-27', 3, 118, 245, 80, 50),
(11, '2024-12-28', 4, 120, 250, 100, 65),
(12, '2024-12-29', 2, 122, 255, 105, 70),
(13, '2024-12-30', 5, 124, 260, 102, 75),
(14, '2024-09-21', 3, 126, 265, 104, 80),
(15, '2024-09-22', 4, 128, 270, 103, 55),
(16, '2024-09-23', 2, 130, 275, 120, 60),
(17, '2024-09-24', 5, 132, 280, 125, 50),
(18, '2024-09-25', 3, 134, 285, 122, 65),
(19, '2024-09-26', 4, 136, 290, 123, 70),
(20, '2024-09-27', 2, 138, 295, 128, 75),
(21, '2024-09-28', 5, 140, 300, 150, 80),
(22, '2024-09-29', 3, 142, 305, 155, 55),
(23, '2024-09-30', 4, 144, 310, 152, 60),
(24, '2024-10-01', 2, 146, 315, 154, 50),
(25, '2024-10-02', 5, 148, 320, 54, 65),
(26, '2024-10-03', 3, 150, 325, 78, 70),
(27, '2024-10-04', 4, 152, 330, 53, 75),
(28, '2024-10-05', 2, 154, 335, 75, 80),
(29, '2024-10-06', 5, 156, 340, 52, 55),
(30, '2024-10-07', 3, 158, 345, 77, 60),
(31, '2024-10-08', 4, 160, 350, 76, 50),
(32, '2024-10-09', 2, 162, 355, 105, 65),
(33, '2024-10-10', 5, 164, 360, 102, 70),
(34, '2024-10-11', 3, 166, 365, 122, 75),
(35, '2024-10-12', 4, 168, 300, 123, 80),
(36, '2024-10-13', 2, 170, 200, 103, 55),
(37, '2024-10-14', 5, 172, 215, 80, 60),
(38, '2024-10-15', 3, 174, 285, 128, 50),
(39, '2024-10-16', 4, 176, 325, 104, 65),
(40, '2024-12-11', 5, 178, 295, 152, 70);

GO
--Table 9
INSERT INTO ProjectDetails.TimeCardExpense(ExpenseDate, ProjectID, ExpenseID, TimeCardID, ExpenseAmount, EndDate)
VALUES
('2024-08-14', 100, 300, 400, 120.50, '2024-05-13'),
('2024-08-15', 102, 302, 405, 230.75, '2024-06-14'),
('2024-08-16', 104, 304, 410, 180.00, '2024-01-15'),
('2024-08-17', 106, 306, 415, 250.10, '2024-04-16'),
('2024-08-18', 108, 308, 420, 310.25, '2024-03-17'),
('2024-08-19', 110, 310, 425, 100.90, '2024-02-18'),
('2024-08-20', 112, 312, 430, 145.65, '2024-05-19'),
('2024-08-21', 114, 314, 435, 210.80, '2023-12-20'),
('2024-08-22', 116, 316, 440, 275.45, '2023-11-21'),
('2024-08-23', 118, 318, 445, 320.00, '2024-02-22'),
('2024-08-24', 120, 320, 450, 185.50, '2024-01-23'),
('2024-08-25', 122, 322, 455, 195.75, '2024-03-24'),
('2024-08-26', 124, 324, 460, 160.00, '2024-01-25'),
('2024-08-27', 126, 326, 465, 225.10, '2023-10-26'),
('2024-08-28', 128, 328, 470, 290.25, '2024-04-27'),
('2024-08-29', 130, 330, 475, 100.90, '2024-02-28'),
('2024-08-30', 132, 332, 480, 145.65, '2024-02-29'),
('2024-08-31', 134, 334, 485, 210.80, '2024-05-30'),
('2024-09-01', 136, 336, 490, 275.45, '2023-12-31'),
('2024-09-02', 138, 338, 495, 320.00, '2023-09-01'),
('2024-09-03', 140, 340, 500, 185.50, '2023-12-02'),
('2024-09-04', 142, 342, 505, 195.75, '2023-12-03'),
('2024-09-05', 144, 344, 510, 160.00, '2024-05-04'),
('2024-09-06', 146, 346, 515, 225.10, '2024-02-05'),
('2024-09-07', 148, 348, 520, 290.25, '2023-09-06'),
('2024-09-08', 150, 350, 525, 100.90, '2023-10-07'),
('2024-09-09', 152, 352, 530, 145.65, '2023-12-08'),
('2024-09-10', 154, 354, 535, 210.80, '2023-09-09'),
('2024-09-11', 156, 356, 540, 275.45, '2024-02-10'),
('2024-09-12', 158, 358, 545, 320.00, '2024-03-11'),
('2024-09-13', 160, 360, 550, 185.50, '2024-04-12'),
('2024-09-14', 162, 362, 555, 195.75, '2024-05-13'),
('2024-09-15', 164, 364, 560, 160.00, '2023-09-14'),
('2024-09-16', 166, 350, 565, 225.10, '2023-12-15'),
('2024-09-17', 168, 360, 570, 290.25, '2024-01-16'),
('2024-09-18', 170, 300, 575, 100.90, '2023-12-17'),
('2024-09-19', 172, 310, 580, 145.65, '2023-11-18'),
('2024-09-20', 174, 348, 585, 210.80, '2024-03-19'),
('2024-09-21', 176, 352, 590, 275.45, '2024-02-20'),
('2024-09-22', 178, 312, 595, 320.00, '2023-12-21'),
('2024-09-23', 100, 322, 500, 185.50, '2024-02-22'),
('2024-09-24', 110, 316, 505, 195.75, '2023-12-23'),
('2024-09-25', 130, 342, 520, 160.00, '2024-03-24'),
('2024-09-26', 150, 302, 435, 225.10, '2024-02-25'),
('2024-09-27', 168, 308, 465, 290.25, '2024-01-26'),
('2024-09-28', 146, 314, 545, 100.90, '2024-07-27'),
('2024-09-29', 142, 332, 530, 145.65, '2024-08-28'),
('2024-09-30', 104, 326, 400, 210.80, '2024-02-29'),
('2024-10-01', 106, 304, 420, 275.45, '2024-04-30');
GO
-- No. 6 Done
SELECT C.ClientID,C.CompanyName,C.ContactPerson,C.Address,C.City,C.Zip,C.PhoneNum,C.Country,P.ClientID,PY.PaymentAmount,PY.PaymentDate,
PY.CreditCardNum,PY.PaymentDue,PY.CreditCardExpDate
FROM CustomerDetails.Clients AS C
JOIN ProjectDetails.Projects AS P
ON C.ClientID=P.ClientID
JOIN Payment.Payments AS PY
ON P.ProjectID=PY.ProjectID
/* 1. Open SSMS and connect to your SQL Server instance.
	2. Write Your Query: Open a new query window and write the query whose results you want to save.
	3. Execute the Query and Save Results:
Instead of clicking the "Execute" button, use the menu at the top and go to Query > Results To > Results to File
(or press Ctrl + Shift + F).
	4. Execute the query (F5 or click "Execute").
	5. A "Save Results" dialog will appear, allowing you to choose where to save the file.
	Specify the file name and location (e.g., C:\Path\YourFileName.txt).
	6. Click Save to store the results in a text file. */
GO

-- No. 7 Creating indexes --Index 1 Done
CREATE CLUSTERED INDEX IX_TableName_ColumnName
ON TableName (ColumnName);

CREATE INDEX IDX_EmployeeTimeCard
ON ProjectDetails.TimeCards (EmployeeID)
INCLUDE (TimeCardID, ProjectID, WorkCodeID, DateIssued, DaysWorked, TotalCost, BillableHours);
SELECT 
    tc.TimeCardID, 
    tc.ProjectID, 
    tc.WorkCodeID, 
    tc.DateIssued,
	tc.BillableHours,
	tc.TotalCost,
	tc.DaysWorked,
	e.FirstName +' '+ LastName AS Name
FROM 
    ProjectDetails.TimeCards tc
JOIN 
    HumanResources.Employee e ON tc.EmployeeID = e.EmployeeID
--Index 2
CREATE INDEX IDX_Employee_Exp_Details
ON HumanResources.Employee(FirstName);
SELECT 
	e.FirstName+ ' '+ LastName AS FullName,
	e.Title,
	t.TimeCardID,
	ex.ExpenseID,
	ex.Description
FROM HumanResources.Employee e
JOIN ProjectDetails.TimeCards t ON e.EmployeeID=t.EmployeeID
JOIN ProjectDetails.TimeCardExpense tx ON t.TimeCardID=tx.TimeCardID
JOIN ProjectDetails.ExpenseDetails ex ON tx.ExpenseID=ex.ExpenseID
WHERE t.TimeCardID BETWEEN 400 AND 450;

--Index 3
CREATE INDEX IDX_EmployeesProjects
ON HumanResources.Employee(EmployeeID);
SELECT
	E.FirstName + ' ' + LastName AS Name,
	E.Title,
	p.ProjectName,
	t.TimeCardID
FROM HumanResources.Employee E
JOIN ProjectDetails.TimeCards t
ON t.EmployeeID=E.EmployeeID
JOIN ProjectDetails.Projects p
ON p.ProjectID=t.ProjectID;

--Index 4
CREATE INDEX IDX_CurrentMonthProjects
ON ProjectDetails.Projects(EndDate);
SELECT 
	ProjectID,
	ProjectName,
	StartDate,
	EndDate
FROM 
    ProjectDetails.Projects
WHERE 
    YEAR(EndDate) = 2024 
    AND MONTH(EndDate) = 8;
GO
--No 8
SELECT p.ProjectID AS 'Project ID',
	p.ProjectName AS 'Project Name',
	e.FirstName +' '+ LastName 'Employee Name',
	e.Title AS 'Employee Title'
FROM ProjectDetails.Projects p 
JOIN ProjectDetails.TimeCards t ON p.ProjectID=t.ProjectID
JOIN HumanResources.Employee e ON e.EmployeeID=t.EmployeeID
GO
--No 9 Done Creating Login roles
-- Admin Role
USE NewProject
CREATE LOGIN Sam WITH PASSWORD = 'SamLog@911419';
CREATE USER Sam FOR LOGIN Sam
ALTER ROLE db_owner ADD MEMBER Sam;
GO

-- Check if 'sam' is a member of db_owner role
SELECT USER_NAME() AS UserName, dp.name AS RoleName
FROM sys.database_role_members drm
JOIN sys.database_principals dp ON drm.role_principal_id = dp.principal_id
WHERE USER_NAME() = 'John';
GO

--User 1
USE	NewProject
CREATE LOGIN John WITH PASSWORD = 'JohnPaul419$';
GO
-- Step 2: Create a database user in the target database
CREATE USER John FOR LOGIN John;
-- Step 3: Grant read/write permissions
ALTER ROLE db_datareader ADD MEMBER John;
GO

ALTER ROLE db_datawriter ADD MEMBER John;
GO

--User 2
CREATE LOGIN Samantha WITH PASSWORD = 'SammyNat9119%';
-- Step 2: Create a database user in the target database
CREATE USER Samantha FOR LOGIN Samantha;
-- Step 3: Grant read/write permissions
ALTER ROLE db_datareader ADD MEMBER Samantha;
GO

ALTER ROLE db_datawriter ADD MEMBER Samantha;
GO

--No 10 Creating column based encryption
USE NewProject;
CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'KenDorathy911419';
CREATE CERTIFICATE MyServerCert
WITH SUBJECT = 'My TDE Certificate';
--Symmetric key
CREATE SYMMETRIC KEY MySymKey
WITH ALGORITHM = AES_256
ENCRYPTION BY CERTIFICATE MyServerCert;
GO

-- Open the symmetric key
OPEN SYMMETRIC KEY MySymKey
    DECRYPTION BY CERTIFICATE MyServerCert;

-- Update patient and doctor data to be encrypted
UPDATE CustomerDetails.Clients
SET ContactPerson = ENCRYPTBYKEY(KEY_GUID('MySymKey'), CAST(ContactPerson AS NVARCHAR(50)));

UPDATE Payment.Payments
SET CreditCardNum = ENCRYPTBYKEY(KEY_GUID('MySymKey'), CAST(CardHoldersName AS NVARCHAR(200)));

UPDATE CustomerDetails.Clients
SET Address = ENCRYPTBYKEY(KEY_GUID('MySymKey'), CAST(Address AS NVARCHAR(200)));

-- Close the symmetric key
CLOSE SYMMETRIC KEY MySymKey;



-- To access the columns, you must Open the symmetric key
OPEN SYMMETRIC KEY MySymKey
    DECRYPTION BY CERTIFICATE MyServerCert;

-- Select decrypted data
SELECT 
    ContactPerson = CONVERT(NVARCHAR(50), DECRYPTBYKEY(ContactPerson))
FROM CustomerDetails.Clients

-- Close the symmetric key
CLOSE SYMMETRIC KEY MySymKey;



--11
-- A backup of the database the C Drive
BACKUP DATABASE [NewProject]
TO DISK = 'C:\SQL Backup\NewProject.bak'
WITH FORMAT,
     MEDIANAME = 'SQLServerBackups',
     NAME = 'Backup of NewProject';
GO

-- Create a stored procedure named GetEmployeesByID to retrieve details of an employee based on ID
CREATE PROCEDURE dbo.GetEmployeeByID
    @EmployeeID INT
AS
BEGIN
    SELECT FirstName, LastName, Title,PhoneNumber
    FROM HumanResources.Employee
    WHERE EmployeeID = @EmployeeID;
END
GO
-- Execute the stored procedure
EXEC dbo.GetEmployeeByID @EmployeeID = 1; -- Replace 1 with the desired department ID
GO

--Store procedure to retrieve projects a client paid for
CREATE PROCEDURE dbo.ProjectsPerClient
	@ClientID INT
AS
BEGIN
	SELECT ProjectID, ProjectName, StartDate
	FROM ProjectDetails.Projects
	WHERE ClientID= @ClientID;
END
EXEC dbo.ProjectsPerClient @ClientID = 6;
GO
--Procedure for Payment per Project
-- Create a stored procedure to update payment amount by project ID
CREATE PROCEDURE dbo.UpdatePaymentAmount
    @ProjectID INT,
    @NewAmount INT
AS
BEGIN
    -- Update the payment amount
    UPDATE Payment.Payments
    SET PaymentAmount = @NewAmount
    WHERE ProjectID = @ProjectID;
END
-- Execute the stored procedure
EXEC dbo.UpdatePaymentAmount @ProjectID = 104, @NewAmount = 3500;
GO

--A Snapshot of the Database
CREATE DATABASE NewProject_Snapshot ON
    (NAME = NewProject_Data, FILENAME = 'C:\NewProject Database\NewProject_Snapshot.ss')
    AS SNAPSHOT OF NewProject;

ALTER DATABASE NewProject SET ONLINE;


