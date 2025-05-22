USE master;
GO
CREATE LOGIN injectionDemo
    WITH PASSWORD = 's89ae7gfmsdoyusIUBDFS_#fsdflkjansf';
GO
CREATE DATABASE InjectionDemo;
GO
USE InjectionDemo;
GO
CREATE USER injectionDemo FROM LOGIN injectionDemo;
GO
GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::dbo TO injectionDemo;
GO

-------------------------------------------------------------------------------
---
--- Base tables
---
-------------------------------------------------------------------------------

CREATE TABLE dbo.SalesAgents (
    Id              int IDENTITY(1000, 1) NOT NULL,
    FirstName       nvarchar(100) NOT NULL,
    LastName        nvarchar(100) NOT NULL,
    UserName        sysname NOT NULL,
    PasswordText    nvarchar(100) NOT NULL,
    CONSTRAINT PK_SalesAgents PRIMARY KEY CLUSTERED (Id),
    CONSTRAINT UQ_SalesAgents_Username UNIQUE (UserName)
);

CREATE TABLE dbo.Products (
    Id              int IDENTITY(2000, 1) NOT NULL,
    SKU             varchar(30) NOT NULL,
    ProductName     nvarchar(100) NOT NULL,
    Color           varchar(100) NULL,
    [Size]          varchar(30) NULL,
    ListPrice       numeric(12, 2) NOT NULL,
    CONSTRAINT PK_Products PRIMARY KEY CLUSTERED (Id),
    CONSTRAINT UQ_Products_SKU UNIQUE (SKU)
);

CREATE TABLE dbo.SalesTargets (
    SalesAgentId    int NOT NULL,
    [Year]          date NOT NULL,
    TargetAmount    numeric(12, 2) NOT NULL,
    CONSTRAINT FK_SalesTargets_Agent FOREIGN KEY (SalesAgentId) REFERENCES dbo.SalesAgents (Id),
    CONSTRAINT CK_SalesTargets_Year CHECK (DATEPART(month, [Year])=1 AND DATEPART(day, [Year])=1),
    CONSTRAINT PK_SalesTargets PRIMARY KEY CLUSTERED (SalesAgentId, [Year])
);

CREATE TABLE dbo.Sales (
    [Timestamp]     datetime2(3) CONSTRAINT DF_Sales_Timestamp DEFAULT (SYSDATETIME()) NOT NULL,
    SalesAgentId    int NOT NULL,
    ProductId       int NOT NULL,
    Quantity        numeric(12, 2) NOT NULL,
    UnitPrice       numeric(12, 2) NOT NULL,
    CONSTRAINT PK_Sales PRIMARY KEY CLUSTERED ([Timestamp], SalesAgentId, ProductId),
    CONSTRAINT FK_Sales_Agent FOREIGN KEY (SalesAgentId) REFERENCES dbo.SalesAgents (Id),
    CONSTRAINT FK_Sales_Product FOREIGN KEY (ProductId) REFERENCES dbo.Products (Id)
);

GO

-------------------------------------------------------------------------------
---
--- View used to present the dashboard metrics
---
-------------------------------------------------------------------------------

CREATE OR ALTER VIEW dbo.SalesDashboard
AS

SELECT a.Id AS SalesAgentId,
       a.UserName,
       a.FirstName,
       a.LastName,
       t.From_Date,
       t.To_Date,
       t.TargetAmount,
       SUM(s.Sales) AS Sales,
       LAG(SUM(s.Sales), 1, 0) OVER (PARTITION BY a.Id ORDER BY t.From_Date) AS Sales_prev_year,
       100.*SUM(s.SalesListPrice-s.Sales)/SUM(s.SalesListPrice) AS DiscountPercent
FROM dbo.SalesAgents AS a
INNER JOIN (
    SELECT SalesAgentId,
           [Year] AS From_Date,
           LEAD([Year], 1, '2099-12-31') OVER (PARTITION BY SalesAgentId ORDER BY [Year]) AS To_Date,
           TargetAmount
    FROM dbo.SalesTargets
    ) AS t ON a.Id=t.SalesAgentId
LEFT JOIN (
    SELECT s.SalesAgentId,
           s.[Timestamp],
           s.Quantity*s.UnitPrice AS Sales,
           s.Quantity*p.ListPrice AS SalesListPrice
    FROM dbo.Sales AS s
    INNER JOIN dbo.Products AS p ON s.ProductId=p.Id
    ) s ON s.SalesAgentId=a.Id AND s.[Timestamp]>=t.From_Date AND s.[Timestamp]<t.To_Date
GROUP BY a.Id, a.UserName, a.FirstName, a.LastName, t.From_Date, t.To_Date, t.TargetAmount

GO


-------------------------------------------------------------------------------
---
--- Generate some data
---
-------------------------------------------------------------------------------

DELETE FROM dbo.SalesTargets;
DELETE FROM dbo.Sales;
DELETE FROM dbo.Products;
DELETE FROM dbo.SalesAgents;





INSERT INTO dbo.SalesAgents (FirstName, LastName, UserName, PasswordText)
SELECT FirstName, LastName,
       LOWER(FirstName+(CASE WHEN COUNT(*) OVER (PARTITION BY FirstName)>1 THEN N'.'+LastName ELSE N'' END)) AS UserName,
       N'password123' AS PasswordText
FROM (
    VALUES ('Agneta', 'Sjögren'), ('Sonja', 'Andersson'), ('Wilhelm', 'Månsson'), ('Ellinor', 'Olsson'),
           ('Helen', 'Blomqvist'), ('Patrik', 'Bergqvist'), ('Fredrik', 'Nilsson'), ('Alexandra', 'Gustafsson'),
           ('Göran', 'Ström'), ('Eva', 'Andersson'), ('Åsa', 'Samuelsson'), ('Birgitta', 'Bergström'),
           ('Yvonne', 'Hansson'), ('Inga', 'Hedlund'), ('Ingrid', 'Hansen'), ('Mikael', 'Ström'),
           ('Emelie', 'Larsson'), ('Rebecca', 'Nyström'), ('Margareta', 'Andersson'), ('Axel', 'Blom'),
           ('Roger', 'Andersson'), ('William', 'Nordström'), ('Kerstin', 'Lindgren'), ('Henrik', 'Johansson'),
           ('Robin', 'Andersson'), ('Håkan', 'Nilsson'), ('Anton', 'Karlsson'), ('Inger', 'Blomqvist'),
           ('Ingeborg', 'Lindqvist'), ('Alice', 'Johansson'), ('Alexander', 'Sjöberg'), ('Patrik', 'Johansson'),
           ('Fredrik', 'Sundberg'), ('Carina', 'Lundgren'), ('Pia', 'Sundström'), ('Yvonne', 'Holmberg'),
           ('Mona', 'Jansson'), ('Stig', 'Persson'), ('Ebba', 'Isaksson'), ('Emilia', 'Danielsson'),
           ('Kjell', 'Pettersson'), ('Louise', 'Samuelsson'), ('Caroline', 'Sjögren'), ('Sofie', 'Lundgren'),
           ('Bo', 'Hermansson'), ('Ulla', 'Danielsson'), ('Ingemar', 'Gustafsson'), ('Amanda', 'Karlsson'),
           ('Lars', 'Forsberg'), ('Ali', 'Svensson'), ('Therese', 'Nordström'), ('Klara', 'Berg'),
           ('Alf', 'Hellström'), ('Sebastian', 'Lundqvist'), ('Sofie', 'Lind'), ('Patrik', 'Blom'),
           ('Jonas', 'Hermansson'), ('Sten', 'Lundberg'), ('Carina', 'Löfgren'), ('Sara', 'Ekström'),
           ('Simon', 'Jönsson'), ('Isak', 'Ahmed'), ('Camilla', 'Hassan'), ('Elsa', 'Andersson'),
           ('Emil', 'Lund'), ('Karl', 'Samuelsson'), ('Klara', 'Jonsson'), ('Karolina', 'Bergman'),
           ('Agneta', 'Lundin'), ('Kristin', 'Jansson'), ('Jonathan', 'Olofsson'), ('Berit', 'Svensson'),
           ('Björn', 'Johansson'), ('Ida', 'Söderberg'), ('Alf', 'Engström'), ('Ingvar', 'Henriksson'),
           ('Madeleine', 'Johansson'), ('Gustav', 'Berg'), ('Irene', 'Gustafsson'), ('Mats', 'Lindqvist'),
           ('Eva', 'Forsberg'), ('Märta', 'Wallin'), ('Ulf', 'Gunnarsson'), ('Patrik', 'Söderberg'),
           ('Sven', 'Dahlberg'), ('Josefin', 'Mattsson'), ('Tommy', 'Bergman'), ('Isak', 'Öberg'),
           ('Roger', 'Hassan'), ('Viola', 'Johansson'), ('Sofia', 'Holm'), ('Gun', 'Lundqvist'),
           ('Fredrik', 'Olsson'), ('Sebastian', 'Björklund'), ('Kerstin', 'Nordström'), ('Mona', 'Ström'),
           ('Wilhelm', 'Mohamed'), ('Ingeborg', 'Nilsson'), ('Alice', 'Ekström'), ('Tommy', 'Eklund')
    ) AS x(FirstName, LastName);


INSERT INTO dbo.Products (SKU, ProductName, Color, [Size], ListPrice)
VALUES ('20562594', 'NICKEBO Door', 'Matte gray-green', '24x60', 181.00),
       ('29546547', 'HJÄLPA Pull-out rail for baskets', 'White light green/with 3 drawers', NULL, 338.00),
       ('49565733', 'SEKTION Wall cabinet frame', 'Nickebo matte gray-green', '30x15x20', 166.00),
       ('79565289', 'SEKTION Base cabinet frame', 'Nickebo matte gray-green', '24x24x30', 366.00),
       ('69572030', 'SINARP Door', 'Sinarp brown', NULL, 764.00),
       ('49571178', 'BILLY Desk', NULL, NULL, 169.00),
       ('09570294', 'EKET Cabinet', NULL, NULL, 100.00),
       ('59483275', 'BILLY Bookcase', 'Oak effect', NULL, 109.00),
       ('29565296', 'SEKTION Wall cabinet frame', 'Nickebo matte gray-green', '18x15x20', 180.00),
       ('39566337', 'SEKTION High cabinet frame', 'Nickebo matte gray-green', '30x24x80', 939.00),
       ('09559277', 'SEKTION Base cabinet frame', 'Havstorp light gray', '24x15x30', 298.00),
       ('09565283', 'SEKTION High cabinet frame', 'Nickebo matte gray-green', '18x15x80', 372.00),
       ('79559575', 'SEKTION Base cabinet frame', 'Havstorp light gray', '24x24x30', 259.00),
       ('59572078', 'SEKTION High cabinet frame', 'Lerh light gray', NULL, 948.00),
       ('99566042', 'SEKTION Base cabinet frame', 'Nickebo matte gray-green', '36x24x30', 549.00),
       ('69566331', 'SEKTION Base cabinet frame', 'Nickebo matte gray-green', '18x15x30', 199.00),
       ('19565744', 'SEKTION Wall cabinet frame', 'Nickebo matte gray-green', '15x15x30', 119.00),
       ('19559347', 'SEKTION Wall cabinet frame', 'Havstorp light gray', '30x15x20', 304.00),
       ('30592109', 'SANELA Comforter set', NULL, NULL, 109.00),
       ('59559246', 'SEKTION Base cabinet frame', 'Havstorp light gray', '24x24x30', 335.00),
       ('89572067', 'SEKTION High cabinet frame', NULL, NULL, 604.00),
       ('89572053', 'SEKTION High cabinet frame', NULL, NULL, 916.00),
       ('50584820', 'TÄRNKULLEN Cover for bed frame', NULL, NULL,  79.00),
       ('89564345', 'TÄRNKULLEN Upholstered bed frame', NULL, NULL, 449.00),
       ('59571917', 'BESTÅ TV unit', 'Black-brown Hammarsmed/anthracite', NULL, 320.00),
       ('39565446', 'SEKTION Base cabinet frame', 'Nickebo matte gray-green', NULL, 427.00),
       ('09571986', 'SEKTION High cabinet frame', 'Vedhamn oak', NULL, 884.00),
       ('69571912', 'BESTÅ TV unit', NULL, NULL, 590.00),
       ('49565276', 'SEKTION Corner wall cabinet frame', 'Nickebo matte gray-green', '26x15x30', 205.00),
       ('89571954', 'SINARP Door', 'Sinarp brown', NULL, 645.00),
       ('49566148', 'SEKTION Base cabinet frame', 'Nickebo matte gray-green', '30x24x30', 356.00),
       ('69572087', 'SEKTION High cabinet frame', NULL, NULL, 555.00),
       ('79559330', 'SEKTION Base cabinet frame', 'Havstorp light gray', NULL, 319.00),
       ('20587783', 'HAVSTORP Cover panel', 'Light gray', '15x90',  90.00),
       ('59569349', 'BESTÅ Frame', 'White/Hammarsmed anthracite', NULL, 256.00),
       ('59559623', 'SEKTION Wall cabinet frame', 'Havstorp light gray', '30x15x40', 279.00),
       ('49548932', 'BOAXEL Wall upright', 'Anthracite', NULL,  98.00),
       ('89559419', 'SEKTION Base cabinet frame', 'Havstorp light gray', '24x24x30', 137.00),
       ('89566311', 'SEKTION High cabinet frame', 'Nickebo matte gray-green', '15x15x80', 330.00),
       ('19572117', 'VOXTORP Door', 'Voxtorp dark gray', NULL, 1025.0),
       ('59566157', 'SEKTION Base cabinet frame', 'Nickebo matte gray-green', '30x15x30', 216.00),
       ('09547816', 'HJÄLPA Pull-out rail for baskets', 'White/blue', NULL, 208.00),
       ('29572013', 'VOXTORP Door', 'Voxtorp dark gray', NULL, 891.00),
       ('59565577', 'SEKTION Wall cabinet frame', 'Nickebo matte gray-green', '24x15x20', 350.00),
       ('39559488', 'SEKTION Base cabinet frame', 'Havstorp light gray', '30x24x30', 243.00),
       ('79566340', 'SEKTION High cabinet frame', 'Nickebo matte gray-green', '18x24x80', 548.00),
       ('09566032', 'SEKTION Wall top cabinet frame', 'Nickebo matte gray-green', '24x24x15', 176.00),
       ('89548987', 'BOAXEL Wall upright', NULL, NULL, 168.00),
       ('09572127', 'SEKTION High cabinet frame', 'Axstad matt white', NULL, 787.00),
       ('79559636', 'SEKTION Base cabinet frame', 'Havstorp light gray', '36x24x30', 307.00),
       ('09566051', 'SEKTION Base cabinet frame', 'Nickebo matte gray-green', '36x24x30', 244.00),
       ('39301771', 'BESTÅ Frame', 'White stained oak effect/Lappviken/Stubbarp white stained oak effect', NULL, 430.00),
       ('69559774', 'SEKTION Base cabinet frame', 'Havstorp light gray', '36x24x30', 408.00),
       ('09559442', 'SEKTION High cabinet frame', 'Havstorp light gray', '15x24x80', 481.00),
       ('39559624', 'SEKTION Wall cabinet frame', 'Havstorp light gray', '24x15x30', 178.00),
       ('70587785', 'HAVSTORP Cover panel', 'Light gray', '25x80', 115.00),
       ('99565759', 'SEKTION Wall cabinet frame', 'Nickebo matte gray-green', '36x15x30', 325.00),
       ('99483551', 'BILLY Corner hardware', 'Dark brown oak effect', NULL, 305.00),
       ('39566182', 'SEKTION Base cabinet frame', 'Nickebo matte gray-green', '24x24x30', 287.00),
       ('10562575', 'NICKEBO Door', 'Matte gray-green', '15x15',  35.00),
       ('39572041', 'SEKTION High cabinet frame', 'Enköping brown walnut effect', NULL, 579.00),
       ('10562599', 'NICKEBO Drawer front', 'Matte gray-green', '18x10',  35.00),
       ('60589657', 'JÄRSTORP Countertop for kitchen island', NULL, NULL, 139.00),
       ('09559654', 'SEKTION Wall cabinet frame', 'Havstorp light gray', '18x15x40', 127.00),
       ('09559734', 'SEKTION Base cabinet frame', 'Havstorp light gray', '15x24x30', 147.00),
       ('59546503', 'HJÄLPA Adjustable clothes rail', 'White/light green', NULL, 646.00),
       ('29566700', 'PAX Wall-mounted storage frame w rail', NULL, '300x60x201 cm', 2105.0),
       ('79565618', 'SEKTION High cabinet frame', 'Nickebo matte gray-green', '24x24x90', 873.00),
       ('90601021', 'KALLAX Insert with 1 shelf', 'White stained/oak effect', NULL,  10.00),
       ('50587828', 'HAVSTORP Toekick', 'Light gray', NULL,  38.00),
       ('79572044', 'SEKTION High cabinet frame', 'Axstad dark gray', NULL, 673.00),
       ('49559384', 'SEKTION Base cabinet frame', 'Havstorp light gray', '36x15x30', 308.00),
       ('89572114', 'SEKTION High cabinet frame', NULL, NULL, 1073.0),
       ('29571971', 'SEKTION High cabinet frame', 'Bodbyn gray', NULL, 688.00),
       ('49571932', 'SEKTION High cabinet frame', 'Havstorp deep green', NULL, 492.00),
       ('79559603', 'SEKTION Base cabinet frame', 'Havstorp light gray', '21x24x30', 126.00),
       ('99565448', 'SEKTION High cabinet frame', 'Nickebo matte gray-green', '24x24x90', 700.00),
       ('99571939', 'SEKTION High cabinet frame', NULL, NULL, 435.00),
       ('39571956', 'SEKTION High cabinet frame', 'Tistorp brown walnut effect', NULL, 397.00),
       ('39559681', 'SEKTION High cabinet frame', 'Havstorp light gray', '15x15x90', 474.00),
       ('79508053', 'BESTÅ Frame', NULL, NULL, 402.00),
       ('09572132', 'SEKTION High cabinet frame', 'Lerh black stained', NULL, 884.00),
       ('19565621', 'SEKTION Base corner cabinet frame', 'Nickebo matte gray-green', NULL, 366.00),
       ('90592106', 'SANELA Comforter set', NULL, NULL, 109.00),
       ('69566048', 'SEKTION Base cabinet frame', 'Nickebo matte gray-green', '30x24x30', 353.00),
       ('79566038', 'SEKTION Wall cabinet frame', 'Nickebo matte gray-green', '36x15x20', 282.00),
       ('79566316', 'SEKTION High cabinet frame', 'Nickebo matte gray-green', '18x24x80', 398.00),
       ('29571909', 'BESTÅ TV unit', NULL, NULL, 590.00),
       ('09559692', 'SEKTION Base cabinet frame', 'Havstorp light gray', '15x24x30', 173.00),
       ('39559266', 'SEKTION Base cabinet frame', 'Havstorp light gray', '30x24x30', 269.00),
       ('09559710', 'SEKTION High cabinet frame', 'Havstorp light gray', '18x24x90', 583.00),
       ('29571933', 'SEKTION High cabinet frame', 'Havstorp deep green', NULL, 530.00),
       ('19572075', 'SEKTION High cabinet frame', 'Havstorp beige', NULL, 555.00),
       ('59572002', 'SEKTION High cabinet frame', 'Nickebo matte anthracite', NULL, 567.00),
       ('49569905', 'SEKTION Base cabinet for oven', 'None', NULL, 112.00),
       ('99565716', 'SEKTION High cabinet frame', 'Nickebo matte gray-green', '30x24x80', 648.00),
       ('39563942', 'BILLY Bookcase', NULL, NULL, 159.00),
       ('49571965', 'SEKTION High cabinet frame', NULL, NULL, 460.00),
       ('29572051', 'SEKTION High cabinet frame', NULL, NULL, 530.00),
       ('09559705', 'SEKTION Base cabinet frame', 'Havstorp light gray', '18x24x30', 192.00),
       ('29565423', 'SEKTION Base cabinet frame', 'Nickebo matte gray-green', '36x24x30', 744.00),
       ('69559321', 'SEKTION Base cabinet frame', 'Havstorp light gray', '30x24x30', 355.00),
       ('49565870', 'SEKTION Base cabinet frame', 'Nickebo matte gray-green', '12x24x30', 116.00),
       ('59571979', 'SINARP Door', NULL, NULL, 684.00),
       ('09559753', 'SEKTION High cabinet frame', 'Havstorp light gray', '24x24x80', 676.00),
       ('20574587', 'EKET Cabinet with 2 doors and shelf', 'Brown/walnut effect', NULL,  80.00),
       ('29565277', 'SEKTION Base cabinet frame', 'Nickebo matte gray-green', '36x15x30', 385.00),
       ('49565714', 'SEKTION Base cabinet frame', 'Nickebo matte gray-green', '36x15x30', 408.00),
       ('09565891', 'SEKTION Wall cabinet frame', 'Nickebo matte gray-green', '24x15x30', 274.00),
       ('10596580', 'VALLSTENA Cover panel', NULL, NULL,  38.00),
       ('70562600', 'NICKEBO Drawer front', 'Matte gray-green', '18x15',  43.00),
       ('40562606', 'NICKEBO Drawer front', 'Matte gray-green', '30x15',  56.00),
       ('49569335', 'BESTÅ Frame', NULL, NULL, 392.00),
       ('09566013', 'SEKTION High cabinet frame', 'Nickebo matte gray-green', '30x24x80', 862.00),
       ('49569236', 'TÄRNKULLEN Upholstered bed frame', NULL, NULL, 419.00),
       ('79559491', 'SEKTION Base cabinet frame', 'Havstorp light gray', '24x24x30', 233.00),
       ('09559786', 'SEKTION Base cabinet frame', 'Havstorp light gray', '24x24x30', 260.00),
       ('19565881', 'SEKTION Base cabinet frame', 'Nickebo matte gray-green', '24x24x30', 299.00),
       ('29572032', 'SEKTION High cabinet frame', 'Stensund beige', NULL, 608.00),
       ('69559533', 'SEKTION Base cabinet frame', 'Havstorp light gray', '30x24x30', 227.00),
       ('39565597', 'SEKTION High cabinet frame', 'Nickebo matte gray-green', '24x24x80', 762.00);




INSERT INTO dbo.SalesTargets (SalesAgentId, [Year], TargetAmount)
SELECT a.Id AS SalesAgentId, DATEFROMPARTS(x.YearNo, 1, 1) AS [Year], FLOOR(x.TargetAmount)
FROM dbo.SalesAgents AS a
CROSS APPLY (
    VALUES (YEAR(SYSDATETIME())-2, 50000/1.05/1.05),
           (YEAR(SYSDATETIME())-1, 50000/1.05),
           (YEAR(SYSDATETIME()),   50000)
    ) AS x(YearNo, TargetAmount);




INSERT INTO dbo.Sales ([Timestamp], SalesAgentId, ProductId, Quantity, UnitPrice)
SELECT DATEADD(second, 9*60*60+8*60*60*RAND(CHECKSUM(NEWID())),
            CAST(DATEADD(day, x.ch, DATEFROMPARTS(YEAR(SYSDATETIME()), 1, 1)) AS datetime2(3))) AS [Timestamp],
       a.Id AS SalesAgentId,
       p.Id AS ProductId,
       1+FLOOR(SQRT(500*RAND(CHECKSUM(NEWID())))) AS Quantity,
       p.ListPrice*(1.-0.1*SQRT(RAND(CHECKSUM(NEWID())))) AS UnitPrice
FROM dbo.SalesAgents AS a
CROSS APPLY GENERATE_SERIES(1, LEN(a.UserName), 1) AS n
CROSS APPLY (VALUES (ASCII(SUBSTRING(a.UserName, n.[value], 1)))) AS x(ch)
CROSS APPLY (
        SELECT Id, ListPrice
        FROM dbo.Products
        ORDER BY Id
        OFFSET x.ch ROWS FETCH NEXT 1 ROW ONLY
) AS p;


