-- Run once on a database created from the legacy SQLQuery1.sql script.
-- New databases should use the EF Core migration instead.
IF OBJECT_ID(N'dbo.HouseholdNotifications', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.HouseholdNotifications (
        Id UNIQUEIDENTIFIER NOT NULL
            CONSTRAINT PK_HouseholdNotifications PRIMARY KEY DEFAULT NEWSEQUENTIALID(),
        HouseholdId UNIQUEIDENTIFIER NOT NULL,
        RecipientUserId UNIQUEIDENTIFIER NOT NULL,
        Title NVARCHAR(150) NOT NULL,
        Message NVARCHAR(500) NOT NULL,
        CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        ReadAt DATETIME2 NULL,
        CONSTRAINT FK_HouseholdNotifications_Households
            FOREIGN KEY (HouseholdId) REFERENCES dbo.Households(Id),
        CONSTRAINT FK_HouseholdNotifications_Users
            FOREIGN KEY (RecipientUserId) REFERENCES dbo.Users(Id)
    );

    CREATE INDEX IX_HouseholdNotifications_RecipientUserId_ReadAt_CreatedAt
        ON dbo.HouseholdNotifications (RecipientUserId, ReadAt, CreatedAt);
END;
