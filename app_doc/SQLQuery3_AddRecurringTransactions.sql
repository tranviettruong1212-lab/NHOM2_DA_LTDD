-- MoneyMate - Bo sung bang RecurringTransactions cho database
USE FINANCE_MANAGER;
GO

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'RecurringTransactions')
BEGIN
    CREATE TABLE RecurringTransactions (
        Id UNIQUEIDENTIFIER NOT NULL CONSTRAINT DF_RecurringTransactions_Id DEFAULT NEWSEQUENTIALID(),
        CreatedByUserId UNIQUEIDENTIFIER NOT NULL,
        HouseholdId UNIQUEIDENTIFIER NULL,
        AccountId UNIQUEIDENTIFIER NOT NULL,
        CategoryId UNIQUEIDENTIFIER NULL,
        Title NVARCHAR(150) NOT NULL,
        Type TINYINT NOT NULL,
        Amount DECIMAL(18,2) NOT NULL,
        Frequency TINYINT NOT NULL,
        StartDate DATE NOT NULL,
        EndDate DATE NULL,
        NextDueDate DATE NOT NULL,
        LastGeneratedDate DATE NULL,
        AutoCreate BIT NOT NULL CONSTRAINT DF_RecurringTransactions_AutoCreate DEFAULT 1,
        IsActive BIT NOT NULL CONSTRAINT DF_RecurringTransactions_IsActive DEFAULT 1,
        Note NVARCHAR(1000) NULL,
        CreatedAt DATETIME2 NOT NULL CONSTRAINT DF_RecurringTransactions_CreatedAt DEFAULT SYSUTCDATETIME(),
        UpdatedAt DATETIME2 NULL,
        CONSTRAINT PK_RecurringTransactions PRIMARY KEY (Id),
        CONSTRAINT CK_RecurringTransactions_Amount CHECK (Amount > 0),
        CONSTRAINT CK_RecurringTransactions_Frequency CHECK (Frequency IN (0,1,2,3)),
        CONSTRAINT CK_RecurringTransactions_Type CHECK (Type IN (0,1)),
        CONSTRAINT FK_RecurringTransactions_Users FOREIGN KEY (CreatedByUserId) REFERENCES Users(Id),
        CONSTRAINT FK_RecurringTransactions_Households FOREIGN KEY (HouseholdId) REFERENCES Households(Id),
        CONSTRAINT FK_RecurringTransactions_Accounts FOREIGN KEY (AccountId) REFERENCES Accounts(Id),
        CONSTRAINT FK_RecurringTransactions_Categories FOREIGN KEY (CategoryId) REFERENCES Categories(Id)
    );

    CREATE NONCLUSTERED INDEX IX_RecurringTransactions_AccountId ON RecurringTransactions(AccountId);
    CREATE NONCLUSTERED INDEX IX_RecurringTransactions_CategoryId ON RecurringTransactions(CategoryId);
    CREATE NONCLUSTERED INDEX IX_RecurringTransactions_Creator ON RecurringTransactions(CreatedByUserId, IsActive, NextDueDate);
    CREATE NONCLUSTERED INDEX IX_RecurringTransactions_Household ON RecurringTransactions(HouseholdId, IsActive, NextDueDate);
END
GO

